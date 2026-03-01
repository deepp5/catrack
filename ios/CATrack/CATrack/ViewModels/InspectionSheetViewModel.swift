import Foundation
import Combine

@MainActor
class InspectionSheetViewModel: ObservableObject {
    @Published var sheetsByMachine: [UUID: [SheetSection]] = [:] {
        didSet { persist() }
    }
    @Published var activeMachineId: UUID? {
        didSet { persist() }
    }

    private let storageKey = "catrack.sheetvm"

    private struct Stored: Codable {
        var sheetsByMachine: [String: [SheetSection]]
        var activeMachineId: UUID?
    }

    init() { load() }

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

    // MARK: - Persistence

    private func persist() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: sheetsByMachine.map { ($0.key.uuidString, $0.value) })
        let stored = Stored(sheetsByMachine: stringKeyed, activeMachineId: activeMachineId)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        sheetsByMachine = Dictionary(uniqueKeysWithValues: stored.sheetsByMachine.compactMap { k, v in
            guard let uuid = UUID(uuidString: k) else { return nil }
            return (uuid, v)
        })
        activeMachineId = stored.activeMachineId
    }
}
