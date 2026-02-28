import SwiftUI

// MARK: - ChatsListView
struct ChatsListView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var sheetVM: InspectionSheetViewModel

    @State private var showNewMachineForm = false
    @State private var showMachinePicker = false
    @State private var selectedMachine: Machine?
    @State private var navigateToChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        SectionHeader(title: "ACTIVE MACHINES")

                        if machineStore.machines.isEmpty {
                            EmptyStateView(
                                icon: "wrench.and.screwdriver",
                                title: "No machines yet",
                                subtitle: "Add a machine to start an inspection"
                            )
                        } else {
                            ForEach(machineStore.machines) { machine in
                                ChatRowView(machine: machine) {
                                    selectedMachine = machine
                                    machineStore.selectMachine(machine)
                                    chatVM.startSession(for: machine)
                                    sheetVM.initSheet(for: machine.id)
                                    navigateToChat = true
                                }
                                Divider().background(Color.appBorder).padding(.leading, 72)
                            }
                        }
                    }
                }

                NavigationLink(
                    destination: Group {
                        if let machine = selectedMachine {
                            ActiveChatView(machine: machine)
                        }
                    },
                    isActive: $navigateToChat
                ) { EmptyView() }
            }
            .navigationTitle("CATrack")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewMachineForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.catYellow)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewMachineForm) {
                NewMachineFormView { machine in
                    machineStore.addMachine(machine)
                    showNewMachineForm = false
                }
            }
        }
        .tint(.catYellow)
    }
}

// MARK: - ChatRowView
struct ChatRowView: View {
    let machine: Machine
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appPanel)
                        .frame(width: 48, height: 48)
                    Image(systemName: "gearshape.2.fill")
                        .foregroundStyle(Color.catYellow)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(machine.model)
                        .font(.barlow(16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("\(machine.site) · \(machine.hours) hrs")
                        .font(.barlow(13))
                        .foregroundStyle(Color.appMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let status = machine.overallStatus {
                        SeverityBadge(severity: status)
                    }

                    if let date = machine.lastInspectedAt {
                        Text(date, style: .relative)
                            .font(.dmMono(11))
                            .foregroundStyle(Color.appMuted)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NewMachineFormView
struct NewMachineFormView: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (Machine) -> Void

    @State private var model = ""
    @State private var serial = ""
    @State private var hours = ""
    @State private var site = ""

    var isValid: Bool {
        !model.isEmpty && !serial.isEmpty && !hours.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                Form {
                    Section {
                        TextField("Model (e.g. CAT 950 GC)", text: $model)
                        TextField("Serial Number", text: $serial)
                        TextField("Hours", text: $hours)
                            .keyboardType(.numberPad)
                        TextField("Site / Location", text: $site)
                    }
                    .listRowBackground(Color.appPanel)
                    .foregroundStyle(.white)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let machine = Machine(
                            model: model,
                            serial: serial,
                            hours: Int(hours) ?? 0,
                            site: site
                        )
                        onAdd(machine)
                    }
                    .foregroundStyle(Color.catYellow)
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - NewChatMachinePickerView
struct NewChatMachinePickerView: View {
    @EnvironmentObject var machineStore: MachineStore
    @Environment(\.dismiss) private var dismiss
    var onSelect: (Machine) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                List(machineStore.machines) { machine in
                    Button {
                        onSelect(machine)
                        dismiss()
                    } label: {
                        HStack {
                            Text(machine.model)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(machine.serial)
                                .font(.dmMono(12))
                                .foregroundStyle(Color.appMuted)
                        }
                    }
                    .listRowBackground(Color.appPanel)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Select Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SectionHeader
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.dmMono(11, weight: .medium))
                .foregroundStyle(Color.appMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Spacer()
        }
        .background(Color.appBackground)
    }
}

// MARK: - EmptyStateView
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.appMuted)
            Text(title)
                .font(.barlow(18, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.barlow(14))
                .foregroundStyle(Color.appMuted)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - SeverityBadge
struct SeverityBadge: View {
    let severity: FindingSeverity

    var body: some View {
        Text(severity.shortLabel)
            .font(.dmMono(10, weight: .medium))
            .foregroundStyle(severity.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(severity.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
