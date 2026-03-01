import SwiftUI

// MARK: - InspectionSheetView
struct InspectionSheetView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var archiveStore: ArchiveStore
    @EnvironmentObject var settingsStore: SettingsStore

    @State private var isGeneratingReport = false
    @State private var reportErrorMessage: String? = nil
    @State private var showReportError = false

    var machine: Machine? { machineStore.activeMachine }

    var sections: [SheetSection] {
        guard let m = machine else { return [] }
        return sheetVM.sectionsFor(m.id)
    }
    //testing adding to github
    var body: some View {
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
                                            Divider()
                                                .background(Color.appBorder)
                                                .padding(.leading, 16)
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
                        generateReport()
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

                    Text("Tap Inspect to start a new inspection.")
                        .font(.barlow(14))
                        .foregroundStyle(Color.appMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            }

            // Generating overlay
            if isGeneratingReport {
                ZStack {
                    Color.black.opacity(0.8).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.catYellow))
                            .scaleEffect(1.8)

                        Text("Generating Report...")
                            .font(.barlow(14, weight: .semibold))
                            .foregroundStyle(Color.appMuted)
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isGeneratingReport)
            }
        }
        .alert("Report Error", isPresented: $showReportError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(reportErrorMessage ?? "Unknown error")
        })
    }

    private func generateReport() {
        guard !isGeneratingReport else { return }

        let possibleKeys = ["activeInspectionId", "inspectionId", "currentInspectionId", "active_inspection_id"]
        let inspectionId = possibleKeys
            .compactMap { UserDefaults.standard.string(forKey: $0) }
            .first

        guard let inspectionId, !inspectionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            reportErrorMessage = "Missing inspection_id. Make sure you started an inspection before generating a report."
            showReportError = true
            return
        }

        NotificationCenter.default.post(name: .didStartGeneratingReport, object: nil)
        isGeneratingReport = true

        Task {
            do {
                let flatChecklist: [String: String] = sections.reduce(into: [:]) { result, section in
                    for field in section.fields {
                        result[field.label] = field.status.rawValue
                    }
                }

                // Sync latest manual updates before generating report
                try await APIService.shared.syncChecklist(inspectionId: inspectionId, checklist: flatChecklist)

                // Generate report
                let report = try await APIService.shared.generateReport(inspectionId: inspectionId)

                await MainActor.run {
                    NotificationCenter.default.post(name: .didEndGeneratingReport, object: nil)
                    isGeneratingReport = false
                    finalizeInspection(with: report)
                }
            } catch {
                await MainActor.run {
                    NotificationCenter.default.post(name: .didEndGeneratingReport, object: nil)
                    isGeneratingReport = false
                    reportErrorMessage = error.localizedDescription
                    showReportError = true
                }
            }
        }
    }

    private func severityRank(_ s: FindingSeverity) -> Int {
        switch s {
        case .pending: return 0
        case .pass: return 1
        case .monitor: return 2
        case .fail: return 3
        }
    }

    private func finalizeInspection(with report: GenerateReportResponse) {
        guard let machine = machine else { return }

        let allFindings = sections.flatMap { section in
            section.fields.compactMap { field -> FindingCard? in
                guard field.status != .pass, field.status != .pending else { return nil }

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
                        costLow: 0, costHigh: 0, downtimeLow: 0, downtimeHigh: 0
                    )
                )
            }
        }

        let overallStatus = sections.map { $0.overallStatus }
            .max(by: { severityRank($0) < severityRank($1) }) ?? .pass

        let summaryLines: [String] = [
            report.executiveSummary,
            "",
            report.operationalReadiness,
            "",
            report.criticalFindings.isEmpty ? "" : ("Critical Findings:\n- " + report.criticalFindings.joined(separator: "\n- ")),
            "",
            report.recommendations.isEmpty ? "" : ("Recommendations:\n- " + report.recommendations.joined(separator: "\n- "))
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let record = ArchiveRecord(
            machine: machine.model,
            serial: machine.serial,
            date: Date(),
            inspector: settingsStore.inspectorName,
            site: machine.site,
            hours: machine.hours,
            riskScore: report.riskScore,
            aiSummary: summaryLines.joined(separator: "\n"),
            sections: sections,
            findings: allFindings,
            estimatedCost: 0,
            trends: []
        )

        archiveStore.add(record)
        machineStore.updateStatus(machineId: machine.id, status: overallStatus)
        sheetVM.resetSheet(for: machine.id)
        machineStore.clearActiveChatMachine()

        NotificationCenter.default.post(name: .didFinishInspection, object: record)
    }
}

