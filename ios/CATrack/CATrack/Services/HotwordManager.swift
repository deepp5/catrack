import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class HotwordManager: ObservableObject {

    enum ListenState: Equatable {
        case idle
        case triggered              // heard "hey cat", waiting for command
        case finalCommand(String)
        case error(String)
    }

    static let shared = HotwordManager()

    @Published var state: ListenState = .idle

    private let audioEngine  = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:    SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))

    private var hasTriggered   = false
    private var commandBuffer  = ""
    private var lastUpdateTime = Date()
    private var silenceTask:   Task<Void, Never>?
    private var restartCount   = 0
    private let maxRestarts    = 10

    private init() {}

    // MARK: - Permissions

    func requestPermissions() async throws {
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission {
                    cont.resume(returning: $0)
                }
            }
        }
        guard micGranted else {
            throw NSError(domain: "Hotword", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }

        let speechStatus: SFSpeechRecognizerAuthorizationStatus =
            await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
        guard speechStatus == .authorized else {
            throw NSError(domain: "Hotword", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied"])
        }
    }

    // MARK: - Start / Stop

    func start() throws {
        stopEngine()

        hasTriggered  = false
        commandBuffer = ""
        state         = .idle

        let session = AVAudioSession.sharedInstance()
        // .playAndRecord + .mixWithOthers coexists with AVCaptureSession when
        // the capture session has NO audio input (setSessionAudioEnabled(false)).
        // We must NOT use .record (exclusive) — that prevents the camera from
        // running at all, causing black screen and -12710 errors.
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // Audio thread — just feed the request buffer
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            // Callback may arrive on any thread — always hop to MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleRecognitionResult(result: result, error: error)
            }
        }

        startSilenceLoop()
    }

    func stop() {
        silenceTask?.cancel()
        silenceTask = nil
        stopEngine()
        hasTriggered  = false
        commandBuffer = ""
        state         = .idle
        restartCount  = 0
    }

    /// Pause before camera frame capture — releases mic tap temporarily.
    func pauseAudio() {
        silenceTask?.cancel()
        silenceTask = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // Leave AVAudioSession active so camera keeps its session
    }

    /// Resume listening after camera snapshot.
    func resumeAfterCapture() {
        hasTriggered  = false
        commandBuffer = ""
        state         = .idle
        // Small delay so the audio engine teardown from pauseAudio() fully completes
        // before we reinstall the tap.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 s
            do {
                try self.start()
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Engine helpers

    private func stopEngine() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    //testing adding to github
    private func handleRecognitionResult(
        result: SFSpeechRecognitionResult?,
        error: Error?
    ) {
        if let error {
            let code = (error as NSError).code
            // Code 301 = Apple's legitimate ~60 s session expiry — restart cleanly.
            // Code 1110 = audio hardware not available (camera session still owns mic) — do NOT retry.
            // Any other code while engine is still running = unexpected, attempt one restart.
            if code == 301 && restartCount < maxRestarts {
                restartCount += 1
                print("HotwordManager: restart #\(restartCount) after 60s expiry")
                try? start()
            } else if code == 1110 {
                // Hardware mic locked by another session — stop completely and surface the error.
                stopEngine()
                state = .error("Microphone unavailable. Camera may be holding the mic.")
                print("HotwordManager: mic unavailable (1110) — stopping")
            } else if audioEngine.isRunning && restartCount < maxRestarts {
                restartCount += 1
                print("HotwordManager: restart #\(restartCount) after error \(code)")
                try? start()
            } else if restartCount >= maxRestarts {
                state = .error("Speech recognition unavailable. Please restart.")
            }
            return
        }

        guard let result else { return }
        let text = result.bestTranscription.formattedString.lowercased()
        processTranscript(text, isFinal: result.isFinal)

        // After a final result Apple closes the task — restart for a fresh window.
        if result.isFinal {
            restartCount = 0
            try? start()
        }
    }

    // MARK: - Transcript processing

    private let triggerPhrases = ["hey cat", "hey cats", "hay cat", "a cat", "hey cap"]

    private func processTranscript(_ text: String, isFinal: Bool) {
        if !hasTriggered {
            if triggerPhrases.contains(where: { text.contains($0) }) {
                hasTriggered   = true
                commandBuffer  = ""
                lastUpdateTime = Date()
                state          = .triggered
            }
            return
        }

        // Extract everything after the last occurrence of a trigger phrase
        var afterTrigger = ""
        for phrase in triggerPhrases {
            if let range = text.range(of: phrase, options: .backwards) {
                let candidate = String(text[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.count > afterTrigger.count {
                    afterTrigger = candidate
                }
            }
        }

        if !afterTrigger.isEmpty {
            commandBuffer  = afterTrigger
            lastUpdateTime = Date()
        }

        if isFinal { emitCommand() }
    }

    private func emitCommand() {
        let cmd = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else {
            hasTriggered  = false
            commandBuffer = ""
            state         = .idle
            return
        }
        state         = .finalCommand(cmd)
        hasTriggered  = false
        commandBuffer = ""
    }

    // MARK: - Silence detection (Swift Concurrency — avoids Timer threading issues)

    private func startSilenceLoop() {
        silenceTask?.cancel()
        silenceTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 s
                if Task.isCancelled { break }
                checkSilence()
            }
        }
    }

    private func checkSilence() {
        guard hasTriggered, !commandBuffer.isEmpty else { return }
        if Date().timeIntervalSince(lastUpdateTime) > 1.8 { emitCommand() }
    }
}
