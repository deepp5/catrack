import Foundation
import Combine

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

            // 4) Call FastAPI /analyze
            let resp = try await APIService.shared.analyzeFastAPI(
                inspectionId: activeInspectionIds[machineId] ?? "",
                userText: text,
                imagesBase64: imagesBase64.isEmpty ? nil : imagesBase64
            )

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
            let transcript = try await APIService.shared.uploadVoiceNote(localURL: url)
            await sendMessage(
                text: transcript,
                machineId: machineId,
                machine: machine,
                sheetVM: sheetVM
            )
        } catch {
            sessions[machineId, default: []].append(
                Message.assistant(text: "Voice upload failed: \(error.localizedDescription)")
            )
        }
    }
}
