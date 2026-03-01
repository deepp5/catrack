//import SwiftUI
//import AVFoundation
//
//struct AssistCaptureView: View {
//    let machine: Machine
//
//    @Environment(\.dismiss) private var dismiss
//    @EnvironmentObject var sheetVM: InspectionSheetViewModel
//    @EnvironmentObject var chatVM: ChatViewModel
//
//    @StateObject private var camera = CameraController()
//    @StateObject private var hotword = HotwordManager.shared
//
//    @State private var showOverlay = false
//    @State private var overlayPhase: GlassHotwordOverlay.Phase = .listening
//    @State private var overlayTranscript = ""
//    @State private var overlayResult = ""
//    @State private var isWorking = false
//
//    enum AssistState {
//        case free
//        case guided(step: Int)
//    }
//
//    @State private var assistState: AssistState = .free
//
//    var body: some View {
//        ZStack {
//            CameraPreview(session: camera.session)
//                .ignoresSafeArea()
//
//            // Overlay — centered at top, only visible after wake word
//            VStack {
//                if showOverlay {
//                    GlassHotwordOverlay(
//                        phase: overlayPhase,
//                        transcript: overlayTranscript,
//                        result: overlayResult
//                    )
//                    .padding(.horizontal, 16)
//                    .padding(.top, 12)
//                }
//                Spacer()
//            }
//
//            VStack {
//                Spacer()
//                bottomBar
//            }
//        }
//        .onAppear {
//            camera.setSessionAudioEnabled(false)
//            camera.start()
//
//            Task {
//                await waitForSessionReady()
//                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s settle
//                do {
//                    try await hotword.requestPermissions()
//                    try hotword.start()
//                } catch {
//                    showOverlay = true
//                    overlayPhase = .error
//                    overlayResult = error.localizedDescription
//                }
//            }
//        }
//        .onDisappear {
//            hotword.stop()
//            camera.setSessionAudioEnabled(true)
//            camera.stop()
//        }
//        .onChange(of: hotword.state) { _, newState in
//            handleHotwordState(newState)
//        }
//    }
//
//    // MARK: - Hotword State Handler
//
//    private func handleHotwordState(_ newState: HotwordManager.ListenState) {
//        switch newState {
//        case .idle:
//            // Only clear overlay when we're truly idle in free mode.
//            // (During wake-word transitions the recognizer may briefly go idle.)
//            guard !isWorking else { return }
//            guard case .free = assistState else { return }
//
//            showOverlay = false
//            overlayTranscript = ""
//            overlayResult = ""
//        case .triggered:
//            showOverlay = true
//            overlayPhase = .listening
//            overlayTranscript = ""
//            overlayResult = ""
//        case .finalCommand(let cmd):
//            print("🔥 FINAL COMMAND RECEIVED:", cmd)
//
//            // Lock UI immediately so an `.idle` transition can't clear the overlay
//            showOverlay = true
//            overlayPhase = .heard
//            overlayTranscript = cmd
//            overlayResult = ""
//            isWorking = true
//
//            Task { await runCommand(cmd) }
//        case .error(let msg):
//            showOverlay = true
//            overlayPhase = .error
//            overlayResult = msg
//        }
//    }
//
//    // MARK: - Run Command
//
//    private func runCommand(_ cmd: String) async {
//        // `isWorking` is set immediately when we receive `.finalCommand` to prevent
//        // an `.idle` transition from hiding the overlay.
//
//        // Normalize command
//        let lower = cmd.lowercased()
//
//        // Resume guided mode from free state
//        if case .free = assistState,
//           lower.contains("continue") ||
//           lower.contains("resume") ||
//           lower.contains("ok") ||
//           lower.contains("sure") {
//
//            let items = orderedChecklistItems()
//            if !items.isEmpty {
//                assistState = .guided(step: 0)
//                overlayPhase = .done
//                overlayResult = """
//                GUIDED MODE RESUMED
//
//                Step 1 / \(items.count)
//                Inspect: \(items[0])
//
//                Say "check" when ready.
//                """
//            }
//
//            isWorking = false
//            hotword.resumeAfterCapture()
//            return
//        }
//
//        // Detect start of guided inspection
//        if lower.contains("start") && lower.contains("inspection") {
//
//            let allItems = orderedChecklistItems()
//
//            if !allItems.isEmpty {
//
//                assistState = .guided(step: 0)
//                hotword.continuousMode = true
//
//                showOverlay = true
//                overlayPhase = .done
//                overlayTranscript = ""
//
//                overlayResult = """
//                GUIDED MODE STARTED
//
//                Step 1 / \(allItems.count)
//                Inspect: \(allItems[0])
//
//                Say "check" when ready.
//                """
//            } else {
//                overlayPhase = .error
//                overlayResult = "No checklist items found."
//            }
//
//            isWorking = false
//            hotword.resumeAfterCapture()
//            return
//        }
//
//        // If in guided mode, handle control flow before capturing
//        if case .guided(let step) = assistState {
//            let items = orderedChecklistItems()
//
//            let isCheckCommand =
//                lower.contains("check") ||
//                lower.contains("inspect") ||
//                lower.contains("evaluate") ||
//                lower.contains("ready")
//
//            // If NOT a check command, treat as interrupt question (no capture)
//            if !isCheckCommand {
//                overlayPhase = .done
//                overlayResult = """
//                GUIDED MODE
//
//                Step \(step + 1) / \(items.count)
//                Inspect: \(items[step])
//
//                Want to continue inspection?
//                """
//
//                isWorking = false
//                hotword.resumeAfterCapture()
//                return
//            }
//        }
//
//        overlayPhase = .heard
//        overlayTranscript = cmd
//        overlayResult = ""
//
//        // Pause hotword mic before capture so audio hardware is free
//        hotword.pauseAudio()
//        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
//
//        overlayPhase = .analyzing
//        overlayResult = "Capturing frame…"
//
//        guard let jpeg = await camera.captureJPEG() else {
//            overlayPhase = .error
//            overlayResult = "Couldn't capture frame."
//            isWorking = false
//            hotword.resumeAfterCapture()
//            return
//        }
//
//        overlayResult = "Sending to CAT AI…"
//
//        // Build current checklist state from sheet
//        let sections = sheetVM.sectionsFor(machine.id)
//        var checklistState: [String: String] = [:]
//        for s in sections {
//            for f in s.fields {
//
//                let backendValue: String
//
//                switch f.status {
//                case .pass:
//                    backendValue = "PASS"
//                case .monitor:
//                    backendValue = "MONITOR"
//                case .fail:
//                    backendValue = "FAIL"
//                case .pending:
//                    backendValue = "none"
//                }
//
//                checklistState[f.label] = backendValue
//            }
//        }
//
//        do {
//            // Use analyzeVideoCommand → hits /analyze-video-command
//            // This endpoint takes checklist state directly (no DB inspection_id needed)
//            let promptText: String
//
//            switch assistState {
//            case .free:
//                promptText = cmd
//            case .guided(let step):
//                let items = orderedChecklistItems()
//                if step < items.count {
//                    let component = items[step]
//                    promptText = """
//                    Inspect this component only: \(component).
//                    Determine PASS, MONITOR, or FAIL.
//                    Only evaluate this component.
//                    """
//                } else {
//                    promptText = cmd
//                }
//            }
//
//            let resp = try await APIService.shared.analyzeVideoCommand(
//                userText: promptText,
//                currentChecklistState: checklistState,
//                framesBase64: [jpeg.base64EncodedString()]
//            )
//
//            // Apply checklist updates back to the sheet
//            var updates: [SheetUpdate] = []
//            for (backendKey, upd) in resp.checklistUpdates {
//                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
//                guard let hit = findField(backendKey, in: sections) else { continue }
//                updates.append(SheetUpdate(
//                    sheetSection: hit.sectionId,
//                    fieldId: hit.fieldId,
//                    value: sev,
//                    evidenceMediaId: nil
//                ))
//            }
//            if !updates.isEmpty {
//                sheetVM.applyUpdates(updates, for: machine.id)
//            }
//
//            // Build result summary for overlay
//            let summary: String
//            if !updates.isEmpty {
//                let risk = resp.riskScore ?? "n/a"
//                summary = "Updated \(updates.count) item\(updates.count == 1 ? "" : "s") · Risk: \(risk)"
//            } else if let answer = resp.answer, !answer.isEmpty {
//                summary = compact(answer)
//            } else {
//                summary = "No updates found."
//            }
//
//            if case .guided(let step) = assistState {
//
//                let items = orderedChecklistItems()
//
//                if !updates.isEmpty {
//                    // Successful evaluation → auto advance
//                    let nextStep = step + 1
//
//                    if nextStep < items.count {
//                        assistState = .guided(step: nextStep)
//                        overlayResult = """
//                        GUIDED MODE
//
//                        Updated \(updates.count) item\(updates.count == 1 ? "" : "s")
//
//                        Step \(nextStep + 1) / \(items.count)
//                        Inspect: \(items[nextStep])
//
//                        Say "check" when ready.
//                        """
//                    } else {
//                        assistState = .free
//                        hotword.continuousMode = false
//                        overlayResult = "Guided inspection complete."
//                    }
//                } else {
//                    // No updates detected → tell user to adjust
//                    overlayResult = """
//                    GUIDED MODE
//
//                    No issues detected.
//                    Move closer if needed.
//
//                    Say "check" when ready.
//                    """
//                }
//
//                overlayPhase = .done
//
//            } else {
//                overlayPhase = .done
//                overlayResult = summary
//            }
//
//        } catch {
//            overlayPhase = .error
//            overlayResult = compact(error.localizedDescription)
//        }
//    
//        isWorking = false
//
//        // Resume listening but DO NOT override overlay state in guided mode
//        hotword.resumeAfterCapture()
//
//        // Only reset to listening phase if we are in free mode
//        if case .free = assistState {
//            overlayPhase = .listening
//            overlayTranscript = ""
//        }
//        // In guided mode we keep overlayPhase and overlayResult as-is
//    }
//
//    // MARK: - Bottom Bar
//
//    private var bottomBar: some View {
//        VStack(spacing: 0) {
//            Rectangle().fill(Color.appBorder).frame(height: 0.5)
//            HStack {
//                Button("Close") { dismiss() }
//                    .foregroundStyle(.white.opacity(0.85))
//                    .padding(.horizontal, 14)
//                    .padding(.vertical, 10)
//                    .background(.ultraThinMaterial)
//                    .clipShape(RoundedRectangle(cornerRadius: 14))
//
//                Spacer()
//
//                VStack(spacing: 6) {
//                    Image(systemName: "waveform.circle.fill")
//                        .font(.system(size: 28, weight: .semibold))
//                        .foregroundStyle(Color.catYellow)
//                        .symbolEffect(.pulse)
//
//                    Text("Say: Hey Cat…")
//                        .font(.dmMono(10))
//                        .foregroundStyle(Color.white.opacity(0.6))
//                }
//
//                Spacer()
//
//                Button { camera.flip() } label: {
//                    Image(systemName: "arrow.triangle.2.circlepath.camera")
//                        .font(.system(size: 18, weight: .semibold))
//                        .foregroundStyle(.white)
//                        .padding(12)
//                        .background(.ultraThinMaterial)
//                        .clipShape(Circle())
//                }
//            }
//            .padding(.horizontal, 18)
//            .padding(.vertical, 14)
//            .background(Color.black.opacity(0.3).ignoresSafeArea(edges: .bottom))
//        }
//    }
//
//    // MARK: - Helpers
//
//    private func waitForSessionReady() async {
//        let deadline = Date().addingTimeInterval(4.0)
//        while !camera.isSessionReady && Date() < deadline {
//            try? await Task.sleep(nanoseconds: 100_000_000)
//        }
//    }
//
//    private func orderedChecklistItems() -> [String] {
//        let sections = sheetVM.sectionsFor(machine.id)
//        return sections.flatMap { section in
//            section.fields.map { $0.label }
//        }
//    }
//
//    /// Match backend key (item label) to the field in the sheet sections
//    private func findField(_ backendKey: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
//        for sec in sections {
//            if let f = sec.fields.first(where: { $0.label == backendKey || $0.id == backendKey }) {
//                return (sec.id, f.id)
//            }
//        }
//        return nil
//    }
//
//    private func compact(_ s: String, max: Int = 140) -> String {
//        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
//        guard t.count > max else { return t }
//        return String(t[t.startIndex..<t.index(t.startIndex, offsetBy: max)]) + "…"
//    }
//}

