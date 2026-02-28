import SwiftUI

// MARK: - FindingCardView
struct FindingCardView: View {
    let finding: FindingCard
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(finding.severity.color)
                        .frame(width: 4, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(finding.componentType.uppercased())
                                .font(.dmMono(11, weight: .medium))
                                .foregroundStyle(finding.severity.color)
                            if finding.seenBefore {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.appMuted)
                            }
                        }
                        Text(finding.componentLocation)
                            .font(.barlow(13, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        SeverityBadge(severity: finding.severity)
                        ConfidenceBarView(confidence: finding.confidence)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.appMuted)
                }
                .padding(K.cardPadding)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(finding.condition)
                        .font(.barlow(14))
                        .foregroundStyle(Color(hex: "#EBEBF5"))
                        .padding(.horizontal, K.cardPadding)

                    if let trend = finding.trend {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.catYellowDim)
                            Text(trend)
                                .font(.dmMono(11))
                                .foregroundStyle(Color.catYellowDim)
                        }
                        .padding(.horizontal, K.cardPadding)
                    }

                    QuantGridView(q: finding.quantification)
                        .padding(.horizontal, K.cardPadding)
                        .padding(.bottom, K.cardPadding)
                }
            }
        }
        .background(Color.appPanel)
        .clipShape(RoundedRectangle(cornerRadius: K.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: K.cornerRadius)
                .stroke(finding.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - QuantGridView
struct QuantGridView: View {
    let q: Quantification

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            QuantCell(label: "FAILURE PROB", value: q.failureProbabilityPercent, color: q.probSeverityColor)
            QuantCell(label: "TIME TO FAIL", value: q.timeToFailure, color: .white)
            QuantCell(label: "SAFETY RISK", value: "\(q.safetyRisk)/100", color: q.safetySeverityColor)
            QuantCell(label: "COST RANGE", value: q.costRange, color: .white)
            QuantCell(label: "DOWNTIME", value: q.downtimeRange, color: .white)
            QuantCell(label: "SAFETY LABEL", value: q.safetyLabel, color: q.safetySeverityColor)
        }
    }
}

// MARK: - QuantCell
struct QuantCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.dmMono(9))
                .foregroundStyle(Color.appMuted)
            Text(value)
                .font(.dmMono(13, weight: .medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ConfidenceBarView
struct ConfidenceBarView: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: 3) {
            Text("AI")
                .font(.dmMono(8))
                .foregroundStyle(Color.appMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appBorder)
                        .frame(width: geo.size.width, height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.catYellow)
                        .frame(width: geo.size.width * confidence, height: 3)
                }
            }
            .frame(width: 36, height: 3)
            Text("\(Int(confidence * 100))%")
                .font(.dmMono(8))
                .foregroundStyle(Color.appMuted)
        }
    }
}
