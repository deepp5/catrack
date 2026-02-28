import Foundation
import Combine

@MainActor
class MachineViewModel: ObservableObject {
    @Published var machines: [Machine] = []
    @Published var selectedMachine: Machine?

    func addMachine(_ machine: Machine) {
        machines.append(machine)
    }

    func selectMachine(_ machine: Machine) {
        selectedMachine = machine
    }
}
