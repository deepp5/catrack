import Foundation

// MARK: - APIService
class APIService {
    static let shared = APIService()
    // NOTE: 127.0.0.1 works only on the iOS Simulator.
    // On a real device, set this to your Mac's LAN IP (e.g., http://192.168.x.x:8000).
    private var baseURL: String = "http://127.0.0.1:8000"

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

    // MARK: - FastAPI endpoints

    /// Start a new inspection for a given machine model.
    func startInspection(machineModel: String) async throws -> StartInspectionResponse {
        guard let url = URL(string: "\(baseURL)/start-inspection?machine_model=\(machineModel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? machineModel)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(StartInspectionResponse.self, from: data)
    }

    /// Analyze user input for an inspection (text/images).
    func analyze(inspectionId: String,
                 machineModel: String? = nil,
                 userText: String,
                 imagesBase64: [String]? = nil) async throws -> AnalyzeResponseBody {

        guard let url = URL(string: "\(baseURL)/analyze") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AnalyzeRequestBody(
            inspectionId: inspectionId,
            machineModel: machineModel,
            userText: userText,
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
        return try decoder.decode(AnalyzeResponseBody.self, from: data)
    }

    /// Generate a final report for an inspection.
    func generateReport(inspectionId: String) async throws -> GenerateReportResponseBody {
        guard let url = URL(string: "\(baseURL)/generate-report") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = GenerateReportRequestBody(inspectionId: inspectionId)
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
        return try decoder.decode(GenerateReportResponseBody.self, from: data)
    }

    /// Analyze a voice command for an inspection (multipart audio).
    func voiceAnalyze(inspectionId: String, localAudioURL: URL) async throws -> VoiceAnalyzeResponseBody {
        guard let url = URL(string: "\(baseURL)/voice-analyze") else {
            throw URLError(.badURL)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: localAudioURL)
        var body = Data()

        // inspection_id field
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"inspection_id\"\r\n\r\n".utf8)
        body.append(contentsOf: "\(inspectionId)\r\n".utf8)

        // audio_file field
        body.append(contentsOf: "--\(boundary)\r\n".utf8)
        body.append(contentsOf: "Content-Disposition: form-data; name=\"audio_file\"; filename=\"\(localAudioURL.lastPathComponent)\"\r\n".utf8)
        body.append(contentsOf: "Content-Type: audio/m4a\r\n\r\n".utf8)
        body.append(fileData)
        body.append(contentsOf: "\r\n".utf8)

        body.append(contentsOf: "--\(boundary)--\r\n".utf8)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(VoiceAnalyzeResponseBody.self, from: data)
    }

    /// Rebuild sound baseline for a machine and mode.
    func soundBaselineRebuild(machineId: String, mode: String = "idle") async throws -> SoundBaselineResponse {
        guard let url = URL(string: "\(baseURL)/sound/baseline/rebuild?machine_id=\(machineId)&mode=\(mode)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SoundBaselineResponse.self, from: data)
    }

    /// Check sound anomaly for a given media and machine.
    func soundCheck(mediaId: String, machineId: String, mode: String = "idle") async throws -> SoundCheckResponse {
        guard let url = URL(string: "\(baseURL)/sound/check?media_id=\(mediaId)&machine_id=\(machineId)&mode=\(mode)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Bad server response"
            throw NSError(domain: "APIService", code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SoundCheckResponse.self, from: data)
    }
}

// MARK: - DTOs (FastAPI)
struct StartInspectionResponse: Decodable {
    let id: String
    let machineModel: String
    let checklistJson: [String: String]
    let overallStatus: String
    let createdAt: String
}

struct AnalyzeRequestBody: Encodable {
    let inspectionId: String
    let machineModel: String?
    let userText: String
    let images: [String]?
}

struct AnalyzeResponseBody: Decodable {
    let intent: String
    let checklistUpdates: [String: ChecklistUpdate]?
    let riskScore: String?
    let answer: String?
    let followUpQuestions: [String]?
    let inspectionId: String?

    struct ChecklistUpdate: Decodable {
        let status: String
        let note: String?
    }
}

struct GenerateReportRequestBody: Encodable {
    let inspectionId: String
}

struct GenerateReportResponseBody: Decodable {
    let executiveSummary: String
    let criticalFindings: [String]
    let recommendations: [String]
    let operationalReadiness: String
    let overallRisk: String
}

struct VoiceAnalyzeResponseBody: Decodable {
    let intent: String
    let checklistUpdates: [String: AnalyzeResponseBody.ChecklistUpdate]?
    let riskScore: String?
    let answer: String?
    let followUpQuestions: [String]?
    let transcript: String?
    let inspectionId: String?
}

struct SoundBaselineResponse: Decodable {
    let machineId: String
    let mode: String
    let nGood: Int
    let nBad: Int
    let maxGood: Double
    let minBad: Double?
    let threshold: Double
}

struct SoundCheckResponse: Decodable {
    let mediaId: String
    let bucket: String?
    let path: String?
    let anomalyScore: Double
    let threshold: Double
    let predictedLabel: String
}
