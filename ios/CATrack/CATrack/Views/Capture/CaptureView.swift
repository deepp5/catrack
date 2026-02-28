import SwiftUI
import AVFoundation

enum CaptureMode: String, CaseIterable {
    case video = "VIDEO"
    case photo = "PHOTO"
}

struct CaptureView: View {
    let machineId: UUID

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    @StateObject private var camera = CameraController()
    @State private var mode: CaptureMode = .photo

    // Fix: HotwordManager is @MainActor ObservableObject — use @StateObject, not @ObservedObject
    @StateObject private var hotword = HotwordManager.shared

    @State private var lastHandledCommand: String? = nil
    @State private var isSending: Bool = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                if hotword.isTriggered {
                    GlassHotwordOverlay(stateText: "Hey Cat…", confirmed: false)
                } else if let cmd = hotword.confirmedCommand {
                    GlassHotwordOverlay(stateText: "Heard: \(cmd)", confirmed: true)
                }
                Spacer()
            }

            VStack {
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            camera.start()
            Task {
                do {
                    try await hotword.requestPermissions()
                    try hotword.start()
                } catch {
                    print("Hotword error:", error)
                }
            }
        }
        .onDisappear {
            camera.stop()
        }
        // Fix: onChange(of:perform:) deprecated in iOS 17 — use two-argument form
        .onChange(of: hotword.confirmedCommand) { _, newValue in
            guard let cmd = newValue else { return }
            if lastHandledCommand == cmd { return }
            lastHandledCommand = cmd
            Task { await handleCommand(cmd) }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                ForEach(CaptureMode.allCases, id: \.self) { m in
                    Text(m.rawValue)
                        .font(.dmMono(12, weight: .medium))
                        .foregroundStyle(m == mode ? Color.catYellow : Color.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(m == mode ? Color.white.opacity(0.10) : Color.clear)
                        )
                        .onTapGesture { mode = m }
                }
            }
            .padding(.top, 6)

            HStack {
                Button("Close") { dismiss() }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                Button {
                    Task {
                        if mode == .photo {
                            await manualSnapshot()
                        } else {
                            await toggleVideoRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 72, height: 72)
                        Circle().stroke(Color.white.opacity(0.5), lineWidth: 4).frame(width: 82, height: 82)
                        if mode == .video {
                            Circle()
                                .fill(camera.isRecording ? Color.severityFail : Color.clear)
                                .frame(width: 26, height: 26)
                        }
                    }
                }
                .disabled(isSending)

                Spacer()

                Button {
                    camera.flip()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func toggleVideoRecording() async {
        if camera.isRecording {
            if let url = await camera.stopRecording() {
                let media = AttachedMedia(type: .video, filename: url.lastPathComponent, localURL: url, thumbnailData: nil)
                chatVM.attachMedia(media)
                dismiss()
            }
        } else {
            camera.startRecording()
        }
    }

    private func manualSnapshot() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        guard let data = await camera.captureJPEG() else { return }
        let media = AttachedMedia(type: .image, filename: "photo.jpg", thumbnailData: data)
        chatVM.attachMedia(media)
        dismiss()
    }

    private func handleCommand(_ cmd: String) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        guard let jpeg = await camera.captureJPEG() else { return }
        let base64 = jpeg.base64EncodedString()

        let sections = sheetVM.sectionsFor(machineId)
        var currentChecklistState: [String: String] = [:]
        for sec in sections {
            for field in sec.fields {
                currentChecklistState[field.id] = field.status.rawValue
            }
        }

        do {
            let resp = try await APIService.shared.analyzeVideoCommand(
                userText: cmd,
                currentChecklistState: currentChecklistState,
                framesBase64: [base64]
            )

            var sheetUpdates: [SheetUpdate] = []
            for (backendKey, upd) in resp.checklistUpdates {
                guard let sev = FindingSeverity(rawValue: upd.status) else { continue }
                guard let hit = findFieldByBackendKey(backendKey, in: sections) else { continue }
                sheetUpdates.append(SheetUpdate(sheetSection: hit.sectionId, fieldId: hit.fieldId, value: sev, evidenceMediaId: nil))
            }
            if !sheetUpdates.isEmpty {
                sheetVM.applyUpdates(sheetUpdates, for: machineId)
            }
        } catch {
            print("analyzeVideoCommand error:", error)
        }
    }

    private func findFieldByBackendKey(_ key: String, in sections: [SheetSection]) -> (sectionId: String, fieldId: String)? {
        for sec in sections {
            if let f = sec.fields.first(where: { $0.id == key }) {
                return (sec.id, f.id)
            }
        }
        return nil
    }
}
