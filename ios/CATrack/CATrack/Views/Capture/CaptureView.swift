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
    @State private var isSending: Bool = false
    //testing adding to github
    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()
                bottomBar
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            // Mode selector
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

                // Shutter / Record button
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
            .padding(.bottom, 22)
        }
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Capture Actions

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
}
