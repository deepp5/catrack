import SwiftUI

// MARK: - ActiveChatView
struct ActiveChatView: View {
    let machine: Machine

    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var sheetVM: InspectionSheetViewModel

    @State private var inputText = ""
    @State private var showCamera = false
    @State private var showVoice = false
    @State private var showDocs = false
    @State private var showAssist = false
    @FocusState private var inputFocused: Bool

    var messages: [Message] {
        chatVM.messagesFor(machine.id).filter { $0.role != .system }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Image("cat_logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320)
                .opacity(0.10)
                .blur(radius: 0.6)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                MachineContextBar(machine: machine, onAssist: { showAssist = true })

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                            if chatVM.isLoading {
                                TypingIndicatorView()
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onTapGesture {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                InputBarView(
                    text: $inputText,
                    pendingMedia: chatVM.pendingMedia,
                    isLoading: chatVM.isLoading,
                    onSend: {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty || !chatVM.pendingMedia.isEmpty else { return }
                        inputText = ""
                        Task {
                            await chatVM.sendMessage(
                                text: text, machineId: machine.id,
                                machine: machine, sheetVM: sheetVM)
                        }
                    },
                    onCamera: { showCamera = true },
                    onVoice:  { showVoice  = true },
                    onDocs:   { showDocs   = true },
                    onRemoveMedia: { chatVM.removeMedia(id: $0) }
                )
                .focused($inputFocused)
            }
        }
        .fullScreenCover(isPresented: $showAssist) {
            AssistCaptureView(machine: machine)
                .environmentObject(chatVM)
                .environmentObject(sheetVM)
        }
        .sheet(isPresented: $showCamera) {
            CaptureView(machineId: machine.id)
                .environmentObject(chatVM)
                .environmentObject(sheetVM)
        }
        .sheet(isPresented: $showVoice) {
            VoiceRecorderView { url, duration in
                Task {
                    await chatVM.sendVoiceNote(
                        url: url, duration: duration,
                        machineId: machine.id, machine: machine, sheetVM: sheetVM)
                }
            }
        }
        .sheet(isPresented: $showDocs) {
            DocumentPickerView { url in
                let media = AttachedMedia(type: .file, filename: url.lastPathComponent, localURL: url)
                chatVM.attachMedia(media)
            }
        }
    }
}

// MARK: - MachineContextBar
struct MachineContextBar: View {
    let machine: Machine
    var onAssist: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2.fill")
                .foregroundStyle(Color.catYellow)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 1) {
                Text(machine.serial)
                    .font(.dmMono(12, weight: .medium))
                    .foregroundStyle(Color.appMuted)
                Text("\(machine.site) · \(machine.hours) hrs")
                    .font(.barlow(12))
                    .foregroundStyle(Color.appMuted)
            }

            Spacer()

            if let status = machine.overallStatus {
                SeverityBadge(severity: status)
            }

            if let onAssist {
                Button(action: onAssist) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.catYellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.appBorder),
            alignment: .bottom
        )
    }
}

// MARK: - TypingIndicatorView
struct TypingIndicatorView: View {
    @State private var dotOpacity: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AIAvatarView()
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.appMuted)
                        .frame(width: 6, height: 6)
                        .opacity(dotOpacity[i])
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: dotOpacity[i]
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.appPanel)
            .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
            Spacer()
        }
        .onAppear {
            for i in 0..<3 { dotOpacity[i] = 0.9 }
        }
    }
}
