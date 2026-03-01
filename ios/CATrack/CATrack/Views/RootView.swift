import SwiftUI

// MARK: - AppTab
enum AppTab: Int, CaseIterable {
    case newInspection, sheet, archive, settings

    var label: String {
        switch self {
        case .newInspection: return "Inspect"
        case .sheet:         return "Sheet"
        case .archive:       return "Archive"
        case .settings:      return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .newInspection: return "plus.circle.fill"
        case .sheet:         return "checklist"
        case .archive:       return "archivebox.fill"
        case .settings:      return "gearshape.fill"
        }
    }
}

// MARK: - RootView
struct RootView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    @State private var selectedTab: AppTab = .newInspection
    @State private var showChat: Bool = false  // active chat tab visible
    @State private var autoOpenArchiveRecord: ArchiveRecord? = nil
    @State private var hideBottomNav: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            // Chat view — always rendered, keyboard avoidance works naturally
            if let machine = machineStore.activeChatMachine {
                ActiveChatView(machine: machine)
                    .opacity(showChat ? 1 : 0)
                    .allowsHitTesting(showChat)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: K.navHeight)
                    }
            }

            // Other tabs — only shown when chat is hidden
            if !showChat {
                ZStack {
                    switch selectedTab {
                    case .newInspection:
                        InspectionPickerView { machine in
                            if !machineStore.machines.contains(where: { $0.id == machine.id }) {
                                machineStore.addMachine(machine)
                            }
                            machineStore.selectMachine(machine)
                            sheetVM.initSheet(for: machine.id)
                            chatVM.startSession(for: machine)
                            machineStore.setActiveChatMachine(machine)
                            showChat = true
                        }
                    case .sheet:
                        if machineStore.activeChatMachine != nil {
                            InspectionSheetView()
                        } else {
                            EmptyView()
                                .onAppear {
                                    selectedTab = .archive
                                }
                        }
                    case .archive:
                        ArchiveListView(autoOpenRecord: $autoOpenArchiveRecord)
                    case .settings:
                        SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, K.navHeight)
            }

            if !hideBottomNav {
                HStack(spacing: 0) {
                    // Plus / Inspect button
                    Button {
                        if machineStore.activeChatMachine != nil {
                            // Already in inspection — confirm reset or just go to picker
                            machineStore.clearActiveChatMachine()
                            showChat = false
                            selectedTab = .newInspection
                        } else {
                            showChat = false
                            selectedTab = .newInspection
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(Color.catYellow)
                            Text("Inspect")
                                .font(.barlow(10, weight: .semibold))
                                .foregroundStyle(Color.catYellow)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                    .buttonStyle(.plain)

                    // Sheet tab
                    if machineStore.activeChatMachine != nil {
                        NavTabButton(tab: .sheet, isSelected: !showChat && selectedTab == .sheet) {
                            showChat = false
                            selectedTab = .sheet
                        }
                    }

                    // Dynamic Chat tab — only shows when inspection is active
                    if machineStore.activeChatMachine != nil {
                        Button {
                            showChat = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 22, weight: showChat ? .semibold : .regular))
                                    .foregroundStyle(showChat ? Color.catYellow : Color.appMuted)
                                Text("Chat")
                                    .font(.barlow(10, weight: showChat ? .semibold : .regular))
                                    .foregroundStyle(showChat ? Color.catYellow : Color.appMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }

                    // Archive tab
                    NavTabButton(tab: .archive, isSelected: !showChat && selectedTab == .archive) {
                        showChat = false
                        selectedTab = .archive
                    }

                    // Settings tab
                    NavTabButton(tab: .settings, isSelected: !showChat && selectedTab == .settings) {
                        showChat = false
                        selectedTab = .settings
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: machineStore.activeChatMachine?.id)
                .frame(height: K.navHeight)
                .background(
                    Color.appSurface
                        .overlay(
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundStyle(Color.appBorder),
                            alignment: .top
                        )
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .didFinishInspection)) { notification in
            showChat = false
            selectedTab = .archive

            if let record = notification.object as? ArchiveRecord {
                autoOpenArchiveRecord = record
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didStartGeneratingReport)) { _ in
            hideBottomNav = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .didEndGeneratingReport)) { _ in
            hideBottomNav = false
        }
        .onChange(of: machineStore.activeChatMachine) { newValue in
            if newValue == nil {
                showChat = false
                if selectedTab == .sheet {
                    selectedTab = .archive
                }
            }
        }
    }
}

// MARK: - NavTabButton
struct NavTabButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.catYellow : Color.appMuted)
                Text(tab.label)
                    .font(.barlow(10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.catYellow : Color.appMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InspectionPickerView
struct InspectionPickerView: View {
    var onStart: (Machine) -> Void

    private let machines: [Machine] = [
        Machine(model: "Wheel Loader 950 GC", serial: "WL950-DEMO", hours: 0, site: "Demo Site"),
    ]

    @State private var selectedMachine: Machine? = nil
    @State private var dropdownOpen = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top logo (notch-safe)
                HStack {
                    Spacer()
                    Image("cat_logo")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(height: 64)
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.bottom, 6)
                .background(Color.black)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(Color.white.opacity(0.12)),
                    alignment: .bottom
                )

                // Content pushed down
                header

                // Reduced spacer so the selector card sits higher
                Spacer()
                    .frame(height: 26)

                card
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.catYellow)
                .frame(width: 3, height: 54)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("NEW INSPECTION")
                    .font(.dmMono(11, weight: .medium))
                    .foregroundStyle(Color.appMuted)

                Text("START INSPECTION")
                    .font(.system(size: 36, weight: .semibold, design: .default))
                    .foregroundStyle(.white)

                Text("Pick a machine to begin the walkaround. You can review and edit the inspection sheet after.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.appMuted)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 36)
        .padding(.bottom, 18)
    }

    private var card: some View {
        VStack(spacing: 12) {
            machineDropdown

            if let m = selectedMachine {
                machinePreview(m)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            startButton
                .padding(.top, 6)
        }
        .padding(16)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder.opacity(0.6), lineWidth: 1)
        )
    }

    private var machineDropdown: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    dropdownOpen.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.2.fill")
                        .foregroundStyle(Color.catYellow)
                        .font(.system(size: 14))

                    Text(selectedMachine?.model ?? "Select Machine")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(selectedMachine != nil ? .white : Color.appMuted)

                    Spacer()

                    Image(systemName: dropdownOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.appMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if dropdownOpen {
                VStack(spacing: 0) {
                    ForEach(machines) { machine in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedMachine = machine
                                dropdownOpen = false
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.catYellow.opacity(0.14))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "gearshape.2.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.catYellow)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(machine.model)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("\(machine.serial) • \(machine.site) • \(machine.hours) hrs")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color.appMuted)
                                }

                                Spacer()

                                if selectedMachine?.id == machine.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Color.catYellow)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(selectedMachine?.id == machine.id ? Color.catYellow.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func machinePreview(_ machine: Machine) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.catYellow.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.catYellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(machine.serial)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(machine.site) • \(machine.hours) hrs")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.appMuted)
            }

            Spacer()

//            Text("Ready")
//                .font(.system(size: 12, weight: .semibold))
//                .foregroundStyle(Color.catYellow)
//                .padding(.horizontal, 10)
//                .padding(.vertical, 6)
//                .background(Color.catYellow.opacity(0.10))
//                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var startButton: some View {
        Button {
            guard let machine = selectedMachine else { return }
            onStart(machine)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text("START INSPECTION")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .tracking(0.3)
            }
            .foregroundStyle(selectedMachine != nil ? Color.appBackground : Color.appMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(selectedMachine != nil ? Color.catYellow : Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appBorder.opacity(selectedMachine != nil ? 0 : 0.7), lineWidth: 1)
            )
        }
        .disabled(selectedMachine == nil)
        .animation(.easeInOut(duration: 0.15), value: selectedMachine?.id)
    }
}

extension Notification.Name {
    static let didFinishInspection = Notification.Name("didFinishInspection")
    static let didStartGeneratingReport = Notification.Name("didStartGeneratingReport")
    static let didEndGeneratingReport = Notification.Name("didEndGeneratingReport")
}
