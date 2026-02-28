import Foundation
import Combine

@MainActor
class MachineStore: ObservableObject {
    @Published var machines: [Machine] = Machine.samples
    @Published var activeMachineId: UUID?

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

    func updateStatus(machineId: UUID, status: FindingSeverity) {
        guard let idx = machines.firstIndex(where: { $0.id == machineId }) else { return }
        machines[idx].overallStatus = status
        machines[idx].lastInspectedAt = Date()
    }
}
