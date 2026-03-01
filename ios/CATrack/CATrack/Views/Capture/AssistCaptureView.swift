import SwiftUI
import AVFoundation

struct AssistCaptureView: View {
    let machine: Machine

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    @StateObject private var camera  = CameraController()
    @StateObject private var hotword = HotwordManager.shared

    @State private var showOverlay       = false
    @State private var overlayPhase: GlassHotwordOverlay.Phase = .listening
    @State private var overlayTranscript = ""
    @State private var overlayResult     = ""
    @State private var isWorking         = false
    @State private var permissionError: String? = nil

    enum AssistState { case free; case guided(step: Int) }
    @State private var assistState: AssistState = .free

    var body: some View {
        ZStack {
            // Camera feed
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            // Top + bottom gradient scrims for legibility
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 160)
                .ignoresSafeArea(edges: .top)

                Spacer()

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .bottom)
            }

            // Overlay card + permission error
            VStack(spacing: 8) {
                if showOverlay {
                    GlassHotwordOverlay(
                        phase: overlayPhase,
                        transcript: overlayTranscript,
                        result: overlayResult
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 54)
                }

                if let err = permissionError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.barlow(12))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, showOverlay ? 0 : 54)
                }

                Spacer()
                bottomBar
            }
        }
        .onAppear {
            // Start camera video-only (no audio input) so preview is visible.
            camera.setSessionAudioEnabled(false)
            camera.start()

            Task {
                // Wait for camera session to be running and fully settled.
                await waitForSessionReady()
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 s — let capture session fully claim its resources

                do {
                    try await hotword.requestPermissions()
                    try hotword.start()
                } catch {
                    permissionError = error.localizedDescription
                }
            }
        }
        .onDisappear {
            hotword.stop()
            camera.stop()
        }
        .onChange(of: hotword.state) { _, newState in
            handleHotwordState(newState)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showOverlay)
    }

    // MARK: - Hotword State

    private func handleHotwordState(_ newState: HotwordManager.ListenState) {
        switch newState {
        case .idle:
            if !isWorking {
                withAnimation { showOverlay = false }
                overlayTranscript = ""
                overlayResult     = ""
            }

        case .triggered:
            withAnimation { showOverlay = true }
            overlayPhase      = .listening
            overlayTranscript = ""
            overlayResult     = ""

        case .finalCommand(let cmd):
            Task { await runCommand(cmd) }

        case .error(let msg):
            withAnimation { showOverlay = true }
            overlayPhase  = .error
            overlayResult = msg
        }
    }

    // MARK: - Run Command

    private func runCommand(_ cmd: String) async {
        guard !isWorking else { return }
        isWorking = true
        let lower = cmd.lowercased()

        // Guided mode resume
        if case .free = assistState,
           lower.contains("continue") || lower.contains("resume") ||
           lower.contains("ok") || lower.contains("sure") {
            let items = orderedChecklistItems()
            if !items.isEmpty {
                assistState   = .guided(step: 0)
                overlayPhase  = .done
                overlayResult = "Guided mode — Step 1/\(items.count): \(items[0])"
            }
            isWorking = false
            hotword.resumeAfterCapture()
            return
        }

        // Start guided inspection
        if lower.contains("start inspection") {
            let allItems = orderedChecklistItems()
            if !allItems.isEmpty {
                assistState   = .guided(step: 0)
                overlayPhase  = .done
                overlayResult = "Step 1/\(allItems.count): \(allItems[0])"
            }
            isWorking = false
            hotword.resumeAfterCapture()
            return
        }

        // Guided: non-check command
        if case .guided(let step) = assistState {
            let items = orderedChecklistItems()
            let isCheck = lower.contains("check") || lower.contains("inspect") ||
                          lower.contains("evaluate") || lower.contains("ready")
            if !isCheck {
                overlayPhase  = .done
                overlayResult = "Step \(step + 1)/\(items.count): \(items[step]) — say \"check\" when ready"
                isWorking = false
                hotword.resumeAfterCapture()
                return
            }
        }

        // --- Capture + AI ---
        overlayPhase      = .heard
        overlayTranscript = cmd
        overlayResult     = ""

        // Pause hotword mic tap (releases AVAudioEngine input node)
        hotword.pauseAudio()
        // Small gap so the audio engine fully teardown before capture
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 s

        overlayPhase  = .analyzing
        overlayResult = "Capturing frame…"

        // Camera is already running (video-only) — just capture
        guard let jpeg = await camera.captureJPEG() else {
            overlayPhase  = .error
            overlayResult = "Couldn't capture frame. Try again."
            isWorking = false
            hotword.resumeAfterCapture()
            return
        }

        overlayResult = "Sending to CAT AI…"

        let sections = sheetVM.sectionsFor(machine.id)
        var checklistState: [String: String] = [:]
        for s in sections {
            for f in s.fields {
                let val: String
                switch f.status {
                case .pass:    val = "PASS"
                case .monitor: val = "MONITOR"
                case .fail:    val = "FAIL"
                case .pending: val = "none"
                }
                checklistState[f.label] = val
            }
        }

        do {
            let promptText: String
            if case .guided(let step) = assistState {
                let items = orderedChecklistItems()
                promptText = step < items.count
                    ? "Inspect this component only: \(items[step]). Determine PASS, MONITOR, or FAIL. Only evaluate this component."
                    : cmd
            } else {
                promptText = cmd
            }

            let resp = try await APIService.shared.analyzeVideoCommand(
                userText: promptText,
                currentChecklistState: checklistState,
                framesBase64: [jpeg.base64EncodedString()]
            )

            var updates: [SheetUpdate] = []
            for (backendKey, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
                guard let hit = findField(backendKey, in: sections) else { continue }
                updates.append(SheetUpdate(
                    sheetSection: hit.sectionId,
                    fieldId: hit.fieldId,
                    value: sev,
                    evidenceMediaId: nil
                ))
            }
            if !updates.isEmpty { sheetVM.applyUpdates(updates, for: machine.id) }

            let summary: String
            if !updates.isEmpty {
                let risk = resp.riskScore ?? "n/a"
                summary = "Updated \(updates.count) item\(updates.count == 1 ? "" : "s") · Risk: \(risk)"
            } else if let answer = resp.answer, !answer.isEmpty {
                summary = compact(answer)
            } else {
                summary = "No updates found."
            }

            if case .guided(let step) = assistState {
                let items = orderedChecklistItems()
                if !updates.isEmpty {
                    let nextStep = step + 1
                    if nextStep < items.count {
                        assistState   = .guided(step: nextStep)
                        overlayResult = "✓ Updated — Step \(nextStep + 1)/\(items.count): \(items[nextStep])"
                    } else {
                        assistState   = .free
                        overlayResult = "Guided inspection complete."
                    }
                } else {
                    overlayResult = "No issues detected. Move closer and say \"check\" again."
                }
                overlayPhase = .done
            } else {
                overlayPhase  = .done
                overlayResult = summary
            }

        } catch {
            overlayPhase  = .error
            overlayResult = compact(error.localizedDescription)
        }

        isWorking = false
        hotword.resumeAfterCapture()
        // Return to listening state but keep result visible
        overlayPhase      = .listening
        overlayTranscript = ""
    }

    // MARK: - Bottom Bar (glassmorphic)

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            HStack(alignment: .center) {
                // Close button
                Button { dismiss() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Close")
                            .font(.barlow(14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }

                Spacer()

                // Center mic indicator
                VStack(spacing: 5) {
                    let isActive = hotword.state == .triggered
                    ZStack {
                        Circle()
                            .fill(Color.catYellow.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Circle()
                            .stroke(Color.catYellow.opacity(isActive ? 0.6 : 0.25), lineWidth: 1.5)
                            .frame(width: 50, height: 50)
                        Image(systemName: isActive ? "waveform.circle.fill" : "waveform.circle")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.catYellow)
                            .symbolEffect(.pulse, isActive: isActive)
                    }
                    Text(isActive ? "Listening…" : "Say: Hey Cat")
                        .font(.dmMono(9))
                        .foregroundStyle(isActive ? Color.catYellow.opacity(0.9) : Color.white.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: isActive)
                }

                Spacer()

                // Flip camera
                Button { camera.flip() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Helpers

    private func waitForSessionReady() async {
        let deadline = Date().addingTimeInterval(5.0)
        while !camera.isSessionReady && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func orderedChecklistItems() -> [String] {
        sheetVM.sectionsFor(machine.id).flatMap { $0.fields.map { $0.label } }
    }

    private func findField(
        _ backendKey: String,
        in sections: [SheetSection]
    ) -> (sectionId: String, fieldId: String)? {
        for sec in sections {
            if let f = sec.fields.first(where: { $0.label == backendKey || $0.id == backendKey }) {
                return (sec.id, f.id)
            }
        }
        return nil
    }

    private func compact(_ s: String, max: Int = 140) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max else { return t }
        return String(t[t.startIndex..<t.index(t.startIndex, offsetBy: max)]) + "…"
    }
}
//testing adding to github