import SwiftUI
import AVFoundation

// MARK: - AssistCaptureView
//
// State machine contract:
//
//  assistState  │  hotword.continuousMode  │  Expected behaviour
//  ─────────────┼──────────────────────────┼───────────────────────────────────
//  .free        │  false                   │  Normal "Hey Cat" wake-word mode.
//  .guided(n)   │  true                    │  Every utterance is a command.
//                                            No wake word needed.
//
// Overlay visibility rule:
//   `showOverlay` is ONLY set to `false` when:
//   • We receive `.idle` AND assistState is `.free` AND isProcessing is false.
//   Guided mode NEVER clears the overlay automatically.

struct AssistCaptureView: View {

    let machine: Machine

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM:  ChatViewModel

    @StateObject private var camera  = CameraController()
    @ObservedObject private var hotword = HotwordManager.shared

    // ── Overlay ──────────────────────────────────────────────────────────────
    @State private var showOverlay    = false
    @State private var overlayPhase: GlassHotwordOverlay.Phase = .listening
    @State private var overlayTranscript = ""
    @State private var overlayResult     = ""

    // ── Guided mode ──────────────────────────────────────────────────────────
    enum AssistState: Equatable {
        case free
        case guided(step: Int)
    }
    @State private var assistState: AssistState = .free

