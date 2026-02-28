import SwiftUI

// MARK: - InspectionSheetView
struct InspectionSheetView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var archiveStore: ArchiveStore
    @EnvironmentObject var settingsStore: SettingsStore

    @State private var showFinalizeConfirm = false

    var machine: Machine? { machineStore.activeMachine }
    var sections: [SheetSection] {
        guard let m = machine else { return [] }
        return sheetVM.sectionsFor(m.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if let machine = machine {
                    VStack(spacing: 0) {
                        SheetMachineStrip(machine: machine)

                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(sections) { section in
                                    VStack(spacing: 0) {
                                        SheetSectionHeader(section: section)
                                        ForEach(section.fields) { field in
                                            SheetFieldCard(
                                                field: field,
                                                onUpdate: { newStatus, note in
                                                    sheetVM.updateField(
                                                        machineId: machine.id,
                                                        sectionId: section.id,
                                                        fieldId: field.id,
                                                        status: newStatus,
                                                        note: note
                                                    )
                                                }
                                            )
                                            if field.id != section.fields.last?.id {
                                                Divider().background(Color.appBorder).padding(.leading, 16)
                                            }
                                        }
                                    }
                                    .background(Color.appPanel)
                                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                                    .padding(.horizontal, 16)
                                }
                                Color.clear.frame(height: 80)
                            }
                            .padding(.top, 12)
                        }

                        FinalizeBar(sections: sections) {
                            showFinalizeConfirm = true
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist")
                            .font(.system(size: 52))
                            .foregroundStyle(Color.appMuted)
                        Text("No Active Inspection")
                            .font(.barlow(18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Select a machine from the Chats tab to begin")
                            .font(.barlow(14))
                            .foregroundStyle(Color.appMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }
            }
            .navigationTitle("Inspection Sheet")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Finalize Inspection?", isPresented: $showFinalizeConfirm, titleVisibility: .visible) {
                Button("Finalize & Archive", role: .none) { finalizeInspection() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will save the inspection to your archive.")
            }
        }
    }

    private func finalizeInspection() {
        guard let machine = machine else { return }
        let allFindings = sections.flatMap { section in
            section.fields.compactMap { field -> FindingCard? in
                guard field.status != .pass else { return nil }
                return FindingCard(
                    componentType: field.label,
                    componentLocation: section.title,
                    condition: field.note.isEmpty ? field.label : field.note,
                    severity: field.status,
                    confidence: 1.0,
                    quantification: Quantification(
                        failureProbability: field.status == .fail ? 0.8 : 0.4,
                        timeToFailure: "N/A",
                        safetyRisk: field.status == .fail ? 70 : 30,
                        safetyLabel: field.status == .fail ? "High" : "Moderate",
                        costLow: 0,
                        costHigh: 0,
                        downtimeLow: 0,
                        downtimeHigh: 0
                    )
                )
            }
        }
        let overallStatus = sections.map { $0.overallStatus }.max {
            ($0 == .pass ? 0 : $0 == .monitor ? 1 : 2) < ($1 == .pass ? 0 : $1 == .monitor ? 1 : 2)
        } ?? .pass
        let riskScore = overallStatus == .fail ? 55 : overallStatus == .monitor ? 75 : 95

        let record = ArchiveRecord(
            machine: machine.model,
            serial: machine.serial,
            date: Date(),
            inspector: settingsStore.inspectorName,
            site: machine.site,
            hours: machine.hours,
            riskScore: riskScore,
            aiSummary: "Manual inspection completed. \(allFindings.count) issue(s) found.",
            sections: sections,
            findings: allFindings,
            estimatedCost: 0,
            trends: []
        )
        archiveStore.add(record)
        machineStore.updateStatus(machineId: machine.id, status: overallStatus)
        sheetVM.resetSheet(for: machine.id)
    }
}

// MARK: - SheetMachineStrip
struct SheetMachineStrip: View {
    let machine: Machine
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2.fill")
                .foregroundStyle(Color.catYellow)
            VStack(alignment: .leading, spacing: 1) {
                Text(machine.model)
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(machine.serial) · \(machine.hours) hrs")
                    .font(.dmMono(11))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.appBorder), alignment: .bottom)
    }
}

// MARK: - SheetSectionHeader
struct SheetSectionHeader: View {
    let section: SheetSection
    var body: some View {
        HStack {
            Text(section.title.uppercased())
                .font(.dmMono(11, weight: .medium))
                .foregroundStyle(Color.appMuted)
            Spacer()
            SheetStatusPill(status: section.overallStatus)
        }
        .padding(.horizontal, K.cardPadding)
        .padding(.vertical, 10)
        .background(Color.appSurface.opacity(0.5))
    }
}

// MARK: - SheetFieldCard
struct SheetFieldCard: View {
    let field: SheetField
    let onUpdate: (FindingSeverity, String) -> Void

    @State private var showNote = false
    @State private var noteText: String

    init(field: SheetField, onUpdate: @escaping (FindingSeverity, String) -> Void) {
        self.field = field
        self.onUpdate = onUpdate
        self._noteText = State(initialValue: field.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if field.aiPrefilled {
                    Image(systemName: "brain")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.catYellowDim)
                }

                Text(field.label)
                    .font(.barlow(14))
                    .foregroundStyle(.white)

                Spacer()

                SheetSegmentedControl(selected: field.status) { newStatus in
                    onUpdate(newStatus, noteText)
                }
            }
            .padding(.horizontal, K.cardPadding)
            .padding(.vertical, 10)

            if !field.note.isEmpty || showNote {
                TextField("Add note...", text: $noteText, onCommit: {
                    onUpdate(field.status, noteText)
                    showNote = false
                })
                .font(.barlow(13))
                .foregroundStyle(Color.appMuted)
                .padding(.horizontal, K.cardPadding)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - SheetSegmentedControl
struct SheetSegmentedControl: View {
    let selected: FindingSeverity
    let onSelect: (FindingSeverity) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FindingSeverity.allCases) { severity in
                Button {
                    onSelect(severity)
                } label: {
                    Text(severity.shortLabel)
                        .font(.dmMono(9, weight: .medium))
                        .foregroundStyle(selected == severity ? .black : severity.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(selected == severity ? severity.color : severity.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - SheetStatusPill
struct SheetStatusPill: View {
    let status: FindingSeverity
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.shortLabel)
                .font(.dmMono(10, weight: .medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - FinalizeBar
struct FinalizeBar: View {
    let sections: [SheetSection]
    let onFinalize: () -> Void

    var failCount: Int { sections.flatMap { $0.fields }.filter { $0.status == .fail }.count }
    var monCount: Int { sections.flatMap { $0.fields }.filter { $0.status == .monitor }.count }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if failCount > 0 {
                        Label("\(failCount) FAIL", systemImage: "xmark.circle.fill")
                            .font(.dmMono(11, weight: .medium))
                            .foregroundStyle(Color.severityFail)
                    }
                    if monCount > 0 {
                        Label("\(monCount) MON", systemImage: "exclamationmark.circle.fill")
                            .font(.dmMono(11, weight: .medium))
                            .foregroundStyle(Color.severityMon)
                    }
                    if failCount == 0 && monCount == 0 {
                        Label("All Clear", systemImage: "checkmark.circle.fill")
                            .font(.dmMono(11, weight: .medium))
                            .foregroundStyle(Color.severityPass)
                    }
                }
            }
            Spacer()
            Button(action: onFinalize) {
                Text("FINALIZE")
                    .font(.dmMono(13, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.catYellow)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.appBorder), alignment: .top)
    }
}
