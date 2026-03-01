import SwiftUI

// MARK: - Part Recommendation Model
struct PartRecommendation: Identifiable {
    var id = UUID()
    var partName: String
    var partNumber: String
    var estimatedPrice: String
    var fixesIssue: String
    var severity: FindingSeverity
}

// MARK: - SettingsView (Parts Recommendations)
struct SettingsView: View {
    @EnvironmentObject var machineStore: MachineStore
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    var machine: Machine? { machineStore.activeMachine }

    var sections: [SheetSection] {
        guard let m = machine else { return [] }
        return sheetVM.sectionsFor(m.id)
    }

    var failFields: [(section: String, field: SheetField)] {
        sections.flatMap { section in
            section.fields
                .filter { $0.status == .fail || $0.status == .monitor }
                .map { (section: section.title, field: $0) }
        }
    }

    var chatFindings: [FindingCard] {
        guard let m = machine else { return [] }
        return chatVM.messagesFor(m.id).flatMap { $0.findings }
    }

    var recommendations: [PartRecommendation] {
        var parts: [PartRecommendation] = []

        for item in failFields {
            parts.append(PartRecommendation(
                partName: partName(for: item.field.label),
                partNumber: partNumber(for: item.field.label),
                estimatedPrice: estimatedPrice(for: item.field.status),
                fixesIssue: item.field.label + " — " + item.section,
                severity: item.field.status
            ))
        }

        for finding in chatFindings {
            parts.append(PartRecommendation(
                partName: finding.componentType + " Replacement",
                partNumber: "CAT-\(finding.componentType.prefix(3).uppercased())-SVC",
                estimatedPrice: "$\(Int(finding.quantification.costLow))–$\(Int(finding.quantification.costHigh))",
                fixesIssue: finding.componentLocation,
                severity: finding.severity
            ))
        }

        return parts.sorted { severityRank($0.severity) > severityRank($1.severity) }
    }