    // ── Processing lock ──────────────────────────────────────────────────────
    // Prevents `.idle` from clearing the overlay while a command is running.
    @State private var isProcessing = false

    // ── MARK: Body ───────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                if showOverlay {
                    GlassHotwordOverlay(
                        phase:      overlayPhase,
                        transcript: overlayTranscript,
                        result:     overlayResult
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                Spacer()
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
        .onAppear  { setup()   }
        .onDisappear { teardown() }
        .onChange(of: hotword.state) { _, newState in
            handleHotwordState(newState)
        }
    }

    // ── MARK: Setup / Teardown ───────────────────────────────────────────────

    private func setup() {
        camera.setSessionAudioEnabled(false)
        camera.start()

        Task {
            await waitForSessionReady()
            // Small settle window for AVCaptureSession to stabilize audio hw.
            try? await Task.sleep(nanoseconds: 500_000_000)

            do {
                try await hotword.requestPermissions()
                try hotword.start()
            } catch {
                presentError(error.localizedDescription)
            }
        }
    }

    private func teardown() {
        hotword.stop()
        hotword.continuousMode = false
        camera.setSessionAudioEnabled(true)
        camera.stop()
    }

    // ── MARK: Hotword state handler ──────────────────────────────────────────

    private func handleHotwordState(_ newState: HotwordManager.ListenState) {
        switch newState {

        case .idle:
            // Only hide the overlay if:
            //   • we are in free mode (guided mode keeps overlay visible)
            //   • nothing is currently being processed
            guard case .free = assistState, !isProcessing else { return }
            hideOverlay()

        case .triggered:
            // Wake word heard — show the overlay in listening state.
            showOverlay(phase: .listening, transcript: "", result: "")

        case .finalCommand(let cmd):
            // Lock immediately so any subsequent `.idle` (from recognizer restart)
            // cannot clear the overlay before we finish processing.
            isProcessing = true
            showOverlay(phase: .heard, transcript: cmd, result: "")
            Task { await runCommand(cmd) }

        case .error(let msg):
            presentError(msg)
        }
    }

