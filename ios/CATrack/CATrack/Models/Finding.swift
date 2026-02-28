import Foundation

struct QuantifiedImpact: Codable, Hashable {
    var probabilityOfFailure: Double
    var timeToFailure: String
    var safetyRisk: Double
    var safetyLabel: String
    var costImpactRange: String
    var operationalImpact: String
}

enum Severity: String, Codable, Hashable {
    case pass = "PASS"
    case monitor = "MONITOR"
    case fail = "FAIL"
}

struct Finding: Identifiable, Codable, Hashable {
    var id: UUID
    var componentType: String
    var componentLocation: String
    var condition: String
    var severity: Severity
    var confidence: Double
    var impact: QuantifiedImpact
    var recommendation: String

    init(id: UUID = UUID(), componentType: String, componentLocation: String, condition: String,
         severity: Severity, confidence: Double, impact: QuantifiedImpact, recommendation: String) {
        self.id = id
        self.componentType = componentType
        self.componentLocation = componentLocation
        self.condition = condition
        self.severity = severity
        self.confidence = confidence
        self.impact = impact
        self.recommendation = recommendation
    }
}
