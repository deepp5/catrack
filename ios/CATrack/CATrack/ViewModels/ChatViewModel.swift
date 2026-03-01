import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [UUID: [Message]] = [:] {
        didSet { persistSessions() }
    }
    @Published var isLoading: Bool = false
    @Published var pendingMedia: [AttachedMedia] = []
    @Published var activeInspectionIds: [UUID: String] = [:] {
        didSet { persistInspectionIds() }
    }

    private let sessionsKey      = "catrack.chat.sessions"
    private let inspectionIdsKey = "catrack.chat.inspectionIds"

    init() {
        loadSessions()
        loadInspectionIds()
    }

    // MARK: - Persistence

    private func persistSessions() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: sessions.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let stringKeyed = try? JSONDecoder().decode([String: [Message]].self, from: data) else { return }
        sessions = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { k, v in
            guard let uuid = UUID(uuidString: k) else { return nil }
            return (uuid, v)
        })
    }

    private func persistInspectionIds() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: activeInspectionIds.map { ($0.key.uuidString, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            UserDefaults.standard.set(data, forKey: inspectionIdsKey)
        }
    }

    private func loadInspectionIds() {
        guard let data = UserDefaults.standard.data(forKey: inspectionIdsKey),
              let stringKeyed = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        activeInspectionIds = Dictionary(uniqueKeysWithValues: stringKeyed.compactMap { k, v in
            guard let uuid = UUID(uuidString: k) else { return nil }
            return (uuid, v)
        })
    }

    // MARK: - Session Management

    func messagesFor(_ machineId: UUID) -> [Message] {
        sessions[machineId] ?? []
    }

    func startSession(for machine: Machine) {
        guard sessions[machine.id] == nil else { return }
        let systemMsg = Message.system("Inspecting \(machine.model) (Serial: \(machine.serial)) at \(machine.site). Hours: \(machine.hours).")
        sessions[machine.id] = [systemMsg]

        Task {
            do {
                let inspectionId = try await APIService.shared.startInspection(machineModel: machine.model)
                activeInspectionIds[machine.id] = inspectionId
                UserDefaults.standard.set(inspectionId, forKey: "activeInspectionId")
            } catch {
                print("Failed to start inspection:", error)
            }
        }
    }

    /// Only call when user starts a NEW inspection on a DIFFERENT machine.
    func clearSession(machineId: UUID) {
        sessions.removeValue(forKey: machineId)
        activeInspectionIds.removeValue(forKey: machineId)
    }

    func attachMedia(_ media: AttachedMedia) {
        pendingMedia.append(media)
    }

    func removeMedia(id: String) {
        pendingMedia.removeAll { $0.id == id }
    }

    // MARK: - Send Message

    func sendMessage(text: String, machineId: UUID, machine: Machine, sheetVM: InspectionSheetViewModel) async {
        var msgs = sessions[machineId] ?? []
        let media = pendingMedia
        pendingMedia = []

        msgs.append(Message.user(text: text, media: media))
        sessions[machineId] = msgs

        isLoading = true
        defer { isLoading = false }

        do {
            var uploadedMedia = media
            for i in uploadedMedia.indices {
                guard uploadedMedia[i].type == .image, let localURL = uploadedMedia[i].localURL else { continue }
                uploadedMedia[i].remoteId = try await APIService.shared.uploadMedia(localURL: localURL, machineId: machineId)
            }

            let sections = sheetVM.sectionsFor(machineId)
            var currentChecklistState: [String: String] = [:]
            for section in sections {
                for field in section.fields {
                    let v: String
                    switch field.status {
                    case .pass:    v = "PASS"
                    case .monitor: v = "MONITOR"
                    case .fail:    v = "FAIL"
                    case .pending: v = "none"
                    }
                    currentChecklistState[field.label] = v
                }
            }

            let imagesBase64: [String] = uploadedMedia.compactMap { m in
                guard m.type == .image else { return nil }
                if let data = m.thumbnailData { return data.base64EncodedString() }
                if let url = m.localURL, let data = try? Data(contentsOf: url) { return data.base64EncodedString() }
                return nil
            }

            var videoFramesBase64: [String]? = nil
            if let video = uploadedMedia.first(where: { $0.type == .video }), let url = video.localURL {
                videoFramesBase64 = try await extractFramesBase64(from: url)
            }

            let historyPayload: [[String: String]] = sessions[machineId, default: []]
                .filter { $0.role != .system }.suffix(6)
                .map { ["role": $0.role == .assistant ? "assistant" : "user", "content": $0.text] }

            let resp: FastAnalyzeResponse
            if let frames = videoFramesBase64, !frames.isEmpty {
                resp = try await APIService.shared.analyzeVideoCommand(
                    userText: text, currentChecklistState: currentChecklistState, framesBase64: frames)
            } else {
                resp = try await APIService.shared.analyzeFastAPI(
                    inspectionId: activeInspectionIds[machineId] ?? "",
                    userText: text,
                    imagesBase64: imagesBase64.isEmpty ? nil : imagesBase64,
                    chatHistory: historyPayload)
            }

            var sheetUpdates: [SheetUpdate] = []
            for (key, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status),
                      let hit = findFieldByBackendKey(key, in: sections) else { continue }
                sheetUpdates.append(SheetUpdate(sheetSection: hit.sectionId, fieldId: hit.fieldId, value: sev,
                    evidenceMediaId: uploadedMedia.first(where: { $0.type == .image })?.remoteId))
            }
            if !sheetUpdates.isEmpty { sheetVM.applyUpdates(sheetUpdates, for: machineId) }

            var reply = resp.answer ?? ""
            if reply.isEmpty && !sheetUpdates.isEmpty { reply = "Updated \(sheetUpdates.count) checklist item(s). Risk: \(resp.riskScore ?? "n/a")." }
            if reply.isEmpty && !resp.followUpQuestions.isEmpty { reply = resp.followUpQuestions.joined(separator: "\n") }
            if reply.isEmpty { reply = "Got it." }

            sessions[machineId, default: []].append(Message.assistant(text: reply))

        } catch {
            sessions[machineId, default: []].append(Message.assistant(text: "Error: \(error.localizedDescription)"))
        }
    }

    // MARK: - Voice Note

    func sendVoiceNote(url: URL, duration: Int, machineId: UUID, machine: Machine, sheetVM: InspectionSheetViewModel) async {
        sessions[machineId, default: []].append(Message.userVoice(url: url, duration: duration))
        isLoading = true
        defer { isLoading = false }

        do {
            guard let inspectionId = activeInspectionIds[machineId] else {
                sessions[machineId, default: []].append(Message.assistant(text: "Inspection not started yet."))
                return
            }

            let resp = try await APIService.shared.uploadVoiceNote(localURL: url, inspectionId: inspectionId)
            let sections = sheetVM.sectionsFor(machineId)
            var sheetUpdates: [SheetUpdate] = []
            for (key, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status),
                      let hit = findFieldByBackendKey(key, in: sections) else { continue }
                sheetUpdates.append(SheetUpdate(sheetSection: hit.sectionId, fieldId: hit.fieldId, value: sev, evidenceMediaId: nil))
            }
            if !sheetUpdates.isEmpty { sheetVM.applyUpdates(sheetUpdates, for: machineId) }

            var reply = resp.answer ?? ""
            if reply.isEmpty && !sheetUpdates.isEmpty { reply = "Updated \(sheetUpdates.count) checklist item(s). Risk: \(resp.riskScore ?? "n/a")." }
            if reply.isEmpty && !resp.followUpQuestions.isEmpty { reply = resp.followUpQuestions.joined(separator: "\n") }
            if reply.isEmpty { reply = "Got it." }
            sessions[machineId, default: []].append(Message.assistant(text: reply))

        } catch {
            sessions[machineId, default: []].append(Message.assistant(text: "Voice upload failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - Helpers

    private func findFieldByBackendKey(_ key: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
        for sec in sections {
            if let f = sec.fields.first(where: { $0.label == key }) { return (sec.id, f.id) }
        }
        return nil
    }

    private func extractFramesBase64(from videoURL: URL, maxFrames: Int = 5) async throws -> [String] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return [] }
        let step = totalSeconds / Double(maxFrames)
        var frames: [String] = []
        for i in 0..<maxFrames {
            let t = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            if let cg = try? generator.copyCGImage(at: t, actualTime: nil),
               let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.7) {
                frames.append(data.base64EncodedString())
            }
        }
        return frames
    }
}
