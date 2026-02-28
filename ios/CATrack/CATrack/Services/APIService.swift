import Foundation

// MARK: - APIService
class APIService {
    static let shared = APIService()
    private var baseURL: String = "https://your-backend.com/api"

    private init() {}

    func configure(baseURL: String) { 
        self.baseURL = baseURL
    }

    func analyze(message: String, machineId: UUID, media: [AttachedMedia]) async throws -> AnalyzeResponse {
        guard let url = URL(string: "\(baseURL)/inspect") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": message,
            "machine_id": machineId.uuidString,
            "media_ids": media.compactMap { $0.remoteId }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AnalyzeResponse.self, from: data)
    }

    func uploadMedia(localURL: URL, machineId: UUID) async throws -> String {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw URLError(.badURL)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: localURL)
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"
        body.append(contentsOf: boundaryPrefix.utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"file\"; filename=\"\(localURL.lastPathComponent)\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: application/octet-stream\r\n\r\n".utf8)
        body.append(fileData)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)

        struct UploadResponse: Decodable { let mediaId: String }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(UploadResponse.self, from: data)
        return decoded.mediaId
    }
}
