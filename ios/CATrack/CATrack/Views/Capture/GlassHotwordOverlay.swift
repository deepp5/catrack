import SwiftUI

enum HotwordOverlayState {
    case listening
    case captured(String)
    case processing
}

struct GlassHotwordOverlay: View {
    let state: HotwordOverlayState

    private var icon: String {
        switch state {
        case .listening:   return "waveform"
        case .captured:    return "cat.fill"
        case .processing:  return "gearshape.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .listening:   return .catYellow
        case .captured:    return .catYellow
        case .processing:  return .appMuted
        }
    }

    private var headline: String {
        switch state {
        case .listening:            return "CAT is listening…"
        case .captured(let cmd):    return "\"\(cmd)\""
        case .processing:           return "On it…"
        }
    }

    private var subline: String {
        switch state {
        case .listening:   return "Speak your command after the wake word."
        case .captured:    return "Command received. Capturing frame."
        case .processing:  return "Analyzing with CAT AI."
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: state == .listening || state == .processing)

                Text(headline)
                    .font(.barlow(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()
            }

            Text(subline)
                .font(.dmMono(11))
                .foregroundStyle(Color.appMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.catYellow.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(radius: 12)
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: headline)
    }
}

// Make listening state equatable for symbolEffect
extension HotwordOverlayState: Equatable {
    static func == (lhs: HotwordOverlayState, rhs: HotwordOverlayState) -> Bool {
        switch (lhs, rhs) {
        case (.listening, .listening): return true
        case (.processing, .processing): return true
        case (.captured(let a), .captured(let b)): return a == b
        default: return false
        }
    }
}
