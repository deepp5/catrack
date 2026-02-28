import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class HotwordManager: ObservableObject {
    static let shared = HotwordManager()

    @Published var isListening = false
    @Published var isTriggered = false
    @Published var liveCaption: String = ""
    @Published var confirmedCommand: String? = nil

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var startedAtTrigger = false
    private var commandBuffer = ""

    private var lastNonEmptyTime = Date()
    private var silenceTimer: Timer?

    // Tracks whether we temporarily paused for a camera snapshot
    private(set) var isPaused = false

    private init() {}

    func requestPermissions() async throws {
        let mic = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
        if !mic {
            throw NSError(domain: "Hotword", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mic permission denied"])
        }

        let speechAuth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        if speechAuth != .authorized {
            throw NSError(domain: "Hotword", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech permission denied"])
        }
    }

    /// Call BEFORE taking a camera snapshot — releases audio session so AVCaptureSession can use it
    func pause() {
        guard isListening, !isPaused else { return }
        isPaused = true

        silenceTimer?.invalidate()
        silenceTimer = nil

        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Call AFTER the camera snapshot is done — resumes listening for the next "Hey Cat"
    func resume() {
        guard isListening, isPaused else { return }
        isPaused = false

        // Clear state so user can issue another command fresh
        isTriggered = false
        startedAtTrigger = false
        commandBuffer = ""
        confirmedCommand = nil
        liveCaption = ""

        do {
            try startAudioEngine()
        } catch {
            print("HotwordManager resume error:", error)
        }
    }

    func start() throws {
        if isListening { return }
        isListening = true
        isPaused = false
        confirmedCommand = nil
        isTriggered = false
        liveCaption = ""
        startedAtTrigger = false
        commandBuffer = ""

        try startAudioEngine()
    }

    private func startAudioEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothA2DP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else {
            throw NSError(domain: "Hotword", code: 3, userInfo: [NSLocalizedDescriptionKey: "No request"])
        }
        request.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    // Speech recognizer auto-times out ~1min — restart silently if still active
                    guard self.isListening, !self.isPaused else { return }
                    print("Speech task ended, restarting:", error.localizedDescription)
                    try? self.startAudioEngine()
                }
                return
            }

            guard let result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            Task { @MainActor in
                self.liveCaption = text
                self.handleTranscript(text)
            }
        }

        startSilenceTimer()
    }

    func stop() {
        isListening = false
        isPaused = false
        silenceTimer?.invalidate()
        silenceTimer = nil

        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleTranscript(_ text: String) {
        if !isTriggered, text.contains("hey cat") {
            isTriggered = true
            startedAtTrigger = true
            commandBuffer = ""
            lastNonEmptyTime = Date()
            return
        }

        if isTriggered && startedAtTrigger {
            if let range = text.range(of: "hey cat", options: .backwards) {
                let after = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !after.isEmpty {
                    commandBuffer = after
                    lastNonEmptyTime = Date()
                }
            }
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.checkForEndOfSpeech()
            }
        }
    }

    private func checkForEndOfSpeech() {
        guard isTriggered else { return }

        // 1.8s gives enough time to finish speaking after "hey cat"
        if Date().timeIntervalSince(lastNonEmptyTime) > 1.8 {
            let final = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

            // Only fire if we actually captured a command — ignore bare wake word with nothing after
            if !final.isEmpty {
                confirmedCommand = final
            } else {
                // Just reset, keep listening — don't crash or fire empty command
                isTriggered = false
                startedAtTrigger = false
                commandBuffer = ""
            }

            isTriggered = false
            startedAtTrigger = false
            commandBuffer = ""
        }
    }
}
