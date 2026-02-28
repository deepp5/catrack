import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [UUID: [Message]] = [:]
    @Published var isLoading: Bool = false
    @Published var pendingMedia: [AttachedMedia] = []

    func messagesFor(_ machineId: UUID) -> [Message] {
        sessions[machineId] ?? []
    }
//checking for errors on UI
    func startSession(for machine: Machine) {
        guard sessions[machine.id] == nil else { return }
        let systemMsg = Message.system("Inspecting \(machine.model) (Serial: \(machine.serial)) at \(machine.site). Hours: \(machine.hours).")
        sessions[machine.id] = [systemMsg]
    }

    // func sendMessage(text: String, machineId: UUID, machine: Machine, sheetVM: InspectionSheetViewModel) async {
    //     var msgs = sessions[machineId] ?? []
    //     let media = pendingMedia
    //     pendingMedia = []
    //     let userMsg = Message.user(text: text, media: media)
    //     msgs.append(userMsg)
    //     sessions[machineId] = msgs
    //     isLoading = true
    //     defer { isLoading = false }

    //     do {
    //         let response = try await APIService.shared.analyze(
    //             message: text,
    //             machineId: machineId,
    //             media: media
    //         )
    //         let aiMsg = Message.assistant(
    //             text: response.assistantMessage,
    //             findings: response.findings,
    //             memoryNote: response.memoryNote
    //         )
    //         sessions[machineId, default: []].append(aiMsg)
    //     } catch {
    //         let errMsg = Message.assistant(text: "Error: \(error.localizedDescription)")
    //         sessions[machineId, default: []].append(errMsg)
    //     }
    // }

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
            // 1) Build current_checklist_state using SheetField.label as the key
            let sections = sheetVM.sectionsFor(machineId)
            var currentChecklistState: [String: String] = [:]
            for section in sections {
                for field in section.fields {
                    currentChecklistState[field.id] = field.status.rawValue
                }
            }

            // 2) Convert attached images to base64 for FastAPI (optional)
            let imagesBase64: [String] = media.compactMap { m in
                guard m.type == .image else { return nil }
                guard let data = m.thumbnailData else { return nil } // you stored jpeg bytes here
                return data.base64EncodedString()
            }

            // 3) Call FastAPI /analyze
            let resp = try await APIService.shared.analyzeFastAPI(
                userText: text,
                currentChecklistState: currentChecklistState,
                imagesBase64: imagesBase64.isEmpty ? nil : imagesBase64
            )

            // 4) Convert resp.checklistUpdates -> [SheetUpdate]
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

            // Apply updates to sheet
            if !sheetUpdates.isEmpty {
                sheetVM.applyUpdates(sheetUpdates, for: machineId)
            }

            // 5) Build assistant message text
            var assistantText = resp.answer ?? ""

            if assistantText.isEmpty && !sheetUpdates.isEmpty {
                assistantText = "Updated \(sheetUpdates.count) checklist item(s). Risk: \(resp.riskScore ?? "n/a")."
            }

            if assistantText.isEmpty && !resp.followUpQuestions.isEmpty {
                assistantText = resp.followUpQuestions.joined(separator: "\n")
            }

            if assistantText.isEmpty {
                assistantText = "Got it."
            }

            let aiMsg = Message.assistant(text: assistantText)
            sessions[machineId, default: []].append(aiMsg)

        } catch {
            let errMsg = Message.assistant(text: "Error: \(error.localizedDescription)")
            sessions[machineId, default: []].append(errMsg)
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
}
