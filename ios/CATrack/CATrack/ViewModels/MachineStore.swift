import Foundation
import Combine

@MainActor
class MachineStore: ObservableObject {
    @Published var machines: [Machine] = Machine.samples
    @Published var activeMachineId: UUID? {
        didSet { persist() }
    }
    @Published var activeChatMachine: Machine? = nil {
        didSet { persist() }
    }

    private let storageKey = "catrack.machinestore"

    private struct Stored: Codable {
        var activeMachineId: UUID?
        var activeChatMachine: Machine?
    }

    init() { load() }

    var activeMachine: Machine? {
        guard let id = activeMachineId else { return nil }
        return machines.first { $0.id == id }
    }

    func addMachine(_ machine: Machine) {
        machines.append(machine)
    }

    func removeMachine(id: UUID) {
        machines.removeAll { $0.id == id }
        if activeMachineId == id { activeMachineId = nil }
    }

    func selectMachine(_ machine: Machine) {
        activeMachineId = machine.id
    }

    func setActiveChatMachine(_ machine: Machine) {
        activeChatMachine = machine
    }

    func clearActiveChatMachine() {
        activeChatMachine = nil
    }

    func updateStatus(machineId: UUID, status: FindingSeverity) {
        guard let idx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        machines[idx].overallStatus = status
        machines[idx].lastInspectedAt = Date()
    }

    // MARK: - Persistence

    private func persist() {
        let stored = Stored(activeMachineId: activeMachineId, activeChatMachine: activeChatMachine)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        activeMachineId   = stored.activeMachineId
        activeChatMachine = stored.activeChatMachine
    }
}
