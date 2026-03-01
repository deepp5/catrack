import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class HotwordManager: ObservableObject {

    enum ListenState: Equatable {
        case idle
        case triggered
        case finalCommand(String)
        case error(String)
    }

    static let shared = HotwordManager()

    @Published var state: ListenState = .idle

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))

    private var hasTriggered = false
    private var commandBuffer = ""
    private var silenceTimer: Timer?
    private var lastUpdateTime = Date()

    // When true, bypass wake word and treat any final speech as a command
    var continuousMode: Bool = false

    private init() {}

    // MARK: - Permissions

    func requestPermissions() async throws {
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in cont.resume(returning: ok) }
            }
        }
        guard micGranted else {
            throw NSError(domain: "Hotword", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        }

        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        guard speechStatus == .authorized else {
            throw NSError(domain: "Hotword", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied"])
        }
    }

    // MARK: - Start / Stop

    func start() throws {
        stop()

        hasTriggered = false
        commandBuffer = ""
        state = .idle

        let session = AVAudioSession.sharedInstance()

        // Key fix: use .playAndRecord with .mixWithOthers so we don't fight AVCaptureSession
        // over the audio hardware. This lets both coexist on device.
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw NSError(domain: "Hotword", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create recognition request"])
        }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let error {
                print("Speech error:", error.localizedDescription)

                // If we are intentionally running continuous mode or mid-command,
                // do NOT auto-restart aggressively. Let resumeAfterCapture() handle restarts.
                if self.continuousMode {
                    return
                }

                Task { @MainActor in
                    guard self.audioEngine.isRunning else { return }
                    try? self.start()
                }
                return
            }

            guard let result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            Task { @MainActor in self.processTranscript(text, isFinal: result.isFinal) }
        }

        startSilenceTimer()
    }

    func stop() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Don't deactivate the session — let AVCaptureSession keep it
        // try? AVAudioSession.sharedInstance().setActive(false) ← removed intentionally

        hasTriggered = false
        commandBuffer = ""
        state = .idle
    }

    /// Pause speech engine before camera snapshot (releases mic tap briefly)
    func pauseAudio() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // Don't touch AVAudioSession — let camera keep it
    }

    /// Resume after camera snapshot — resets for next command
    func resumeAfterCapture() {
        hasTriggered = false
        commandBuffer = ""
        state = .idle
        do {
            try start()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Transcript

    private func processTranscript(_ text: String, isFinal: Bool) {
        // Continuous guided mode: bypass wake word
        if continuousMode {
            if isFinal {
                let cmd = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cmd.isEmpty {
                    state = .finalCommand(cmd)
                }
            }
            return
        }

        if !hasTriggered {
            if text.contains("hey cat") {
                hasTriggered = true
                commandBuffer = ""
                lastUpdateTime = Date()
                state = .triggered
            }
            return
        }

        if let range = text.range(of: "hey cat", options: .backwards) {
            let after = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                commandBuffer = after
                lastUpdateTime = Date()
            }
        }

        if isFinal { emitCommand() }
    }

    private func emitCommand() {
        let cmd = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else {
            hasTriggered = false
            commandBuffer = ""
            state = .idle
            return
        }
        state = .finalCommand(cmd)
        hasTriggered = false
        commandBuffer = ""
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.checkSilence() }
        }
    }

    private func checkSilence() {
        guard hasTriggered, !commandBuffer.isEmpty else { return }
        if Date().timeIntervalSince(lastUpdateTime) > 1.8 { emitCommand() }
    }
}