    // ── MARK: Run command ────────────────────────────────────────────────────

    private func runCommand(_ cmd: String) async {
        defer {
            isProcessing = false
            // Restart listening. Does not change `state` or overlay.
            hotword.resumeAfterCapture()

            // In guided mode, keep the overlay visible with whatever result
            // we last wrote. In free mode, return to the listening indicator.
            if case .free = assistState {
                // Brief pause so the user can read the result before it clears.
                // Comment this out if you want instant clear.
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard case .free = assistState, !isProcessing else { return }
                    hideOverlay()
                }
            }
        }

        let lower = cmd.lowercased()

        // ── Handle "start inspection" ────────────────────────────────────────
        if lower.contains("start") && lower.contains("inspection") {
            let items = orderedChecklistItems()

            guard !items.isEmpty else {
                updateOverlay(phase: .error, result: "No checklist items found.")
                return
            }

            enterGuidedMode(step: 0, totalItems: items.count, firstItem: items[0])
            return
        }

        // ── Handle resume commands in free mode ──────────────────────────────
        if case .free = assistState {
            let resumeWords = ["continue", "resume", "ok", "sure"]
            if resumeWords.contains(where: { lower.contains($0) }) {
                let items = orderedChecklistItems()
                if !items.isEmpty {
                    enterGuidedMode(step: 0, totalItems: items.count, firstItem: items[0])
                }
                return
            }
        }

