import SwiftUI
import UIKit

struct ChatInputBar: View {
    @Binding var text: String
    @Binding var pendingAttachments: [MediaAttachment]
    var onSend: () -> Void

    @State private var showImagePicker = false
    @State private var showVideoPicker = false
    @State private var showVoiceRecorder = false
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Pending attachment chips
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingAttachments) { attachment in
                            HStack(spacing: 4) {
                                Image(systemName: attachmentIcon(for: attachment.type))
                                    .font(.caption)
                                Text(attachment.localURL.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(1)
                                Button {
                                    pendingAttachments.removeAll { $0.id == attachment.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                }
            }

            HStack(spacing: 10) {
                // Media capture buttons
                Button { showImagePicker = true } label: {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.secondary)
                }
                Button { showVideoPicker = true } label: {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.secondary)
                }
                Button { showVoiceRecorder = true } label: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
                Button { showFilePicker = true } label: {
                    Image(systemName: "paperclip")
                        .foregroundStyle(.secondary)
                }

                // Text field
                TextField("Describe what you see...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                // Send button
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty ? .secondary : .accentColor)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showImagePicker) {
            ImagePicker { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let url = saveToTemp(data: data, ext: "jpg")
                    pendingAttachments.append(MediaAttachment(type: .image, localURL: url, thumbnailData: image.jpegData(compressionQuality: 0.3)))
                }
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker { url in
                pendingAttachments.append(MediaAttachment(type: .video, localURL: url))
            }
        }
        .sheet(isPresented: $showVoiceRecorder) {
            VoiceRecorderView { url in
                pendingAttachments.append(MediaAttachment(type: .audio, localURL: url))
            }
        }
        .sheet(isPresented: $showFilePicker) {
            FilePicker { url in
                pendingAttachments.append(MediaAttachment(type: .file, localURL: url))
            }
        }
    }

    private func attachmentIcon(for type: MediaAttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .file: return "doc"
        }
    }

    private func saveToTemp(data: Data, ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
        try? data.write(to: url)
        return url
    }
}
