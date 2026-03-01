//import Foundation
//import Speech
//import AVFoundation
//import Combine
//
//@MainActor
//final class HotwordManager: ObservableObject {
//
//    enum ListenState: Equatable {
//        case idle
//        case triggered
//        case finalCommand(String)
//        case error(String)
//    }
//
//    static let shared = HotwordManager()
//
//    @Published var state: ListenState = .idle
//
//    private let audioEngine = AVAudioEngine()
//    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
//    private var recognitionTask: SFSpeechRecognitionTask?
//    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
//
//    private var hasTriggered = false
//    private var commandBuffer = ""
//    private var silenceTimer: Timer?
//    private var lastUpdateTime = Date()
//
//    // When true, bypass wake word and treat any final speech as a command
//    var continuousMode: Bool = false
//
//    private init() {}
//
//    // MARK: - Permissions
//
//    func requestPermissions() async throws {
//        let micGranted: Bool
//        if #available(iOS 17.0, *) {
//            micGranted = await AVAudioApplication.requestRecordPermission()
//        } else {
//            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
//                AVAudioSession.sharedInstance().requestRecordPermission { ok in cont.resume(returning: ok) }
//            }
//        }
//        guard micGranted else {
//            throw NSError(domain: "Hotword", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
//        }
//
//        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
//            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
//        }
//        guard speechStatus == .authorized else {
//            throw NSError(domain: "Hotword", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied"])
//        }
//    }
//
//    // MARK: - Start / Stop
//
//    func start() throws {
//        stop()
//
//        hasTriggered = false
//        commandBuffer = ""
//        state = .idle
//
//        let session = AVAudioSession.sharedInstance()
//
//        // Key fix: use .playAndRecord with .mixWithOthers so we don't fight AVCaptureSession
//        // over the audio hardware. This lets both coexist on device.
//        try session.setCategory(
//            .playAndRecord,
//            mode: .measurement,
//            options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker]
//        )
//        try session.setActive(true, options: .notifyOthersOnDeactivation)
//
//        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
//        guard let recognitionRequest else {
//            throw NSError(domain: "Hotword", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create recognition request"])
//        }
//        recognitionRequest.shouldReportPartialResults = true
//
//        let inputNode = audioEngine.inputNode
//        let format = inputNode.outputFormat(forBus: 0)
//        inputNode.removeTap(onBus: 0)
//        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
//            self?.recognitionRequest?.append(buffer)
//        }
//
//        audioEngine.prepare()
//        try audioEngine.start()
//
//        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
//            guard let self else { return }
//
//            if let error {
//                print("Speech error:", error.localizedDescription)
//
//                Task { @MainActor in
//                    // If audio engine stopped, restart cleanly
//                    if !self.audioEngine.isRunning {
//                        try? self.start()
//                        return
//                    }
//
//                    // In continuous guided mode, restart quietly
//                    if self.continuousMode {
//                        try? self.start()
//                        return
//                    }
//
//                    // Normal wake-word mode restart
//                    try? self.start()
//                }
//
//                return
//            }
//
//            guard let result else { return }
//            let text = result.bestTranscription.formattedString.lowercased()
//            Task { @MainActor in self.processTranscript(text, isFinal: result.isFinal) }
//        }
//
//        startSilenceTimer()
//    }
//
//    func stop() {
//        silenceTimer?.invalidate()
//        silenceTimer = nil
//
//        recognitionTask?.cancel()
//        recognitionTask = nil
//
//        recognitionRequest?.endAudio()
//        recognitionRequest = nil
//
//        if audioEngine.isRunning {
//            audioEngine.stop()
//            audioEngine.inputNode.removeTap(onBus: 0)
//        }
//
//        // Don't deactivate the session — let AVCaptureSession keep it
//        // try? AVAudioSession.sharedInstance().setActive(false) ← removed intentionally
//
//        hasTriggered = false
//        commandBuffer = ""
//        state = .idle
//    }
//
//    /// Pause speech engine before camera snapshot (releases mic tap briefly)
//    func pauseAudio() {
//        silenceTimer?.invalidate()
//        silenceTimer = nil
//
//        recognitionTask?.cancel()
//        recognitionTask = nil
//
//        recognitionRequest?.endAudio()
//        recognitionRequest = nil
//
//        if audioEngine.isRunning {
//            audioEngine.stop()
//            audioEngine.inputNode.removeTap(onBus: 0)
//        }
//        // Don't touch AVAudioSession — let camera keep it
//    }
//
//    /// Resume after camera snapshot — resets for next command
//    func resumeAfterCapture() {
//        hasTriggered = false
//        commandBuffer = ""
//        state = .idle
//        do {
//            try start()
//        } catch {
//            state = .error(error.localizedDescription)
//        }
//    }
//
//    // MARK: - Transcript
//
//    private func processTranscript(_ text: String, isFinal: Bool) {
//        // Continuous guided mode: bypass wake word
//        if continuousMode {
//            if isFinal {
//                let cmd = text.trimmingCharacters(in: .whitespacesAndNewlines)
//                if !cmd.isEmpty {
//                    state = .finalCommand(cmd)
//                }
//            }
//            return
//        }
//
//        if !hasTriggered {
//            if text.contains("hey cat") {
//                hasTriggered = true
//                commandBuffer = ""
//                lastUpdateTime = Date()
//                state = .triggered
//            }
//            return
//        }
//
//        if let range = text.range(of: "hey cat", options: .backwards) {
//            let after = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
//            if !after.isEmpty {
//                commandBuffer = after
//                lastUpdateTime = Date()
//            }
//        }
//
//        if isFinal { emitCommand() }
//    }
//
//    private func emitCommand() {
//        let cmd = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard !cmd.isEmpty else {
//            hasTriggered = false
//            commandBuffer = ""
//            state = .idle
//            return
//        }
//        state = .finalCommand(cmd)
//        hasTriggered = false
//        commandBuffer = ""
//    }
//
//    private func startSilenceTimer() {
//        silenceTimer?.invalidate()
//        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
//            guard let self else { return }
//            Task { @MainActor in self.checkSilence() }
//        }
//    }
//
//    private func checkSilence() {
//        guard hasTriggered, !commandBuffer.isEmpty else { return }
//        if Date().timeIntervalSince(lastUpdateTime) > 1.8 { emitCommand() }
//    }
//}

