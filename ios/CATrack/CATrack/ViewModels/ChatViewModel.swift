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

    func startSession(for machine: Machine) {
        guard sessions[machine.id] == nil else { return }
        let systemMsg = Message.system("Inspecting \(machine.model) (Serial: \(machine.serial)) at \(machine.site). Hours: \(machine.hours).")
        sessions[machine.id] = [systemMsg]
    }

    func sendMessage(text: String, machineId: UUID, machine: Machine) async {
        var msgs = sessions[machineId] ?? []
        let media = pendingMedia
        pendingMedia = []
        let userMsg = Message.user(text: text, media: media)
        msgs.append(userMsg)
        sessions[machineId] = msgs
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIService.shared.analyze(
                message: text,
                machineId: machineId,
                media: media
            )
            let aiMsg = Message.assistant(
                text: response.assistantMessage,
                findings: response.findings,
                memoryNote: response.memoryNote
            )
            sessions[machineId, default: []].append(aiMsg)
        } catch {
            let errMsg = Message.assistant(text: "Error: \(error.localizedDescription)")
            sessions[machineId, default: []].append(errMsg)
        }
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
