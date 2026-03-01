import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [UUID: [Message]] = [:]
    @Published var isLoading: Bool = false
    @Published var pendingMedia: [AttachedMedia] = []
    @Published var activeInspectionIds: [UUID: String] = [:]

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
            } catch {
                print("Failed to start inspection:", error)
            }
        }
    }

    // Helper: Extract frames from a video file and return them as base64-encoded JPEGs
    private func extractFramesBase64(from videoURL: URL, maxFrames: Int = 5) async throws -> [String] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return [] }

        var times: [NSValue] = []
        let step = totalSeconds / Double(maxFrames)
        for i in 0..<maxFrames {
            let cmTime = CMTime(seconds: Double(i) * step, preferredTimescale: 600)
            times.append(NSValue(time: cmTime))
        }

        var frames: [String] = []

        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time.timeValue, actualTime: nil) {
                let uiImage = UIImage(cgImage: cgImage)
                if let data = uiImage.jpegData(compressionQuality: 0.7) {
                    frames.append(data.base64EncodedString())
                }
            }
        }

        return frames
    }

    func sendMessage(text: String, machineId: UUID, machine: Machine, sheetVM: InspectionSheetViewModel) async {
        var msgs = sessions[machineId] ?? []
        let media = pendingMedia
        pendingMedia = []

        let userMsg = Message.user(text: text, media: media)
        msgs.append(userMsg)
        sessions[machineId] = msgs

        isLoading = true
        defer { isLoading = false }

        do {
            // 1) Upload any image media files first, get back remote IDs
            var uploadedMedia = media
            for i in uploadedMedia.indices {
                guard uploadedMedia[i].type == .image,
                      let localURL = uploadedMedia[i].localURL else { continue }
                let remoteId = try await APIService.shared.uploadMedia(
                    localURL: localURL,
                    machineId: machineId
                )
                uploadedMedia[i].remoteId = remoteId
            }

            // 2) Build checklist state
            let sections = sheetVM.sectionsFor(machineId)
            var currentChecklistState: [String: String] = [:]
            for section in sections {
                for field in section.fields {
                    currentChecklistState[field.id] = field.status.rawValue
                }
            }

            // 3) Convert images to base64
            let imagesBase64: [String] = uploadedMedia.compactMap { m in
                guard m.type == .image else { return nil }
                if let data = m.thumbnailData { return data.base64EncodedString() }
                if let url = m.localURL, let data = try? Data(contentsOf: url) {
                    return data.base64EncodedString()
                }
                return nil
            }

            // 3b) Extract video frames if video attached
            let videoMedia = uploadedMedia.first(where: { $0.type == .video })
            var videoFramesBase64: [String]? = nil

            if let video = videoMedia, let videoURL = video.localURL {
                videoFramesBase64 = try await extractFramesBase64(from: videoURL)
            }

            // Build chat history payload (last 6 messages, excluding system)
            let historyPayload: [[String: String]] = sessions[machineId, default: []]
                .filter { $0.role != .system }
                .suffix(6)
                .map { msg in
                    [
                        "role": msg.role == .assistant ? "assistant" : "user",
                        "content": msg.text
                    ]
                }

            // 4) Call FastAPI /analyze or /analyzeVideoCommand depending on presence of video frames
            let resp: FastAnalyzeResponse

            if let frames = videoFramesBase64, !frames.isEmpty {
                resp = try await APIService.shared.analyzeVideoCommand(
                    userText: text,
                    currentChecklistState: currentChecklistState,
                    framesBase64: frames
                )
            } else {
                resp = try await APIService.shared.analyzeFastAPI(
                    inspectionId: activeInspectionIds[machineId] ?? "",
                    userText: text,
                    imagesBase64: imagesBase64.isEmpty ? nil : imagesBase64,
                    chatHistory: historyPayload
                )
            }

            // 5) Convert checklist updates
            var sheetUpdates: [SheetUpdate] = []
            for (backendKey, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
                guard let hit = findFieldByBackendKey(backendKey, in: sections) else { continue }
                sheetUpdates.append(
                    SheetUpdate(
                        sheetSection: hit.sectionId,
                        fieldId: hit.fieldId,
                        value: sev,
                        evidenceMediaId: uploadedMedia.first(where: { $0.type == .image })?.remoteId
                    )
                )
            }

            if !sheetUpdates.isEmpty {
                sheetVM.applyUpdates(sheetUpdates, for: machineId)
            }

            // 6) Build assistant response
            var assistantText = resp.answer ?? ""
            if assistantText.isEmpty && !sheetUpdates.isEmpty {
                assistantText = "Updated \(sheetUpdates.count) checklist item(s). Risk: \(resp.riskScore ?? "n/a")."
            }
            if assistantText.isEmpty && !resp.followUpQuestions.isEmpty {
                assistantText = resp.followUpQuestions.joined(separator: "\n")
            }
            if assistantText.isEmpty { assistantText = "Got it." }

            sessions[machineId, default: []].append(Message.assistant(text: assistantText))

        } catch {
            sessions[machineId, default: []].append(
                Message.assistant(text: "Error: \(error.localizedDescription)")
            )
        }
    }

    private func findFieldByBackendKey(_ key: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
        for sec in sections {
            if let f = sec.fields.first(where: { $0.id == key }) {
                return (sec.id, f.id)
            }
        }
        return nil
    }

    func clearSession(machineId: UUID) {
        sessions.removeValue(forKey: machineId)
    }

    func attachMedia(_ media: AttachedMedia) {
        pendingMedia.append(media)
    }

    func removeMedia(id: String) {
        pendingMedia.removeAll { $0.id == id }
    }

    func sendVoiceNote(url: URL, duration: Int, machineId: UUID, machine: Machine, sheetVM: InspectionSheetViewModel) async {
        sessions[machineId, default: []].append(
            Message.userVoice(url: url, duration: duration)
        )

        isLoading = true
        defer { isLoading = false }

        do {
            guard let inspectionId = activeInspectionIds[machineId] else {
                sessions[machineId, default: []].append(
                    Message.assistant(text: "Inspection not started yet.")
                )
                return
            }

            let resp = try await APIService.shared.uploadVoiceNote(
                localURL: url,
                inspectionId: inspectionId
            )

            // Apply checklist updates just like text flow
            let sections = sheetVM.sectionsFor(machineId)
            var sheetUpdates: [SheetUpdate] = []

            for (backendKey, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
                guard let hit = findFieldByBackendKey(backendKey, in: sections) else { continue }
                sheetUpdates.append(
                    SheetUpdate(
                        sheetSection: hit.sectionId,
                        fieldId: hit.fieldId,
                        value: sev,
                        evidenceMediaId: nil
                    )
                )
            }

            if !sheetUpdates.isEmpty {
                sheetVM.applyUpdates(sheetUpdates, for: machineId)
            }

            var assistantText = resp.answer ?? ""
            if assistantText.isEmpty && !sheetUpdates.isEmpty {
                assistantText = "Updated \(sheetUpdates.count) checklist item(s). Risk: \(resp.riskScore ?? "n/a")."
            }
            if assistantText.isEmpty && !resp.followUpQuestions.isEmpty {
                assistantText = resp.followUpQuestions.joined(separator: "\n")
            }
            if assistantText.isEmpty { assistantText = "Got it." }

            sessions[machineId, default: []].append(
                Message.assistant(text: assistantText)
            )
        } catch {
            sessions[machineId, default: []].append(
                Message.assistant(text: "Voice upload failed: \(error.localizedDescription)")
            )
        }
    }
}
