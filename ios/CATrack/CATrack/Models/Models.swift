import Foundation
import SwiftUI

// MARK: - Finding Severity
enum FindingSeverity: String, Codable, CaseIterable, Identifiable {
    case pass    = "PASS"
    case monitor = "MONITOR"
    case fail    = "FAIL"
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pass:    return .severityPass
        case .monitor: return .severityMon
        case .fail:    return .severityFail
        }
    }
    var shortLabel: String {
        switch self {
        case .pass:    return "PASS"
        case .monitor: return "MON"
        case .fail:    return "FAIL"
        }
    }
}

// MARK: - Machine
struct Machine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var model: String
    var serial: String
    var hours: Int
    var site: String
    var lastInspectedAt: Date?
    var overallStatus: FindingSeverity?

    static let samples: [Machine] = [
        Machine(model: "CAT 950 GC", serial: "CAT0950GC4821", hours: 4280, site: "North Quarry", lastInspectedAt: Date().addingTimeInterval(-7200), overallStatus: .fail),
        Machine(model: "CAT 966", serial: "CAT0966L2201", hours: 6840, site: "East Haul Road", lastInspectedAt: Date().addingTimeInterval(-86400), overallStatus: .monitor),
        Machine(model: "CAT 320 Excavator", serial: "CAT032012093", hours: 2105, site: "Bench 3", lastInspectedAt: Date().addingTimeInterval(-259200), overallStatus: .pass),
        Machine(model: "CAT D6 Dozer", serial: "CATD6R001128", hours: 9410, site: "West Bench", lastInspectedAt: Date().addingTimeInterval(-432000), overallStatus: .pass),
    ]
}

// MARK: - Media
enum MediaType: String, Codable {
    case image, video, audio, file
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video.fill"
        case .audio: return "mic.fill"
        case .file:  return "doc.fill"
        }
    }
    var label: String { rawValue.capitalized }
    var fileExtension: String {
        switch self {
        case .image: return "jpg"
        case .video: return "mp4"
        case .audio: return "m4a"
        case .file:  return "pdf"
        }
    }
}

struct AttachedMedia: Identifiable, Codable {
    var id: String = UUID().uuidString
    var type: MediaType
    var filename: String
    var localURL: URL?
    var remoteId: String?
    var thumbnailData: Data?
}

// MARK: - Quantification
struct Quantification: Codable {
    var failureProbability: Double
    var timeToFailure: String
    var safetyRisk: Int
    var safetyLabel: String
    var costLow: Double
    var costHigh: Double
    var downtimeLow: Double
    var downtimeHigh: Double

    var failureProbabilityPercent: String { "\(Int(failureProbability * 100))%" }
    var costRange: String { "$\(Int(costLow/1000))K–$\(Int(costHigh/1000))K" }
    var downtimeRange: String { "\(Int(downtimeLow))–\(Int(downtimeHigh))h" }

    var probSeverityColor: Color {
        failureProbability > 0.7 ? .severityFail :
        failureProbability > 0.4 ? .severityMon  : .severityPass
    }
    var safetySeverityColor: Color {
        safetyRisk > 60 ? .severityFail :
        safetyRisk > 30 ? .severityMon  : .severityPass
    }
}

// MARK: - Finding Card
struct FindingCard: Identifiable, Codable {
    var id: UUID = UUID()
    var componentType: String
    var componentLocation: String
    var condition: String
    var severity: FindingSeverity
    var confidence: Double
    var quantification: Quantification
    var evidenceMediaIds: [String] = []
    var seenBefore: Bool = false
    var trend: String?
}

// MARK: - Message
enum MessageRole: String, Codable { case user, assistant, system }

struct Message: Identifiable, Codable {
    var id: UUID = UUID()
    var role: MessageRole
    var text: String
    var media: [AttachedMedia] = []
    var findings: [FindingCard] = []
    var memoryNote: String?
    var createdAt: Date = Date()
    var voiceNoteURL: URL?        // ← ADD THIS
    var voiceNoteDuration: Int?

    static func system(_ text: String) -> Message {
        Message(role: .system, text: text)
    }
    static func user(text: String, media: [AttachedMedia] = []) -> Message {
        Message(role: .user, text: text, media: media)
    }
    static func assistant(text: String, findings: [FindingCard] = [], memoryNote: String? = nil) -> Message {
        Message(role: .assistant, text: text, findings: findings, memoryNote: memoryNote)
    }
    
    static func userVoice(url: URL, duration: Int) -> Message {
        Message(role: .user, text: "", voiceNoteURL: url, voiceNoteDuration: duration)
    }
}

// MARK: - Inspection Sheet Field
struct SheetField: Identifiable, Codable {
    var id: String
    var label: String
    var status: FindingSeverity
    var note: String
    var aiPrefilled: Bool
    var evidenceMediaId: String?
}

struct SheetSection: Identifiable, Codable {
    var id: String
    var title: String
    var fields: [SheetField]

    var overallStatus: FindingSeverity {
        if fields.contains(where: { $0.status == .fail })    { return .fail }
        if fields.contains(where: { $0.status == .monitor }) { return .monitor }
        return .pass
    }
}

// MARK: - Archive Record
struct ArchiveRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var machine: String
    var serial: String
    var date: Date
    var inspector: String
    var site: String
    var hours: Int
    var riskScore: Int
    var aiSummary: String
    var sections: [SheetSection]
    var findings: [FindingCard]
    var estimatedCost: Double
    var trends: [TrendItem]

    var riskScoreColor: Color {
        riskScore < 70 ? .severityFail :
        riskScore < 85 ? .severityMon  : .severityPass
    }
    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f.string(from: date)
    }

    static func == (lhs: ArchiveRecord, rhs: ArchiveRecord) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TrendItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String
    var value: String
    var delta: String
    var direction: TrendDirection
}

enum TrendDirection: String, Codable, Hashable {
    case better, worse, same
    var color: Color {
        switch self {
        case .better: return .severityPass
        case .worse:  return .severityFail
        case .same:   return .appMuted
        }
    }
}

// MARK: - API Response
struct AnalyzeResponse: Decodable {
    var assistantMessage: String
    var findings: [FindingCard]
    var inspectionSheetUpdates: [SheetUpdate]
    var memoryNote: String?
}

struct SheetUpdate: Decodable {
    var sheetSection: String
    var fieldId: String
    var value: FindingSeverity
    var evidenceMediaId: String?
}


// MARK: - FastAPI Analyze Models
struct FastAnalyzeRequest: Encodable {
    let inspectionId: String
    let userText: String
    let images: [String]?
}

struct FastChecklistUpdate: Decodable {
    let status: String // PASS/MONITOR/FAIL
    let note: String?
}

struct FastAnalyzeResponse: Decodable {
    let intent: String
    let checklistUpdates: [String: FastChecklistUpdate]
    let riskScore: String?
    let answer: String?
    let followUpQuestions: [String]
}