import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - HotwordManager
//
// Design principles:
//
//  1. Recognition session lifecycle is INTERNAL. The published `state` never
//     flickers to `.idle` just because the recognizer restarted — it only
//     changes when the assistant conversation state actually changes.
//
//  2. Two operating modes:
//     • Normal      – waits for "hey cat", then collects the trailing command.
//     • Continuous  – every finalized utterance is immediately a command.
//                     Set `continuousMode = true` to activate.
//
//  3. Restart is silent. Apple's recognizer times out after ~60 s; we restart
//     transparently, preserving `hasTriggered` and `commandBuffer` so an
//     in-progress wake-word session is not lost.
//
//  4. `pauseAudio()` / `resumeAfterCapture()` are the only entry points the
//     camera layer should use. They do NOT reset conversation state.

@MainActor
final class HotwordManager: ObservableObject {

    // ── Published state ──────────────────────────────────────────────────────

    enum ListenState: Equatable {
        /// Mic is running, waiting for wake word (or any utterance in continuous mode).
        case idle
        /// Wake word detected; now collecting the command utterance.
        case triggered
        /// A complete command has been recognized — ready to act on.
        case finalCommand(String)
        /// A hard error that requires user action (permissions denied, etc.).
        case error(String)
    }

    static let shared = HotwordManager()

    @Published private(set) var state: ListenState = .idle

    // ── Configuration ────────────────────────────────────────────────────────

    /// When `true`, every finalized utterance becomes a `.finalCommand` without
    /// requiring the "hey cat" wake phrase first.
    var continuousMode: Bool = false

    // ── Private audio / recognition plumbing ────────────────────────────────

    private let audioEngine         = AVAudioEngine()
    private var recognitionRequest : SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask    : SFSpeechRecognitionTask?
    private let recognizer          = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // ── Conversation state (preserved across recognizer restarts) ────────────

    private var hasTriggered    = false
    private var commandBuffer   = ""
    private var lastUpdateTime  = Date()

    // ── Silence-based finalization ───────────────────────────────────────────

    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.8   // seconds without new text

    // ── Internal flags ───────────────────────────────────────────────────────

    /// `true` while the audio engine has been deliberately paused for camera capture.
    private var isPaused = false
    /// `true` while a recognition session restart is in progress (suppresses
    /// publishing `.idle` during the gap between old session ending / new starting).
    private var isRestarting = false

    private init() {}

    // ── MARK: Permissions ────────────────────────────────────────────────────

    func requestPermissions() async throws {
        // Microphone
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        }
        guard micGranted else {
            throw PermissionError.microphoneDenied
        }

        // Speech recognition
        let speechStatus = await withCheckedContinuation {
            (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            throw PermissionError.speechDenied
        }
    }

    enum PermissionError: LocalizedError {
        case microphoneDenied, speechDenied
        var errorDescription: String? {
            switch self {
            case .microphoneDenied: return "Microphone permission denied."
            case .speechDenied:     return "Speech recognition permission denied."
            }
        }
    }

    // ── MARK: Start / Stop (public) ──────────────────────────────────────────

    /// Starts the hotword manager from scratch, resetting all conversation state.
    func start() throws {
        isPaused     = false
        isRestarting = false

        // Reset conversation
        hasTriggered   = false
        commandBuffer  = ""

        // Tear down any existing session before building a new one
        tearDownRecognition()

        try configureAudioSession()
        try startRecognitionSession()

        // Only publish `.idle` when starting fresh (not during a silent restart)
        state = .idle
    }

