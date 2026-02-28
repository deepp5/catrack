import Foundation
import Combine

@MainActor
class InspectionSheetViewModel: ObservableObject {
    @Published var sheetsByMachine: [UUID: [SheetSection]] = [:]
    @Published var activeMachineId: UUID?

    var activeSections: [SheetSection] {
        guard let id = activeMachineId else { return [] }
        return sheetsByMachine[id] ?? SheetSection.defaultSections()
    }

    func sectionsFor(_ machineId: UUID) -> [SheetSection] {
        sheetsByMachine[machineId] ?? SheetSection.defaultSections()
    }

    func initSheet(for machineId: UUID) {
        if sheetsByMachine[machineId] == nil {
            sheetsByMachine[machineId] = SheetSection.defaultSections()
        }
        activeMachineId = machineId
    }

    func applyUpdates(_ updates: [SheetUpdate], for machineId: UUID) {
        var sections = sectionsFor(machineId)
        for update in updates {
            for sIdx in sections.indices where sections[sIdx].id == update.sheetSection {
                for fIdx in sections[sIdx].fields.indices where sections[sIdx].fields[fIdx].id == update.fieldId {
                    sections[sIdx].fields[fIdx].status = update.value
                    sections[sIdx].fields[fIdx].aiPrefilled = true
                    sections[sIdx].fields[fIdx].evidenceMediaId = update.evidenceMediaId
                }
            }
        }
        sheetsByMachine[machineId] = sections
    }

    func updateField(machineId: UUID, sectionId: String, fieldId: String, status: FindingSeverity, note: String) {
        guard var sections = sheetsByMachine[machineId] else { return }
        for sIdx in sections.indices where sections[sIdx].id == sectionId {
            for fIdx in sections[sIdx].fields.indices where sections[sIdx].fields[fIdx].id == fieldId {
                sections[sIdx].fields[fIdx].status = status
                sections[sIdx].fields[fIdx].note = note
            }
        }
        sheetsByMachine[machineId] = sections
    }

    func resetSheet(for machineId: UUID) {
        sheetsByMachine[machineId] = SheetSection.defaultSections()
    }
}
