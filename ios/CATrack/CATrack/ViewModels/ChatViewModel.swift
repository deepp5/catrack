import Foundation
import Combine

struct ChatSessionSummary: Identifiable {
    var id: UUID
    var machine: Machine
    var lastMessage: String
    var timestamp: Date
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var sessions: [UUID: [ChatMessage]] = [:]
    @Published var isLoading: Bool = false

    var allSessionSummaries: [ChatSessionSummary] {
        sessions.compactMap { machineId, messages in
            guard let last = messages.last else { return nil }
            return ChatSessionSummary(id: machineId, machine: Machine(id: machineId, model: "", serialNumber: "", hours: 0, site: ""), lastMessage: last.text, timestamp: last.timestamp)
        }.sorted { $0.timestamp > $1.timestamp }
    }

    func startSession(for machine: Machine) {
        if sessions[machine.id] == nil {
            sessions[machine.id] = []
        }
    }

    func sendTextMessage(_ text: String, attachments: [MediaAttachment] = [], for machineId: UUID) async {
        let userMsg = ChatMessage(role: .user, text: text, attachments: attachments)
        sessions[machineId, default: []].append(userMsg)
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIService.shared.sendInspectionMessage(text: text, machineId: machineId, attachments: attachments)
            sessions[machineId, default: []].append(response)
        } catch {
            let errMsg = ChatMessage(role: .assistant, text: "Error: \(error.localizedDescription)")
            sessions[machineId, default: []].append(errMsg)
        }
    }
}
