import Foundation

enum MediaAttachmentType: String, Codable, Hashable {
    case image, video, audio, file
}

struct MediaAttachment: Identifiable, Codable, Hashable {
    var id: UUID
    var type: MediaAttachmentType
    var localURL: URL
    var thumbnailData: Data?

    init(id: UUID = UUID(), type: MediaAttachmentType, localURL: URL, thumbnailData: Data? = nil) {
        self.id = id
        self.type = type
        self.localURL = localURL
        self.thumbnailData = thumbnailData
    }
}

struct SheetUpdate: Identifiable, Codable, Hashable {
    var id: UUID
    var sectionName: String
    var fieldId: UUID
    var value: String
    var evidenceMediaId: UUID?

    init(id: UUID = UUID(), sectionName: String, fieldId: UUID, value: String, evidenceMediaId: UUID? = nil) {
        self.id = id
        self.sectionName = sectionName
        self.fieldId = fieldId
        self.value = value
        self.evidenceMediaId = evidenceMediaId
    }
}

enum ChatRole: String, Codable {
    case user, assistant
}

struct ChatMessage: Identifiable, Codable {
    var id: UUID
    var role: ChatRole
    var text: String
    var attachments: [MediaAttachment]
    var findings: [Finding]?
    var sheetUpdates: [SheetUpdate]?
    var timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, text: String, attachments: [MediaAttachment] = [],
         findings: [Finding]? = nil, sheetUpdates: [SheetUpdate]? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.attachments = attachments
        self.findings = findings
        self.sheetUpdates = sheetUpdates
        self.timestamp = timestamp
    }
}
