import SwiftUI

struct CompletedReportView: View {
    let inspection: CompletedInspection

    var riskColor: Color {
        switch inspection.overallRisk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(inspection.machine.model)
                                .font(.title2.bold())
                            Text("S/N: \(inspection.machine.serialNumber)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(inspection.overallRisk.rawValue)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(riskColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Text(inspection.completedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Summary
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI Summary")
                        .font(.headline)
                    Text(inspection.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // Trend Notes
                if let trendNotes = inspection.trendNotes {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trend Analysis")
                            .font(.headline)
                        Text(trendNotes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Findings
                if !inspection.allFindings.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Findings (\(inspection.allFindings.count))")
                            .font(.headline)
                        ForEach(inspection.allFindings) { finding in
                            FindingCardView(finding: finding)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Inspection Report")
        .navigationBarTitleDisplayMode(.inline)
    }
}
