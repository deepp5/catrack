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
        case .listening:  return .catYellow
        case .heard:      return .catYellow
        case .analyzing:  return .catYellow
        case .done:       return .severityPass
        case .error:      return .severityFail
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 20)
                .symbolEffect(.pulse, isActive: phase == .listening || phase == .analyzing)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.dmMono(12, weight: .semibold))
                    .foregroundStyle(.white)

                if !transcript.isEmpty {
                    Text("\(transcript)")
                        .font(.barlow(13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                }

                if !result.isEmpty {
                    Text(result)
                        .font(.barlow(12))
                        .foregroundStyle(Color.appMuted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Full width — fills whatever container gives it horizontal space
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: phase)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: transcript)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: result)
    }
}
