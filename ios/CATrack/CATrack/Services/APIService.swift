import Foundation

// MARK: - APIService
class APIService {
    static let shared = APIService()
    private var baseURL: String = "http://192.168.10.201:8000"
//    private var baseURL: String = "http://127.0.0.1:8000"

    private init() {}

    func configure(baseURL: String) {
        self.baseURL = baseURL
    }
    
    func analyzeVideoCommand(userText: String,
                             currentChecklistState: [String: String],
                             framesBase64: [String]?) async throws -> FastAnalyzeResponse {

        guard let url = URL(string: "\(baseURL)/analyze-video-command") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_text": userText,
            "current_checklist_state": currentChecklistState,
            "frames": framesBase64 as Any
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FastAnalyzeResponse.self, from: data)
    }

    func analyzeFastAPI(inspectionId: String,
                        userText: String,
                        currentChecklistState: [String: String],
                        imagesBase64: [String]?) async throws -> FastAnalyzeResponse {

        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = FastAnalyzeRequest(
            inspectionId: inspectionId,
            userText: userText,
            currentChecklistState: currentChecklistState,
            images: imagesBase64
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FastAnalyzeResponse.self, from: data)
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
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
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

    func uploadVoiceNote(localURL: URL) async throws -> String {
        guard let url = URL(string: "\(baseURL)/interpret-audio") else {
            throw URLError(.badURL)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: localURL)
        var body = Data()
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"file\"; filename=\"voice_note.m4a\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: audio/m4a\r\n\r\n".utf8)
        body.append(fileData)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        struct VoiceResponse: Decodable { let transcript: String }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(VoiceResponse.self, from: data)
        return decoded.transcript
    }
}
