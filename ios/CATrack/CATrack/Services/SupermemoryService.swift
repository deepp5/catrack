import Foundation

class SupermemoryService {
    static let shared = SupermemoryService()
    private let apiKey = "YOUR_SUPERMEMORY_API_KEY"
    private let baseURL = "https://api.supermemory.ai/v1"

    private init() {}

    func storeFinding(_ finding: Finding, machineId: UUID) async throws {
        guard let url = URL(string: "\(baseURL)/memories") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "content": "Machine \(machineId.uuidString): \(finding.componentType) at \(finding.componentLocation) — \(finding.condition). Severity: \(finding.severity.rawValue). Confidence: \(finding.confidence). Recommendation: \(finding.recommendation)",
            "tags": [machineId.uuidString, finding.componentType, finding.severity.rawValue]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }

    func retrieveHistory(for machineId: UUID) async throws -> String {
        guard let url = URL(string: "\(baseURL)/search?query=\(machineId.uuidString)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        struct HistoryResponse: Codable {
            let results: [HistoryEntry]
        }
        struct HistoryEntry: Codable {
            let content: String
        }

        let decoded = try JSONDecoder().decode(HistoryResponse.self, from: data)
        return decoded.results.map { $0.content }.joined(separator: "\n")
    }
}