    var failParts: [PartRecommendation] { recommendations.filter { $0.severity == .fail } }
    var monParts: [PartRecommendation]  { recommendations.filter { $0.severity == .monitor } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if machine == nil {
                    emptyState(
                        icon: "wrench.and.screwdriver",
                        title: "No Active Inspection",
                        subtitle: "Start an inspection to get part recommendations."
                    )
                } else if recommendations.isEmpty {
                    emptyState(
                        icon: "checkmark.seal.fill",
                        title: "No Parts Needed",
                        subtitle: "No issues found yet.\nMark fields as FAIL or MON to see recommendations."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {

                            // Machine header
                            if let machine = machine {
                                HStack(spacing: 10) {
                                    Image(systemName: "gearshape.2.fill")
                                        .foregroundStyle(Color.catYellow)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(machine.model)
                                            .font(.barlow(14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Text("\(recommendations.count) part(s) recommended")
                                            .font(.dmMono(11))
                                            .foregroundStyle(Color.appMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                        .foregroundStyle(Color.catYellow)
                                        .font(.system(size: 14))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.appSurface)
                                .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                                .padding(.horizontal, 16)
                            }

                            if !failParts.isEmpty {
                                PartsSectionLabel(title: "CRITICAL — IMMEDIATE ACTION", color: .severityFail)
                                ForEach(failParts) { part in
                                    PartCard(part: part)
                                }
                            }

                            if !monParts.isEmpty {
                                PartsSectionLabel(title: "MONITOR — PLAN REPLACEMENT", color: .severityMon)
                                ForEach(monParts) { part in
                                    PartCard(part: part)
                                }
                            }

                            Color.clear.frame(height: 80)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Parts")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 52))
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

    private func severityRank(_ s: FindingSeverity) -> Int {
        switch s {
        case .pending: return 0
        case .pass:    return 1
        case .monitor: return 2
        case .fail:    return 3
        }
    }

    private func partName(for label: String) -> String {
        let map: [String: String] = [
            "Engine oil":                         "Engine Oil Filter",
            "Engine coolant":                     "Coolant Flush Kit",
            "Radiator":                           "Radiator Assembly",
            "All hoses and lines":                "Hydraulic Hose Kit",
            "Fuel filters / water separator":     "Fuel Filter Element",
            "All belts":                          "Serpentine Belt Kit",
            "Air filter":                         "Air Filter Element",
            "Battery compartment":                "Battery 12V Heavy Duty",
            "Tires, wheels, stem caps, lug nuts": "Tire Stem Cap Set",
            "Hydraulic tank":                     "Hydraulic Filter Element",
            "Transmission oil":                   "Transmission Filter Kit",
            "Seat belt and mounting":             "Seat Belt Assembly",
            "Fire extinguisher":                  "Fire Extinguisher 5lb",
            "Windshield and windows":             "Windshield Glass",
            "Windshield wipers / washers":        "Wiper Blade Set",
            "Differential and final drive oil":   "Final Drive Oil Seal Kit",
            "Transmission, transfer case":        "Transmission Service Kit",
            "Axles, final drives, differentials, brakes": "Brake Pad Set",
            "Horn, backup alarm, lights":         "Backup Alarm Unit",
            "Gauges, indicators, switches, controls": "Instrument Cluster",
        ]
        return map[label] ?? "\(label) Service Kit"
    }

    private func partNumber(for label: String) -> String {
        let map: [String: String] = [
            "Engine oil":                         "1R-0716",
            "Engine coolant":                     "8C-3672",
            "Radiator":                           "6I-2501",
            "All hoses and lines":                "5P-0732",
            "Fuel filters / water separator":     "1R-0755",
            "All belts":                          "7X-7967",
            "Air filter":                         "6I-2506",
            "Battery compartment":                "4P-5578",
            "Tires, wheels, stem caps, lug nuts": "9X-8562",
            "Hydraulic tank":                     "1R-0726",
            "Transmission oil":                   "4T-6788",
            "Seat belt and mounting":             "5I-7671",
            "Fire extinguisher":                  "9U-5141",
            "Windshield and windows":             "2S-4689",
            "Windshield wipers / washers":        "4K-8341",
            "Differential and final drive oil":   "3E-6825",
            "Transmission, transfer case":        "6V-8639",
            "Axles, final drives, differentials, brakes": "8E-9763",
            "Horn, backup alarm, lights":         "2T-7981",
            "Gauges, indicators, switches, controls": "1U-8812",
        ]
        return map[label] ?? "CAT-\(label.prefix(3).uppercased())-SVC"
    }

    private func estimatedPrice(for status: FindingSeverity) -> String {
        switch status {
        case .fail:    return "$80–$350"
        case .monitor: return "$40–$150"
        default:       return "$20–$80"
        }
    }
}

// MARK: - PartsSectionLabel
struct PartsSectionLabel: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 12)
                .clipShape(Capsule())
            Text(title)
                .font(.dmMono(10, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}

// MARK: - PartCard
struct PartCard: View {
    let part: PartRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.partName)
                        .font(.barlow(15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(part.partNumber)
                        .font(.dmMono(12, weight: .medium))
                        .foregroundStyle(Color.catYellow)
                }
                Spacer()
                Text(part.severity.shortLabel)
                    .font(.dmMono(10, weight: .medium))
                    .foregroundStyle(part.severity.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(part.severity.color.opacity(0.15))
                    .clipShape(Capsule())
            }

            Divider().background(Color.appBorder)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FIXES")
                        .font(.dmMono(9, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                    Text(part.fixesIssue)
                        .font(.barlow(13))
                        .foregroundStyle(Color.appMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("EST. PRICE")
                        .font(.dmMono(9, weight: .medium))
                        .foregroundStyle(Color.appMuted)
                    Text(part.estimatedPrice)
                        .font(.dmMono(14, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(K.cardPadding)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: K.cornerRadius)
                .strokeBorder(part.severity.color.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
