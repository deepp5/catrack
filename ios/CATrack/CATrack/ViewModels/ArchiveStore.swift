import Foundation
import Combine

// MARK: - ArchiveStore
@MainActor
class ArchiveStore: ObservableObject {
    @Published var records: [ArchiveRecord] = []

    func add(_ record: ArchiveRecord) {
        records.insert(record, at: 0)
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
    }

    func recordsFor(serial: String) -> [ArchiveRecord] {
        records.filter { $0.serial == serial }.sorted { $0.date > $1.date }
    }
}

// MARK: - SettingsStore
@MainActor
class SettingsStore: ObservableObject {
    @Published var inspectorName: String = "Inspector"
    @Published var backendURL: String = "https://your-backend.com/api"
    @Published var enableMemory: Bool = true
    @Published var enableNotifications: Bool = true
    @Published var autoFinalizeSheet: Bool = false
    @Published var defaultSite: String = ""
    @Published var showConfidenceScores: Bool = true
    @Published var showQuantification: Bool = true
}
