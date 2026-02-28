import Foundation

struct InspectionField: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var value: String
    var severity: Severity?
    var evidenceMediaId: UUID?

    init(id: UUID = UUID(), label: String, value: String = "", severity: Severity? = nil, evidenceMediaId: UUID? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.severity = severity
        self.evidenceMediaId = evidenceMediaId
    }
}

struct InspectionSection: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var fields: [InspectionField]

    init(id: UUID = UUID(), title: String, fields: [InspectionField]) {
        self.id = id
        self.title = title
        self.fields = fields
    }
}

struct InspectionSheet: Identifiable, Codable {
    var id: UUID
    var machineId: UUID
    var templateName: String
    var sections: [InspectionSection]
    var isFinalized: Bool
    var createdAt: Date

    init(id: UUID = UUID(), machineId: UUID, templateName: String = "Daily Walkaround / TA1 Safety",
         sections: [InspectionSection], isFinalized: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.machineId = machineId
        self.templateName = templateName
        self.sections = sections
        self.isFinalized = isFinalized
        self.createdAt = createdAt
    }

    static func defaultSheet(for machineId: UUID) -> InspectionSheet {
        let sections = [
            InspectionSection(title: "Steps/Handrails/Access", fields: [
                InspectionField(label: "Steps Condition"),
                InspectionField(label: "Handrails Secure"),
                InspectionField(label: "Access Clear")
            ]),
            InspectionSection(title: "Wheels/Rims/Lug Nuts", fields: [
                InspectionField(label: "Tires Condition"),
                InspectionField(label: "Rims Damage"),
                InspectionField(label: "Lug Nuts Tight")
            ]),
            InspectionSection(title: "Cooling System/Hoses", fields: [
                InspectionField(label: "Coolant Level"),
                InspectionField(label: "Hoses Condition"),
                InspectionField(label: "Radiator Clear")
            ]),
            InspectionSection(title: "Glass/Mirrors", fields: [
                InspectionField(label: "Windshield Condition"),
                InspectionField(label: "Mirrors Secure"),
                InspectionField(label: "Visibility Clear")
            ])
        ]
        return InspectionSheet(machineId: machineId, sections: sections)
    }
}
