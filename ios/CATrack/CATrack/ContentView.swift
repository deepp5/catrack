import SwiftUI

enum AppTab: Int, CaseIterable {
    case chats, newChat, sheet, reports
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .newChat

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            ZStack {
                PastChatsView()
                    .opacity(selectedTab == .chats ? 1 : 0)
                    .allowsHitTesting(selectedTab == .chats)

                NewChatView()
                    .opacity(selectedTab == .newChat ? 1 : 0)
                    .allowsHitTesting(selectedTab == .newChat)

                InspectionSheetView()
                    .opacity(selectedTab == .sheet ? 1 : 0)
                    .allowsHitTesting(selectedTab == .sheet)

                CompletedInspectionsView()
                    .opacity(selectedTab == .reports ? 1 : 0)
                    .allowsHitTesting(selectedTab == .reports)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Bottom Tab Bar

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: 0) {
                tabButton(tab: .chats, icon: "bubble.left.and.bubble.right.fill", label: "Chats")
                Spacer()
                newChatButton
                Spacer()
                tabButton(tab: .sheet, icon: "doc.text.fill", label: "Sheet")
                Spacer()
                tabButton(tab: .reports, icon: "checkmark.seal.fill", label: "Reports")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, bottomPadding)
            .background(colorScheme == .dark ? Color(.systemBackground) : Color(.systemBackground))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
        }
    }

    private var newChatButton: some View {
        Button {
            selectedTab = .newChat
        } label: {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 2)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }
        }
        .offset(y: -8)
    }

    private func tabButton(tab: AppTab, icon: String, label: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color(.systemGray2))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color(.systemGray2))
            }
        }
    }

    private var bottomPadding: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return (windowScene?.windows.first?.safeAreaInsets.bottom ?? 0) + 4
    }
}
