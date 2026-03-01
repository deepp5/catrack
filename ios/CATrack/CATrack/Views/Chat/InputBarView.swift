import SwiftUI

// MARK: - InputBarView
struct InputBarView: View {
    @Binding var text: String
    let pendingMedia: [AttachedMedia]
    let isLoading: Bool
    let onSend: () -> Void
    let onCamera: () -> Void
    let onVoice: () -> Void
    let onDocs: () -> Void
    let onRemoveMedia: (String) -> Void

    var canSend: Bool {
        (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingMedia.isEmpty) && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 0.5)

            if !pendingMedia.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingMedia) { media in
                            HStack(spacing: 5) {
                                Image(systemName: media.type.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.catYellow)
                                Text(media.filename)
                                    .font(.dmMono(11))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Button {
                                    onRemoveMedia(media.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.appMuted)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.appPanel)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color.appSurface)
            }

            HStack(alignment: .bottom, spacing: 10) {
                // Left-side media buttons
                HStack(spacing: 6) {
                    CaptureButton(icon: "camera.fill", action: onCamera)
                    CaptureButton(icon: "paperclip", action: onDocs)
                }

                // Text input (expands to fill available space)
                TextField("Describe what you see...", text: $text, axis: .vertical)
                    .font(.barlow(15))
                    .foregroundStyle(.white)
                    .tint(.catYellow)
                    .lineLimit(1...5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { onSend() }
                    }

                // Right-side buttons (mic + send)
                HStack(spacing: 6) {
                    CaptureButton(icon: "mic.fill", action: onVoice)

                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(canSend ? Color.catYellow : Color.appMuted)
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.appSurface)
        }
    }
}

// MARK: - CaptureButton
struct CaptureButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.appMuted)
                .frame(width: 34, height: 34)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
