import Foundation

class APIService {
    static let shared = APIService()
    private let baseURL = "http://127.0.0.1:8000"

    private init() {}

    func sendInspectionMessage(text: String, machineId: UUID, attachments: [MediaAttachment]) async throws -> ChatMessage {
        guard let url = URL(string: "\(baseURL)/api/inspect") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": text,
            "machine_id": machineId.uuidString
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        struct APIResponse: Codable {
            let message: String
            let findings: [Finding]?
            let sheetUpdates: [SheetUpdate]?
        }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        return ChatMessage(
            role: .assistant,
            text: decoded.message,
            findings: decoded.findings,
            sheetUpdates: decoded.sheetUpdates
        )
    }

    func uploadMedia(localURL: URL, machineId: UUID) async throws -> UUID {
        guard let url = URL(string: "\(baseURL)/api/upload") else {
            throw URLError(.badURL)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: localURL)
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(localURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)

        struct UploadResponse: Codable {
            let media_id: String
        }

        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
        return UUID(uuidString: decoded.media_id) ?? UUID()
    }
}
