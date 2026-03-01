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
                        Text("Select a machine from the Chats tab to begin")
                            .font(.barlow(14))
                            .foregroundStyle(Color.appMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                }
            }
            .alert("Report Error", isPresented: $showReportError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(reportErrorMessage ?? "Unknown error")
            })
            .navigationTitle("Inspection Sheet")
            .navigationBarTitleDisplayMode(.large)
        }
    }


    private func generateReport() {
        guard !isGeneratingReport else { return }

        // Try to locate the active backend inspection id.
        // Prefer UserDefaults keys so this view compiles even if other stores change.
        let possibleKeys = ["activeInspectionId", "inspectionId", "currentInspectionId", "active_inspection_id"]
        let inspectionId = possibleKeys
            .compactMap { UserDefaults.standard.string(forKey: $0) }
            .first

        guard let inspectionId, !inspectionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            reportErrorMessage = "Missing inspection_id. Make sure you started an inspection before generating a report."
            showReportError = true
            return
        }

        isGeneratingReport = true

        Task {
            do {
                //Flatten current sheet state into backend checklist format
                let flatChecklist: [String: String] = sections.reduce(into: [:]) { result, section in
                    for field in section.fields {
                        result[field.label] = field.status.rawValue
                    }
                }

                //Sync latest manual updates to backend before generating report
                try await APIService.shared.syncChecklist(
                    inspectionId: inspectionId,
                    checklist: flatChecklist
                )

                // Calls FastAPI /generate-report
                let report = try await APIService.shared.generateReport(inspectionId: inspectionId)
                await MainActor.run {
                    isGeneratingReport = false
                    finalizeInspection(with: report)
                }
            } catch {
                await MainActor.run {
                    isGeneratingReport = false
                    reportErrorMessage = error.localizedDescription
                    showReportError = true
                }
            }
        }
    }

    private func finalizeInspection(with report: GenerateReportResponse) {
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

        let allStatuses = sections.map { $0.overallStatus }
        let overallStatus = allStatuses.max(by: { severityRank($0) < severityRank($1) }) ?? .pass

        // Prefer AI report risk if present.
        let riskScore: Int
        switch report.overallRisk.lowercased() {
        case "high":
            riskScore = 55
        case "moderate":
            riskScore = 75
        case "low":
            riskScore = 95
        default:
            switch overallStatus {
            case .fail:    riskScore = 55
            case .monitor: riskScore = 75
            case .pass:    riskScore = 95
            }
        }

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
            riskScore: riskScore,
            aiSummary: summaryLines.joined(separator: "\n"),
            sections: sections,
            findings: allFindings,
            estimatedCost: 0,
            trends: []
        )
        archiveStore.add(record)
        machineStore.updateStatus(machineId: machine.id, status: overallStatus)
        sheetVM.resetSheet(for: machine.id)
    }

    private func severityRank(_ s: FindingSeverity) -> Int {
        switch s {
        case .pass:    return 0
        case .monitor: return 1
        case .fail:    return 2
        }
    }

    private func finalizeInspection() {
        // If we are generating via AI report, this path is not used.
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

        let allStatuses = sections.map { $0.overallStatus }
        let overallStatus = allStatuses.max(by: { severityRank($0) < severityRank($1) }) ?? .pass

        let riskScore: Int
        switch overallStatus {
        case .fail:    riskScore = 55
        case .monitor: riskScore = 75
        case .pass:    riskScore = 95
        }

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
                Text("GENERATE REPORT")
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


//Add commment
