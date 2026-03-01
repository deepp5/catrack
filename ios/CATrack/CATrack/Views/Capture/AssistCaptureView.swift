import SwiftUI
import AVFoundation

struct AssistCaptureView: View {
    let machine: Machine

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    @StateObject private var camera = CameraController()
    @StateObject private var hotword = HotwordManager.shared

    @State private var showOverlay = false
    @State private var overlayPhase: GlassHotwordOverlay.Phase = .listening
    @State private var overlayTranscript = ""
    @State private var overlayResult = ""
    @State private var isWorking = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            // Overlay — centered at top, only visible after wake word
            VStack {
                if showOverlay {
                    GlassHotwordOverlay(
                        phase: overlayPhase,
                        transcript: overlayTranscript,
                        result: overlayResult
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
        .onAppear {
            camera.setSessionAudioEnabled(false)
            camera.start()

            Task {
                await waitForSessionReady()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s settle
                do {
                    try await hotword.requestPermissions()
                    try hotword.start()
                } catch {
                    showOverlay = true
                    overlayPhase = .error
                    overlayResult = error.localizedDescription
                }
            }
        }
        .onDisappear {
            hotword.stop()
            camera.setSessionAudioEnabled(true)
            camera.stop()
        }
        .onChange(of: hotword.state) { _, newState in
            handleHotwordState(newState)
        }
    }

    // MARK: - Hotword State Handler

    private func handleHotwordState(_ newState: HotwordManager.ListenState) {
        switch newState {
        case .idle:
            guard !isWorking else { return }
            showOverlay = false
            overlayTranscript = ""
            overlayResult = ""

        case .triggered:
            showOverlay = true
            overlayPhase = .listening
            overlayTranscript = ""
            overlayResult = ""

        case .finalCommand(let cmd):
            print("🔥 FINAL COMMAND RECEIVED:", cmd)

            showOverlay = true
            overlayPhase = .heard
            overlayTranscript = cmd
            overlayResult = ""
            isWorking = true

            Task { await runCommand(cmd) }

        case .error(let msg):
            showOverlay = true
            overlayPhase = .error
            overlayResult = msg
        }
    }

    // MARK: - Run Command

    private func runCommand(_ cmd: String) async {

        overlayPhase = .analyzing
        overlayResult = "Capturing frame…"

        hotword.pauseAudio()
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard let jpeg = await camera.captureJPEG() else {
            overlayPhase = .error
            overlayResult = "Couldn't capture frame."
            isWorking = false
            hotword.resumeAfterCapture()
            return
        }

        overlayResult = "Analyzing…"

        let sections = sheetVM.sectionsFor(machine.id)
        var checklistState: [String: String] = [:]

        for s in sections {
            for f in s.fields {
                switch f.status {
                case .pass: checklistState[f.label] = "PASS"
                case .monitor: checklistState[f.label] = "MONITOR"
                case .fail: checklistState[f.label] = "FAIL"
                case .pending: checklistState[f.label] = "none"
                }
            }
        }

        do {
            let resp = try await APIService.shared.analyzeVideoCommand(
                userText: cmd,
                currentChecklistState: checklistState,
                framesBase64: [jpeg.base64EncodedString()]
            )

            var updates: [SheetUpdate] = []

            for (backendKey, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
                guard let hit = findField(backendKey, in: sections) else { continue }

                updates.append(
                    SheetUpdate(
                        sheetSection: hit.sectionId,
                        fieldId: hit.fieldId,
                        value: sev,
                        evidenceMediaId: nil
                    )
                )
            }

            if !updates.isEmpty {
                sheetVM.applyUpdates(updates, for: machine.id)
            }

            let summary: String

            if !updates.isEmpty {
                let risk = resp.riskScore ?? "n/a"
                summary = "Updated \(updates.count) item\(updates.count == 1 ? "" : "s") · Risk: \(risk)"
            } else if let answer = resp.answer, !answer.isEmpty {
                summary = compact(answer)
            } else {
                summary = "No updates found."
            }

            overlayPhase = .done
            overlayResult = summary

        } catch {
            overlayPhase = .error
            overlayResult = compact(error.localizedDescription)
        }

        isWorking = false
        hotword.resumeAfterCapture()
    }

    // MARK: - Bottom Bar

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

                    Text("Say: Hey Cat…")
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

    // MARK: - Helpers

    private func waitForSessionReady() async {
        let deadline = Date().addingTimeInterval(4.0)
        while !camera.isSessionReady && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// Match backend key (item label) to the field in the sheet sections
    private func findField(_ backendKey: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
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
