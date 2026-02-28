import SwiftUI

struct ActiveChatView: View {
    let machine: Machine
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var sheetVM: InspectionSheetViewModel

    @State private var inputText = ""
    @State private var pendingAttachments: [MediaAttachment] = []

    var messages: [ChatMessage] {
        chatVM.sessions[machine.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(machine.model)
                        .font(.headline.bold())
                    Text("\(machine.site) · \(Int(machine.hours))h")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubbleView(message: msg)
                                .id(msg.id)
                        }
                        if chatVM.isLoading {
                            HStack {
                                ProgressView()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            ChatInputBar(text: $inputText, pendingAttachments: $pendingAttachments) {
                sendMessage()
            }
        }
        .onAppear {
            chatVM.startSession(for: machine)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        let attachments = pendingAttachments
        inputText = ""
        pendingAttachments = []

        Task {
            await chatVM.sendTextMessage(text, attachments: attachments, for: machine.id)
            // Apply any sheet updates from AI response
            if let lastMsg = chatVM.sessions[machine.id]?.last,
               let updates = lastMsg.sheetUpdates {
                sheetVM.applyUpdates(updates, for: machine.id)
            }
        }
    }
}
