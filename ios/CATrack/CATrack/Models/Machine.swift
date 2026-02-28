import Foundation

struct Machine: Identifiable, Codable, Hashable {
    var id: UUID
    var model: String
    var serialNumber: String
    var hours: Double
    var site: String
    var createdAt: Date

    init(id: UUID = UUID(), model: String, serialNumber: String, hours: Double, site: String, createdAt: Date = Date()) {
        self.id = id
        self.model = model
        self.serialNumber = serialNumber
        self.hours = hours
        self.site = site
        self.createdAt = createdAt
    }
}