        // ── Guided mode: non-check interrupt ────────────────────────────────
        if case .guided(let step) = assistState {
            let items = orderedChecklistItems()
            let isCheckCommand = lower.contains("check")
                              || lower.contains("inspect")
                              || lower.contains("evaluate")
                              || lower.contains("ready")

            if !isCheckCommand {
                // Treat as a question; re-display current step prompt.
                updateOverlay(
                    phase:  .done,
                    result: guidedPrompt(step: step, total: items.count, item: items[step])
                )
                return
            }
        }

        // ── Capture + analyze ────────────────────────────────────────────────
        updateOverlay(phase: .analyzing, result: "Capturing frame…")

        // Pause mic before capture
        hotword.pauseAudio()
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard let jpeg = await camera.captureJPEG() else {
            updateOverlay(phase: .error, result: "Couldn't capture frame.")
            return
        }

        updateOverlay(phase: .analyzing, result: "Sending to CAT AI…")

        let sections       = sheetVM.sectionsFor(machine.id)
        let checklistState = buildChecklistState(from: sections)

        let promptText: String
        if case .guided(let step) = assistState {
            let items = orderedChecklistItems()
            if step < items.count {
                promptText = "Inspect this component only: \(items[step]). Determine PASS, MONITOR, or FAIL."
            } else {
                promptText = cmd
            }
        } else {
            promptText = cmd
        }

