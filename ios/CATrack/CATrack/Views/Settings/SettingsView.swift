import SwiftUI

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var editingField: EditableField?

    enum EditableField: Identifiable {
        case inspectorName, backendURL, defaultSite
        var id: Self { self }
        var title: String {
            switch self {
            case .inspectorName: return "Inspector Name"
            case .backendURL:    return "Backend URL"
            case .defaultSite:   return "Default Site"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        SettingsGroup(title: "PROFILE") {
                            SettingsRow(
                                icon: "person.fill",
                                iconColor: .catYellow,
                                title: "Inspector Name",
                                value: settingsStore.inspectorName
                            ) { editingField = .inspectorName }

                            SettingsDivider()

                            SettingsRow(
                                icon: "map.fill",
                                iconColor: .catYellowDim,
                                title: "Default Site",
                                value: settingsStore.defaultSite.isEmpty ? "Not set" : settingsStore.defaultSite
                            ) { editingField = .defaultSite }
                        }

                        SettingsGroup(title: "BACKEND") {
                            SettingsRow(
                                icon: "server.rack",
                                iconColor: .severityPass,
                                title: "API URL",
                                value: settingsStore.backendURL
                            ) { editingField = .backendURL }
                        }

                        SettingsGroup(title: "AI") {
                            ToggleRow(
                                icon: "brain",
                                iconColor: .catYellow,
                                title: "Enable Memory",
                                isOn: $settingsStore.enableMemory
                            )
                            SettingsDivider()
                            ToggleRow(
                                icon: "eye",
                                iconColor: .catYellowDim,
                                title: "Show Confidence Scores",
                                isOn: $settingsStore.showConfidenceScores
                            )
                            SettingsDivider()
                            ToggleRow(
                                icon: "chart.bar.fill",
                                iconColor: .catYellowDim,
                                title: "Show Quantification",
                                isOn: $settingsStore.showQuantification
                            )
                        }

                        SettingsGroup(title: "WORKFLOW") {
                            ToggleRow(
                                icon: "bell.fill",
                                iconColor: .severityMon,
                                title: "Notifications",
                                isOn: $settingsStore.enableNotifications
                            )
                            SettingsDivider()
                            ToggleRow(
                                icon: "checkmark.seal.fill",
                                iconColor: .severityPass,
                                title: "Auto-Finalize Sheet",
                                isOn: $settingsStore.autoFinalizeSheet
                            )
                        }

                        // App Info
                        VStack(spacing: 4) {
                            Text("CATrack")
                                .font(.bebasNeue(size: 18))
                                .foregroundStyle(Color.catYellow)
                            Text("AI Inspection Copilot for Caterpillar Equipment")
                                .font(.barlow(12))
                                .foregroundStyle(Color.appMuted)
                                .multilineTextAlignment(.center)
                            Text("v1.0.0")
                                .font(.dmMono(10))
                                .foregroundStyle(Color.appBorder)
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $editingField) { field in
                EditFieldSheet(
                    title: field.title,
                    currentValue: {
                        switch field {
                        case .inspectorName: return settingsStore.inspectorName
                        case .backendURL:    return settingsStore.backendURL
                        case .defaultSite:   return settingsStore.defaultSite
                        }
                    }()
                ) { newValue in
                    switch field {
                    case .inspectorName: settingsStore.inspectorName = newValue
                    case .backendURL:    settingsStore.backendURL = newValue
                    case .defaultSite:   settingsStore.defaultSite = newValue
                    }
                }
            }
        }
    }
}

// MARK: - SettingsGroup
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.dmMono(11, weight: .medium))
                .foregroundStyle(Color.appMuted)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content
            }
            .background(Color.appPanel)
            .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - SettingsRow
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                SettingsIconBox(icon: icon, color: iconColor)
                Text(title)
                    .font(.barlow(15))
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .font(.barlow(14))
                    .foregroundStyle(Color.appMuted)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
            }
            .padding(.horizontal, K.cardPadding)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ToggleRow
struct ToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconBox(icon: icon, color: iconColor)
            Text(title)
                .font(.barlow(15))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.catYellow)
        }
        .padding(.horizontal, K.cardPadding)
        .padding(.vertical, 12)
    }
}

// MARK: - SettingsIconBox
struct SettingsIconBox: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.2))
                .frame(width: 32, height: 32)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
        }
    }
}

// MARK: - SettingsDivider
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.appBorder)
            .padding(.leading, 56)
    }
}

// MARK: - EditFieldSheet
struct EditFieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let currentValue: String
    let onSave: (String) -> Void

    @State private var value: String

    init(title: String, currentValue: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.currentValue = currentValue
        self.onSave = onSave
        self._value = State(initialValue: currentValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    TextField(title, text: $value)
                        .font(.barlow(16))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.appPanel)
                        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                        .padding(16)
                    Spacer()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(value)
                        dismiss()
                    }
                    .foregroundStyle(Color.catYellow)
                }
            }
        }
    }
}
