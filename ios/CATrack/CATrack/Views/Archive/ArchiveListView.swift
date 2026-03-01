import SwiftUI

// MARK: - ArchiveListView
struct ArchiveListView: View {
    @Binding var autoOpenRecord: ArchiveRecord?
    @EnvironmentObject var archiveStore: ArchiveStore
    @EnvironmentObject var machineStore: MachineStore

    @State private var searchText = ""
    @State private var selectedRecord: ArchiveRecord?
    @State private var compareRecord: ArchiveRecord?
    @State private var showCompare = false
    @State private var navigationPath: [ArchiveRecord] = []

    var filtered: [ArchiveRecord] {
        guard !searchText.isEmpty else { return archiveStore.records }
        return archiveStore.records.filter {
            $0.machine.localizedCaseInsensitiveContains(searchText) ||
            $0.serial.localizedCaseInsensitiveContains(searchText) ||
            $0.site.localizedCaseInsensitiveContains(searchText)
        }
    }
    //testing adding to github
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if archiveStore.records.isEmpty {
                    EmptyStateView(
                        icon: "archivebox",
                        title: "No Inspections Yet",
                        subtitle: "Completed inspections will appear here"
                    )
                } else {
                    ScrollView {
                        // Stats strip
                        HStack(spacing: 12) {
                            ArchiveStat(label: "TOTAL", value: "\(archiveStore.records.count)")
                            ArchiveStat(label: "FAILS", value: "\(archiveStore.records.filter { $0.riskScore < 70 }.count)", color: .severityFail)
                            ArchiveStat(label: "MON", value: "\(archiveStore.records.filter { $0.riskScore >= 70 && $0.riskScore < 85 }.count)", color: .severityMon)
                            ArchiveStat(label: "PASS", value: "\(archiveStore.records.filter { $0.riskScore >= 85 }.count)", color: .severityPass)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        VStack(spacing: 8) {
                            ForEach(filtered) { record in
                                NavigationLink(value: record) {
                                    ArchiveRowView(record: record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Color.clear.frame(height: 20)
                    }
                    .searchable(text: $searchText, prompt: "Search inspections…")
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ArchiveRecord.self) { record in
                ArchiveDetailView(record: record)
            }
        }
        .tint(.catYellow)
        .onChange(of: autoOpenRecord) { newValue in
            if let record = newValue {
                navigationPath = [record]
                autoOpenRecord = nil
            }
        }
    }
}

// MARK: - ArchiveRowView
struct ArchiveRowView: View {
    let record: ArchiveRecord

    var body: some View {
        HStack(spacing: 12) {
            RiskScoreRing(score: record.riskScore)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.machine)
                    .font(.barlow(15, weight: .semibold))
                    .foregroundStyle(.white)

                Text("\(record.site) · \(record.hours) hrs")
                    .font(.barlow(12))
                    .foregroundStyle(Color.appMuted)

                HStack(spacing: 6) {
                    Text(record.inspector)
                        .font(.dmMono(11))
                        .foregroundStyle(Color.appMuted)
                    Text("·")
                        .foregroundStyle(Color.appBorder)
                    Text(record.formattedDate)
                        .font(.dmMono(11))
                        .foregroundStyle(Color.appMuted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(record.findings.count) findings")
                    .font(.dmMono(10))
                    .foregroundStyle(Color.appMuted)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appMuted)
            }
        }
        .padding(K.cardPadding)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - ArchiveStat
struct ArchiveStat: View {
    let label: String
    let value: String
    var color: Color = .white

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.bebasNeue(size: 24))
                .foregroundStyle(color)
            Text(label)
                .font(.dmMono(9))
                .foregroundStyle(Color.appMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ArchiveDetailView
struct ArchiveDetailView: View {
    let record: ArchiveRecord

    @EnvironmentObject var archiveStore: ArchiveStore

    var previousRecord: ArchiveRecord? {
        let same = archiveStore.recordsFor(serial: record.serial)
        guard let idx = same.firstIndex(of: record), idx + 1 < same.count else { return nil }
        return same[idx + 1]
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    ArchiveHeroCard(record: record)
                        .padding(.horizontal, 16)

                    if let prev = previousRecord {
                        CompareBannerView(current: record, previous: prev)
                            .padding(.horizontal, 16)
                    }

                    if !record.trends.isEmpty {
                        TrendGridView(trends: record.trends)
                            .padding(.horizontal, 16)
                    }

                    ForEach(record.sections) { section in
                        ReadOnlySectionCard(section: section)
                            .padding(.horizontal, 16)
                    }

                    InspectorSignOffCard(record: record)
                        .padding(.horizontal, 16)

                    Color.clear.frame(height: 24)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(record.machine)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ArchiveRecord.self) { r in
            ReportView(record: r)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(value: record) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Color.catYellow)
                }
            }
        }
        .tint(.catYellow)
    }
}

// MARK: - CompareBannerView
struct CompareBannerView: View {
    let current: ArchiveRecord
    let previous: ArchiveRecord

