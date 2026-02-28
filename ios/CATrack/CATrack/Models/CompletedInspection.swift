import Foundation

enum OverallRisk: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

struct CompletedInspection: Identifiable, Codable {
    var id: UUID
    var machine: Machine
    var sheet: InspectionSheet
    var allFindings: [Finding]
    var summary: String
    var overallRisk: OverallRisk
    var completedAt: Date
    var trendNotes: String?

    init(id: UUID = UUID(), machine: Machine, sheet: InspectionSheet, allFindings: [Finding],
         summary: String, overallRisk: OverallRisk, completedAt: Date = Date(), trendNotes: String? = nil) {
        self.id = id
        self.machine = machine
        self.sheet = sheet
        self.allFindings = allFindings
        self.summary = summary
        self.overallRisk = overallRisk
        self.completedAt = completedAt
        self.trendNotes = trendNotes
    }
}
