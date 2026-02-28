import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            // Attachments row
            if !message.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.attachments) { attachment in
                            MediaPreviewView(attachment: attachment)
                        }
                    }
                }
            }

            // Bubble text
            if !message.text.isEmpty {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: isUser ? .trailing : .leading)
            }

            // Finding cards for AI messages
            if let findings = message.findings, !findings.isEmpty, !isUser {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(findings) { finding in
                        FindingCardView(finding: finding)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.82)
            }

            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.horizontal, 12)
    }
}
