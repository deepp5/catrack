import SwiftUI

// MARK: - AppTab
enum AppTab: Int, CaseIterable {
    case chats, sheet, archive, settings

    var label: String {
        switch self {
        case .chats:    return "Chats"
        case .sheet:    return "Sheet"
        case .archive:  return "Archive"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chats:    return "bubble.left.and.bubble.right.fill"
        case .sheet:    return "checklist"
        case .archive:  return "archivebox.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - RootView
struct RootView: View {
    @State private var selectedTab: AppTab = .chats

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .chats:
                    ChatsListView()
                case .sheet:
                    InspectionSheetView()
                case .archive:
                    ArchiveListView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, K.navHeight)

            BottomNavBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - BottomNavBar
struct BottomNavBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                NavTabButton(tab: tab, isSelected: selected == tab) {
                    selected = tab
                }
            }
        }
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
