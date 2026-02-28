import SwiftUI

struct FindingCardView: View {
    let finding: Finding

    var severityColor: Color {
        switch finding.severity {
        case .pass: return .green
        case .monitor: return .orange
        case .fail: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(finding.severity.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(severityColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                Spacer()

                Text("Confidence: \(Int(finding.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(finding.componentType) — \(finding.componentLocation)")
                .font(.subheadline.bold())

            Text(finding.condition)
                .font(.caption)
                .foregroundStyle(.secondary)

            QuantBlockView(impact: finding.impact)

            Text("💡 \(finding.recommendation)")
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(severityColor.opacity(0.4), lineWidth: 1))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}
