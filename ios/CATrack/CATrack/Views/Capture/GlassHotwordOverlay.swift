import SwiftUI

// MARK: - GlassHotwordOverlay
struct GlassHotwordOverlay: View {
    enum Phase: Equatable {
        case listening
        case heard
        case analyzing
        case done
        case error
    }

    let phase:      Phase
    let transcript: String
    let result:     String

    @State private var pulseScale:   CGFloat = 1.0
    @State private var pulseOpacity: Double  = 0.6

    private var accentColor: Color {
        switch phase {
        case .listening, .heard, .analyzing: return .catYellow
        case .done:                          return .severityPass
        case .error:                         return .severityFail
        }
    }

    private var icon: String {
        switch phase {
        case .listening:  return "waveform"
        case .heard:      return "quote.bubble.fill"
        case .analyzing:  return "sparkles"
        case .done:       return "checkmark.circle.fill"
        case .error:      return "exclamationmark.triangle.fill"
        }
    }

    private var statusLabel: String {
        switch phase {
        case .listening:
            return "LISTENING"

        case .heard:
            return "HEARD"

        case .analyzing:
            return "ANALYZING"

        case .done:
            let lower = result.lowercased()

            if lower.contains("fail") {
                return "FAIL"
            }

            if lower.contains("monitor") {
                return "MONITOR"
            }

            if lower.contains("pass") {
                return "PASS"
            }

            return "DONE"

        case .error:
            return "ERROR"
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

            // Pulsing icon ring
            ZStack {
                if phase == .listening || phase == .analyzing {
                    Circle()
                        .stroke(accentColor.opacity(pulseOpacity), lineWidth: 1.5)
                        .frame(width: 46, height: 46)
                        .scaleEffect(pulseScale)
                }
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .symbolEffect(
                        .pulse,
                        isActive: phase == .listening || phase == .analyzing
                    )
            }
            .frame(width: 46, height: 46)

            // Text stack
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(statusLabel)
                        .font(.dmMono(9, weight: .bold))
                        .foregroundStyle(accentColor)
                        .tracking(1.5)
                    if phase == .listening || phase == .analyzing {
                        MiniWaveform(color: accentColor)
                    }
                }

                if !transcript.isEmpty {
                    Text("\"\(transcript)\"")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if !result.isEmpty {
                    Text(result)
                        .font(.barlow(12))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.08), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.2), accentColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: accentColor.opacity(0.18), radius: 24, x: 0, y: 8)
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: transcript)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: result)
        .onAppear { startPulse() }
        .onChange(of: phase) { _, _ in startPulse() }
    }

    private func startPulse() {
        pulseScale   = 1.0
        pulseOpacity = 0.6
        guard phase == .listening || phase == .analyzing else { return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            pulseScale   = 1.4
            pulseOpacity = 0.0
        }
    }
}

// MARK: - MiniWaveform
private struct MiniWaveform: View {
    let color: Color
    @State private var heights: [CGFloat] = [4, 8, 5, 10, 4]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 2.5, height: heights[i])
                    .animation(
                        .easeInOut(duration: 0.38)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                        value: heights[i]
                    )
            }
        }
        .onAppear {
            let targets: [CGFloat] = [11, 5, 13, 7, 10]
            for i in 0..<5 { heights[i] = targets[i] }
        }
    }
}
