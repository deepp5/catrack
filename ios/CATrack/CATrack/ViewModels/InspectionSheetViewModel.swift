import Foundation
import Combine

@MainActor
class InspectionSheetViewModel: ObservableObject {
    @Published var sheets: [UUID: InspectionSheet] = [:]

    func getOrCreateSheet(for machineId: UUID) -> InspectionSheet {
        if let sheet = sheets[machineId] {
            return sheet
        }
        let sheet = InspectionSheet.defaultSheet(for: machineId)
        sheets[machineId] = sheet
        return sheet
    }

    func applyUpdates(_ updates: [SheetUpdate], for machineId: UUID) {
        var sheet = getOrCreateSheet(for: machineId)
        for update in updates {
            for sIdx in sheet.sections.indices {
                if sheet.sections[sIdx].title == update.sectionName {
                    for fIdx in sheet.sections[sIdx].fields.indices {
                        if sheet.sections[sIdx].fields[fIdx].id == update.fieldId {
                            sheet.sections[sIdx].fields[fIdx].value = update.value
                            sheet.sections[sIdx].fields[fIdx].evidenceMediaId = update.evidenceMediaId
                        }
                    }
                }
            }
        }
        sheets[machineId] = sheet
    }

    func updateField(machineId: UUID, sectionId: UUID, fieldId: UUID, value: String) {
        guard var sheet = sheets[machineId] else { return }
        for sIdx in sheet.sections.indices where sheet.sections[sIdx].id == sectionId {
            for fIdx in sheet.sections[sIdx].fields.indices where sheet.sections[sIdx].fields[fIdx].id == fieldId {
                sheet.sections[sIdx].fields[fIdx].value = value
            }
        }
        sheets[machineId] = sheet
    }

    func finalizeSheet(for machineId: UUID) {
        guard var sheet = sheets[machineId] else { return }
        sheet.isFinalized = true
        sheets[machineId] = sheet
    }
}