// MARK: - SheetMachineStrip
struct SheetMachineStrip: View {
    let machine: Machine

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2.fill")
                .foregroundStyle(Color.catYellow)
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 2) {
                Text(machine.model)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(machine.serial) • \(machine.hours) hrs")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.appMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appSurface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(Color.appBorder),
            alignment: .bottom
        )
    }
}

// MARK: - SheetSectionHeader
struct SheetSectionHeader: View {
    let section: SheetSection

    var body: some View {
        HStack {
            Text(section.title.uppercased())
                .font(.dmMono(13, weight: .medium))
                .foregroundStyle(Color.appMuted)

            Spacer()

            SheetStatusPill(status: section.overallStatus)
        }
        .padding(.horizontal, K.cardPadding)
        .padding(.vertical, 12)
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
                        .font(.system(size: 12))
                        .foregroundStyle(Color.catYellowDim)
                }

                Text(field.label)
                    .font(.barlow(16))
                    .foregroundStyle(.white)

                Spacer()

                SheetSegmentedControl(selected: field.status) { newStatus in
                    onUpdate(newStatus, noteText)
                }
            }
            .padding(.horizontal, K.cardPadding)
            .padding(.vertical, 13)

            if !field.note.isEmpty || showNote {
                TextField("Add note...", text: $noteText)
                    .font(.barlow(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, K.cardPadding)
                    .padding(.bottom, 10)
                    .onSubmit {
                        onUpdate(field.status, noteText)
                        showNote = false
                    }
            }
        }
        .onTapGesture {
            if field.note.isEmpty {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showNote.toggle()
                }
            }
        }
        .onChange(of: field.note) { newValue in
            // Keep local editor synced if AI updates the note
            if noteText != newValue {
                noteText = newValue
            }
        }
    }
}

// MARK: - SheetSegmentedControl
struct SheetSegmentedControl: View {
    let selected: FindingSeverity
    let onSelect: (FindingSeverity) -> Void

    private let options: [FindingSeverity] = [.pass, .monitor, .fail]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { severity in
                Button {
                    onSelect(severity)
                } label: {
                    Text(severity.shortLabel)
                        .font(.dmMono(11, weight: .medium))
                        .foregroundStyle(selected == severity ? .black : severity.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selected == severity ? severity.color : severity.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
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
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 7, height: 7)

            Text(status.shortLabel)
                .font(.dmMono(12, weight: .medium))
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - FinalizeBar
struct FinalizeBar: View {
    let sections: [SheetSection]
    let onFinalize: () -> Void

    var failCount: Int    { sections.flatMap { $0.fields }.filter { $0.status == .fail }.count }
    var monCount: Int     { sections.flatMap { $0.fields }.filter { $0.status == .monitor }.count }
    var pendingCount: Int { sections.flatMap { $0.fields }.filter { $0.status == .pending }.count }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                if failCount > 0 {
                    Label("\(failCount) FAIL", systemImage: "xmark.circle.fill")
                        .font(.dmMono(13, weight: .medium))
                        .foregroundStyle(Color.severityFail)
                }

                if monCount > 0 {
                    Label("\(monCount) MON", systemImage: "exclamationmark.circle.fill")
                        .font(.dmMono(13, weight: .medium))
                        .foregroundStyle(Color.severityMon)
                }

                if pendingCount > 0 {
                    Label("\(pendingCount) remaining", systemImage: "circle.dotted")
                        .font(.dmMono(11, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                }

                if failCount == 0 && monCount == 0 && pendingCount == 0 {
                    Label("All Clear", systemImage: "checkmark.circle.fill")
                        .font(.dmMono(13, weight: .medium))
                        .foregroundStyle(Color.severityPass)
                }
            }

            Spacer()

            Button(action: onFinalize) {
                Text("GENERATE REPORT")
                    .font(.dmMono(15, weight: .medium))
                    .foregroundStyle(pendingCount == 0 ? .black : Color.appMuted)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(pendingCount == 0 ? Color.catYellow : Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
            }
            .disabled(pendingCount > 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appSurface)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(Color.appBorder),
            alignment: .top
        )
    }
}