    var scoreDelta: Int { current.riskScore - previous.riskScore }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Color.catYellowDim)
            VStack(alignment: .leading, spacing: 1) {
                Text("COMPARED TO PREVIOUS")
                    .font(.dmMono(9))
                    .foregroundStyle(Color.appMuted)
                Text("Risk score \(scoreDelta >= 0 ? "+" : "")\(scoreDelta) pts vs \(previous.formattedDate)")
                    .font(.barlow(13))
                    .foregroundStyle(scoreDelta >= 0 ? Color.severityPass : Color.severityFail)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - TrendGridView
struct TrendGridView: View {
    let trends: [TrendItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardSectionTitle(title: "TRENDS")
            ForEach(trends) { trend in
                HStack {
                    Text(trend.label)
                        .font(.barlow(13))
                        .foregroundStyle(Color.appMuted)
                    Spacer()
                    Text(trend.value)
                        .font(.dmMono(13, weight: .medium))
                        .foregroundStyle(.white)
                    Text(trend.delta)
                        .font(.dmMono(11))
                        .foregroundStyle(trend.direction.color)
                }
                if trend.id != trends.last?.id {
                    Divider().background(Color.appBorder)
                }
            }
        }
        .padding(K.cardPadding)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - ArchiveHeroCard
struct ArchiveHeroCard: View {
    let record: ArchiveRecord

    /// Splits the aiSummary into named sections based on known headers.
    private var parsedSections: [(title: String?, lines: [String])] {
        let raw = record.aiSummary
        let knownHeaders = ["Critical Findings:", "Recommendations:"]

        var sections: [(title: String?, lines: [String])] = []
        var currentTitle: String? = nil
        var currentLines: [String] = []

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if knownHeaders.contains(trimmed) {
                if !currentLines.isEmpty {
                    sections.append((currentTitle, currentLines))
                }
                currentTitle = trimmed.replacingOccurrences(of: ":", with: "")
                currentLines = []
            } else {
                currentLines.append(trimmed)
            }
        }
        if !currentLines.isEmpty {
            sections.append((currentTitle, currentLines))
        }
        return sections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Machine header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.machine)
                        .font(.bebasNeue(size: 24))
                        .foregroundStyle(.white)
                    Text(record.serial)
                        .font(.dmMono(12))
                        .foregroundStyle(Color.appMuted)
                }
                Spacer()
                RiskScoreRing(score: record.riskScore)
            }

            Divider().background(Color.appBorder)

            // Structured summary sections
            ForEach(Array(parsedSections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = section.title {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(title == "Critical Findings" ? Color.severityFail : Color.catYellow)
                                .frame(width: 3, height: 12)
                            Text(title.uppercased())
                                .font(.dmMono(10, weight: .medium))
                                .foregroundStyle(title == "Critical Findings" ? Color.severityFail : Color.catYellow)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(section.lines, id: \.self) { line in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color.appMuted)
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(line.hasPrefix("- ") ? String(line.dropFirst(2)) : line)
                                        .font(.barlow(13))
                                        .foregroundStyle(Color(hex: "#EBEBF5"))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    } else {
                        // Executive summary — no header, plain prose
                        ForEach(section.lines, id: \.self) { line in
                            Text(line)
                                .font(.barlow(13))
                                .foregroundStyle(Color(hex: "#EBEBF5"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(K.cardPadding)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - ReadOnlySectionCard
struct ReadOnlySectionCard: View {
    let section: SheetSection

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(section.title.uppercased())
                    .font(.dmMono(11, weight: .medium))
                    .foregroundStyle(Color.appMuted)
                Spacer()
                SheetStatusPill(status: section.overallStatus)
            }
            .padding(K.cardPadding)
            .background(Color.appSurface.opacity(0.5))

            ForEach(section.fields) { field in
                HStack {
                    Text(field.label)
                        .font(.barlow(13))
                        .foregroundStyle(.white)
                    Spacer()
                    SeverityBadge(severity: field.status)
                }
                .padding(.horizontal, K.cardPadding)
                .padding(.vertical, 8)
                if field.id != section.fields.last?.id {
                    Divider().background(Color.appBorder).padding(.leading, K.cardPadding)
                }
            }
        }
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - InspectorSignOffCard
struct InspectorSignOffCard: View {
    let record: ArchiveRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.system(size: 22))
                .foregroundStyle(Color.catYellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Inspected by \(record.inspector)")
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(record.formattedDate) at \(record.formattedTime)")
                    .font(.dmMono(11))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
        }
        .padding(K.cardPadding)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}