        do {
            let resp = try await APIService.shared.analyzeVideoCommand(
                userText:             promptText,
                currentChecklistState: checklistState,
                framesBase64:         [jpeg.base64EncodedString()]
            )

            let updates = applyChecklistUpdates(resp.checklistUpdates, sections: sections)

            // ── Update guided mode state ─────────────────────────────────────
            if case .guided(let step) = assistState {
                let items = orderedChecklistItems()

                if !updates.isEmpty {
                    let nextStep = step + 1
                    if nextStep < items.count {
                        assistState = .guided(step: nextStep)
                        updateOverlay(
                            phase:  .done,
                            result: guidedStepResult(
                                updatedCount: updates.count,
                                nextStep:     nextStep,
                                total:        items.count,
                                nextItem:     items[nextStep]
                            )
                        )
                    } else {
                        exitGuidedMode(message: "Guided inspection complete! All steps done.")
                    }
                } else {
                    // Nothing detected — stay on same step
                    updateOverlay(
                        phase:  .done,
                        result: "No issues detected — move closer if needed.\n\n"
                               + guidedPrompt(step: step, total: items.count, item: items[step])
                    )
                }

            } else {
                // Free mode result
                let summary: String
                if !updates.isEmpty {
                    let risk = resp.riskScore ?? "n/a"
                    summary = "Updated \(updates.count) item\(updates.count == 1 ? "" : "s") · Risk: \(risk)"
                } else if let answer = resp.answer, !answer.isEmpty {
                    summary = compact(answer)
                } else {
                    summary = "No updates found."
                }
                updateOverlay(phase: .done, result: summary)
            }

        } catch {
            updateOverlay(phase: .error, result: compact(error.localizedDescription))
        }
    }

    // ── MARK: Guided mode helpers ────────────────────────────────────────────

    private func enterGuidedMode(step: Int, totalItems: Int, firstItem: String) {
        assistState             = .guided(step: step)
        hotword.continuousMode  = true
        updateOverlay(
            phase:  .done,
            result: guidedStepStart(step: step, total: totalItems, item: firstItem)
        )
    }

    private func exitGuidedMode(message: String) {
        assistState             = .free
        hotword.continuousMode  = false
        updateOverlay(phase: .done, result: message)
    }

    private func guidedPrompt(step: Int, total: Int, item: String) -> String {
        "GUIDED MODE\n\nStep \(step + 1) / \(total)\nInspect: \(item)\n\nSay \"check\" when ready."
    }

    private func guidedStepStart(step: Int, total: Int, item: String) -> String {
        "GUIDED MODE STARTED\n\nStep \(step + 1) / \(total)\nInspect: \(item)\n\nSay \"check\" when ready."
    }

    private func guidedStepResult(updatedCount: Int, nextStep: Int, total: Int, nextItem: String) -> String {
        "Updated \(updatedCount) item\(updatedCount == 1 ? "" : "s")\n\n"
        + guidedPrompt(step: nextStep, total: total, item: nextItem)
    }

    // ── MARK: Overlay helpers ────────────────────────────────────────────────

    private func showOverlay(phase: GlassHotwordOverlay.Phase, transcript: String, result: String) {
        showOverlay       = true
        overlayPhase      = phase
        overlayTranscript = transcript
        overlayResult     = result
    }

    private func updateOverlay(phase: GlassHotwordOverlay.Phase, result: String) {
        overlayPhase  = phase
        overlayResult = result
    }

    private func hideOverlay() {
        showOverlay       = false
        overlayPhase      = .listening
        overlayTranscript = ""
        overlayResult     = ""
    }

    private func presentError(_ msg: String) {
        showOverlay   = true
        overlayPhase  = .error
        overlayResult = msg
    }

    // ── MARK: Checklist helpers ──────────────────────────────────────────────

    private func orderedChecklistItems() -> [String] {
        sheetVM.sectionsFor(machine.id).flatMap { $0.fields.map(\.label) }
    }

    private func buildChecklistState(from sections: [SheetSection]) -> [String: String] {
        var result: [String: String] = [:]
        for s in sections {
            for f in s.fields {
                let val: String
                switch f.status {
                case .pass:    val = "PASS"
                case .monitor: val = "MONITOR"
                case .fail:    val = "FAIL"
                case .pending: val = "none"
                }
                result[f.label] = val
            }
        }
        return result
    }

    @discardableResult
    private func applyChecklistUpdates(
        _ raw: [String: FastChecklistUpdate],
        sections: [SheetSection]
    ) -> [SheetUpdate] {
        var updates: [SheetUpdate] = []
        for (key, upd) in raw {
            guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
            guard let hit = findField(key, in: sections)          else { continue }
            updates.append(SheetUpdate(
                sheetSection:    hit.sectionId,
                fieldId:         hit.fieldId,
                value:           sev,
                evidenceMediaId: nil
            ))
        }
        if !updates.isEmpty {
            sheetVM.applyUpdates(updates, for: machine.id)
        }
        return updates
    }

    private func findField(_ key: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
        for sec in sections {
            if let f = sec.fields.first(where: { $0.label == key || $0.id == key }) {
                return (sec.id, f.id)
            }
        }
        return nil
    }

    // ── MARK: Bottom bar ─────────────────────────────────────────────────────

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.appBorder).frame(height: 0.5)
            HStack {
                Button("Close") { dismiss() }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                VStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.catYellow)
                        .symbolEffect(.pulse)

                    Text(
                        {
                            if case .guided = assistState { return "Say: \"check\"…" }
                            return "Say: \"Hey Cat\"…"
                        }()
                    )
                    .font(.dmMono(10))
                    .foregroundStyle(Color.white.opacity(0.6))
                }

                Spacer()

                Button { camera.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.3).ignoresSafeArea(edges: .bottom))
        }
    }

    // ── MARK: Misc helpers ───────────────────────────────────────────────────

    private func waitForSessionReady() async {
        let deadline = Date().addingTimeInterval(4.0)
        while !camera.isSessionReady && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func compact(_ s: String, maxLength: Int = 140) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxLength else { return t }
        return String(t.prefix(maxLength)) + "…"
    }
}
