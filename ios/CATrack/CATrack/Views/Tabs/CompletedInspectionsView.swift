import SwiftUI

struct CompletedInspectionsView: View {
    @EnvironmentObject var completedVM: CompletedInspectionViewModel

    var body: some View {
        NavigationStack {
            Group {
                if completedVM.completedInspections.isEmpty {
                    ContentUnavailableView(
                        "No Reports Yet",
                        systemImage: "checkmark.seal",
                        description: Text("Finalize an inspection to generate a report.")
                    )
                } else {
                    List(completedVM.completedInspections) { inspection in
                        NavigationLink(destination: CompletedReportView(inspection: inspection)) {
                            inspectionRow(inspection)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reports")
        }
    }

    private func inspectionRow(_ inspection: CompletedInspection) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(riskColor(inspection.overallRisk).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(riskColor(inspection.overallRisk))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(inspection.machine.model)
                        .font(.headline)
                    Spacer()
                    Text(inspection.overallRisk.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(riskColor(inspection.overallRisk))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                HStack {
                    Text(inspection.machine.site)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(inspection.completedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !inspection.allFindings.isEmpty {
                    Text("\(inspection.allFindings.count) finding(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func riskColor(_ risk: OverallRisk) -> Color {
        switch risk {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}
