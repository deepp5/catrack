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
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 20) {

                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(iconColor)

                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                if !transcript.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(transcript)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                if !result.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Result")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(result)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(width: geo.size.width,
                   height: geo.size.height * 0.5,
                   alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(radius: 20)
        }
        .ignoresSafeArea(edges: .top)
    }
}
