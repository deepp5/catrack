import Foundation  // ← ADD THIS
import Combine     // ← ADD THIS

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

    private func persist() {
        let stored = Stored(activeMachineId: activeMachineId, activeChatMachine: activeChatMachine)
        do {
            let data = try JSONEncoder().encode(stored)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // Failing to persist should not crash the app.
            print("MachineStore.persist encode error: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let stored = try JSONDecoder().decode(Stored.self, from: data)
            self.activeMachineId = stored.activeMachineId
            self.activeChatMachine = stored.activeChatMachine
        } catch {
            // If stored data is incompatible, ignore it.
            print("MachineStore.load decode error: \(error)")
        }
    }
    //testing adding to github
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
}
