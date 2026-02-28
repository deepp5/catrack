import SwiftUI

struct QuantBlockView: View {
    let impact: QuantifiedImpact

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                quantItem(label: "Failure Prob.", value: String(format: "%.0f%%", impact.probabilityOfFailure * 100))
                Divider()
                quantItem(label: "Time to Fail", value: impact.timeToFailure)
            }
            HStack {
                quantItem(label: "Safety Risk", value: String(format: "%.0f/100", impact.safetyRisk))
                Divider()
                quantItem(label: "Cost Range", value: impact.costImpactRange)
            }
            Text("Operational: \(impact.operationalImpact)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func quantItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