    /// Tears everything down. Resets conversation state and publishes `.idle`.
    func stop() {
        isPaused     = false
        isRestarting = false

        tearDownRecognition()

        hasTriggered  = false
        commandBuffer = ""
        state         = .idle
    }

    // ── MARK: Camera integration ─────────────────────────────────────────────

    /// Pause the speech engine before a camera capture.
    /// Does NOT reset conversation state or change the published `state`.
    func pauseAudio() {
        guard !isPaused else { return }
        isPaused = true

        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask  = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        // Leave AVAudioSession active — camera owns it while paused.
    }

    /// Resume listening after a camera capture. Resets for the *next* command
    /// but does NOT change the displayed overlay state (caller manages that).
    func resumeAfterCapture() {
        isPaused      = false
        hasTriggered  = false
        commandBuffer = ""

        // Don't touch `state` — the UI layer owns what's displayed.
        silentRestart()
    }

    // ── MARK: Private – Audio session ────────────────────────────────────────

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // ── MARK: Private – Recognition session ─────────────────────────────────

    private func startRecognitionSession() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device recognition avoids network latency and reduces the frequency
        // of Apple's server-side session timeouts.
        if recognizer?.supportsOnDeviceRecognition == true {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in self.handleRecognitionError(error) }
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString.lowercased()
            Task { @MainActor in self.processTranscript(text, isFinal: result.isFinal) }
        }

        startSilenceTimer()
    }

    private func tearDownRecognition() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionTask?.cancel()
        recognitionTask  = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    // ── MARK: Private – Silent restart ──────────────────────────────────────
    //
    // Used when the recognizer times out or after camera capture.
    // Key behaviour: does NOT touch `state`, `hasTriggered`, or `commandBuffer`
    // so the UI sees no interruption.

    private func silentRestart() {
        guard !isPaused else { return }

        isRestarting = true
        tearDownRecognition()

        do {
            // Audio session should still be active; no need to reconfigure.
            try startRecognitionSession()
        } catch {
            isRestarting = false
            state = .error(error.localizedDescription)
            return
        }

        isRestarting = false
    }

    // ── MARK: Private – Error handling ──────────────────────────────────────

    private func handleRecognitionError(_ error: Error) {
        guard !isPaused else { return }   // Camera has the mic — expected.

        let nsErr = error as NSError
        // Code 301 = "Recognition request was canceled" — our own teardown; ignore.
        // Code 1110 = "No speech detected" — benign timeout; restart.
        // Code 209  = "Recording stopped" — AVAudioSession interrupted; restart.
        let benignCodes: Set<Int> = [209, 301, 1110]

        if nsErr.domain == "kAFAssistantErrorDomain" && benignCodes.contains(nsErr.code) {
            silentRestart()
            return
        }

        // Some other recognizer error. Attempt a restart but cap retries to
        // avoid a tight loop on a persistent failure.
        print("[HotwordManager] Recognition error \(nsErr.domain)/\(nsErr.code): \(error.localizedDescription)")
        silentRestart()
    }

    // ── MARK: Private – Transcript processing ───────────────────────────────

    private func processTranscript(_ text: String, isFinal: Bool) {
        // ── Continuous mode: every final utterance is a command ──────────────
        if continuousMode {
            if isFinal {
                let cmd = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cmd.isEmpty {
                    state = .finalCommand(cmd)
                }
            }
            return
        }

        // ── Normal mode: wait for "hey cat" ─────────────────────────────────
        if !hasTriggered {
            if text.contains("hey cat") {
                hasTriggered   = true
                commandBuffer  = ""
                lastUpdateTime = Date()
                state          = .triggered
            }
            return
        }

        // We are triggered. Extract everything after the last "hey cat"
        if let range = text.range(of: "hey cat", options: .backwards) {
            let after = String(text[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                commandBuffer  = after
                lastUpdateTime = Date()
            }
        }

        if isFinal { emitCommand() }
    }

    private func emitCommand() {
        let cmd = commandBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if cmd.isEmpty {
            // Nothing captured after the wake word; go back to listening.
            hasTriggered  = false
            commandBuffer = ""
            // Only return to `.idle` if we were in triggered state
            if state == .triggered { state = .idle }
            return
        }
        state         = .finalCommand(cmd)
        hasTriggered  = false
        commandBuffer = ""
    }

    // ── MARK: Private – Silence timer ───────────────────────────────────────

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.checkSilence() }
        }
    }

    private func checkSilence() {
        guard hasTriggered, !commandBuffer.isEmpty else { return }
        if Date().timeIntervalSince(lastUpdateTime) > silenceThreshold {
            emitCommand()
        }
    }
}
