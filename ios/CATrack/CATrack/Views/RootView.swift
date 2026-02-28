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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            ZStack {
                // Always-rendered chat view so it never gets destroyed
                if let machine = machineStore.activeChatMachine {
                    ActiveChatView(machine: machine)
                        .opacity(showChat ? 1 : 0)
                        .allowsHitTesting(showChat)
                }

                // Other tabs rendered on top when chat not showing
                if !showChat {
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
                            showChat = true  // switch to chat tab
                        }
                    case .sheet:
                        InspectionSheetView()
                    case .archive:
                        ArchiveListView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, K.navHeight)

            // Bottom navbar
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
                NavTabButton(tab: .sheet, isSelected: !showChat && selectedTab == .sheet) {
                    showChat = false
                    selectedTab = .sheet
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
        .ignoresSafeArea(edges: .bottom)
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
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEW INSPECTION")
                    .font(.dmMono(11, weight: .medium))
                    .foregroundStyle(Color.appMuted)
                Text("Start Inspection")
                    .font(.bebasNeue(size: 32))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dropdownOpen.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundStyle(Color.catYellow)
                            .font(.system(size: 14))
                        Text(selectedMachine?.model ?? "Select Machine")
                            .font(.barlow(15))
                            .foregroundStyle(selectedMachine != nil ? .white : Color.appMuted)
                        Spacer()
                        Image(systemName: dropdownOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
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
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.catYellow.opacity(0.15))
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "gearshape.2.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.catYellow)
                                    }
                                    Text(machine.model)
                                        .font(.barlow(15))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if selectedMachine?.id == machine.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.catYellow)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedMachine?.id == machine.id ? Color.catYellow.opacity(0.08) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .zIndex(1)

            Spacer()

            Button {
                guard let machine = selectedMachine else { return }
                onStart(machine)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                    Text("START INSPECTION")
                        .font(.bebasNeue(size: 20))
                }
                .foregroundStyle(selectedMachine != nil ? Color.appBackground : Color.appMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedMachine != nil ? Color.catYellow : Color.appPanel)
                .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
            }
            .disabled(selectedMachine == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(.easeInOut(duration: 0.15), value: selectedMachine?.id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}
