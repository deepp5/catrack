import SwiftUI

struct GlassHotwordOverlay: View {
    enum Phase: Equatable {
        case listening
        case heard
        case analyzing
        case done
        case error
    }

    let phase: Phase
    let transcript: String
    let result: String

    private var icon: String {
        switch phase {
        case .listening:  return "waveform"
        case .heard:      return "quote.bubble"
        case .analyzing:  return "sparkles"
        case .done:       return "checkmark.circle.fill"
        case .error:      return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch phase {
        case .listening:
            return .catYellow

        case .heard:
            return .catYellow

        case .analyzing:
            return .catYellow

        case .done:
            let lower = result.lowercased()

            if lower.contains("fail") {
                return .severityFail
            }

            if lower.contains("monitor") {
                return .severityMon
            }

            if lower.contains("pass") {
                return .severityPass
            }

            return .severityPass

        case .error:
            return .severityFail
        }
    }

    private var title: String {
        switch phase {
        case .listening:  return "CAT is listening…"
        case .heard:      return "Heard"
        case .analyzing:  return "Analyzing…"
        case .done:       return "Done"
        case .error:      return "Error"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(iconColor)
                    .tracking(1.2)

                if !transcript.isEmpty {
                    Text("\"\(transcript)\"")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if !result.isEmpty {
                    Text(result)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                iconColor.opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                iconColor.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(radius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.25), value: transcript)
        .animation(.easeInOut(duration: 0.25), value: result)
    }
}
