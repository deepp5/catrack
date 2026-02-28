import SwiftUI

// MARK: - MessageBubbleView
struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        Group {
            switch message.role {
            case .system:
                SystemMessageView(message: message)
            case .user:
                UserMessageView(message: message)
            case .assistant:
                AIMessageView(message: message)
            }
        }
    }
}

// MARK: - SystemMessageView
struct SystemMessageView: View {
    let message: Message
    var body: some View {
        HStack {
            Spacer()
            Text(message.text)
                .font(.dmMono(10))
                .foregroundStyle(Color.appMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Spacer()
        }
    }
}

// MARK: - UserMessageView
struct UserMessageView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 6) {

                // Media chips
                if !message.media.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(message.media) { media in
                                MediaChipView(media: media)
                            }
                        }
                    }
                }

                // Voice note bubble
                if let url = message.voiceNoteURL,
                   let duration = message.voiceNoteDuration {
                    VoiceNoteBubble(url: url, duration: duration)
                }

                // Text bubble
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.barlow(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.catYellow.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                }
            }
        }
    }
}

// MARK: - MediaChipView
struct MediaChipView: View {
    let media: AttachedMedia

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: media.type.icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.catYellow)
            Text(media.filename)
                .font(.dmMono(11))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - AIMessageView
struct AIMessageView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AIAvatarView()
            VStack(alignment: .leading, spacing: 8) {
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.barlow(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.appPanel)
                        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                }

                ForEach(message.findings) { finding in
                    FindingCardView(finding: finding)
                }

                if let note = message.memoryNote {
                    MemoryBadgeView(note: note)
                }
            }
            Spacer(minLength: 20)
        }
    }
}

// MARK: - MemoryBadgeView
struct MemoryBadgeView: View {
    let note: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain")
                .font(.system(size: 11))
                .foregroundStyle(Color.catYellowDim)
            Text(note)
                .font(.dmMono(10))
                .foregroundStyle(Color.catYellowDim)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.catYellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
