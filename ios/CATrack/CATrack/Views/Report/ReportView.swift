import SwiftUI

// MARK: - ReportView
struct ReportView: View {
    let record: ArchiveRecord

    var allFindings: [FindingCard] { record.findings }
    var failFindings: [FindingCard] { allFindings.filter { $0.severity == .fail } }
    var monFindings: [FindingCard] { allFindings.filter { $0.severity == .monitor } }
    var maxDowntime: Double { allFindings.map { $0.quantification.downtimeHigh }.max() ?? 0 }
    var totalCostHigh: Double { allFindings.reduce(0) { $0 + $1.quantification.costHigh } }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Hero Card
                    VStack(spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.machine)
                                    .font(.bebasNeue(size: 28))
                                    .foregroundStyle(.white)
                                Text(record.serial)
                                    .font(.dmMono(12))
                                    .foregroundStyle(Color.appMuted)
                                Text("\(record.site) · \(record.hours) hrs")
                                    .font(.barlow(13))
                                    .foregroundStyle(Color.appMuted)
                            }
                            Spacer()
                            RiskScoreRing(score: record.riskScore)
                        }

                        HStack(spacing: 8) {
                            ReportTag(text: record.inspector, icon: "person.fill")
                            ReportTag(text: record.formattedDate, icon: "calendar")
                            ReportTag(text: record.formattedTime, icon: "clock.fill")
                        }
                    }
                    .padding(K.cardPadding)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                    .padding(.horizontal, 16)

                    // AI Summary
                    VStack(alignment: .leading, spacing: 8) {
                        CardSectionTitle(title: "AI SUMMARY")
                        Text(record.aiSummary)
                            .font(.barlow(14))
                            .foregroundStyle(.white)
                    }
                    .padding(K.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appPanel)
                    .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                    .padding(.horizontal, 16)

                    // Impact
                    HStack(spacing: 12) {
                        ImpactCard(
                            label: "MAX DOWNTIME",
                            value: "\(Int(maxDowntime))h",
                            icon: "clock.badge.exclamationmark",
                            color: .severityMon
                        )
                        ImpactCard(
                            label: "COST EXPOSURE",
                            value: "$\(Int(totalCostHigh/1000))K",
                            icon: "dollarsign.circle.fill",
                            color: .severityFail
                        )
                    }
                    .padding(.horizontal, 16)

                    // Findings
                    if !allFindings.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            CardSectionTitle(title: "FINDINGS (\(allFindings.count))")
                            ForEach(allFindings) { finding in
                                FindingRow(finding: finding)
                                if finding.id != allFindings.last?.id {
                                    Divider().background(Color.appBorder)
                                }
                            }
                        }
                        .padding(K.cardPadding)
                        .background(Color.appPanel)
                        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                        .padding(.horizontal, 16)
                    }

                    // Trends
                    if !record.trends.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            CardSectionTitle(title: "TRENDS")
                            ForEach(record.trends) { trend in
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
                            }
                        }
                        .padding(K.cardPadding)
                        .background(Color.appPanel)
                        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
                        .padding(.horizontal, 16)
                    }

                    Color.clear.frame(height: 24)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Inspection Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - RiskScoreRing
struct RiskScoreRing: View {
    let score: Int

    var color: Color {
        score < 70 ? .severityFail : score < 85 ? .severityMon : .severityPass
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.appBorder, lineWidth: 5)
                .frame(width: 64, height: 64)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 64, height: 64)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.bebasNeue(size: 22))
                    .foregroundStyle(color)
                Text("RISK")
                    .font(.dmMono(8))
                    .foregroundStyle(Color.appMuted)
            }
        }
    }
}

// MARK: - ImpactCard
struct ImpactCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.dmMono(9))
                    .foregroundStyle(Color.appMuted)
                Text(value)
                    .font(.bebasNeue(size: 24))
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(K.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
    }
}

// MARK: - FindingRow
struct FindingRow: View {
    let finding: FindingCard

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(finding.severity.color)
                .frame(width: 3, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.componentType)
                    .font(.barlow(13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(finding.componentLocation)
                    .font(.barlow(12))
                    .foregroundStyle(Color.appMuted)
            }
            Spacer()
            SeverityBadge(severity: finding.severity)
        }
    }
}

// MARK: - ReportTag
struct ReportTag: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.appMuted)
            Text(text)
                .font(.barlow(12))
                .foregroundStyle(Color.appMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - CardSectionTitle
struct CardSectionTitle: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.dmMono(11, weight: .medium))
            .foregroundStyle(Color.appMuted)
    }
}
