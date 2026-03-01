//import SwiftUI
//
//struct GlassHotwordOverlay: View {
//    enum Phase: Equatable {
//        case listening
//        case heard
//        case analyzing
//        case done
//        case error
//    }
//
//    let phase: Phase
//    let transcript: String
//    let result: String
//    let isOn: Bool
//
//    private var icon: String {
//        switch phase {
//        case .listening: return "waveform"
//        case .heard:     return "quote.bubble"
//        case .analyzing: return "sparkles"
//        case .done:      return "checkmark.circle.fill"
//        case .error:     return "exclamationmark.triangle.fill"
//        }
//    }
//
//    private var iconColor: Color {
//        switch phase {
//        case .listening: return .catYellow
//        case .heard:     return .catYellow
//        case .analyzing: return .catYellow
//        case .done:      return .severityPass
//        case .error:     return .severityFail
//        }
//    }
//
//    private var title: String {
//        switch phase {
//        case .listening: return "CAT is listening…"
//        case .heard:     return "Heard"
//        case .analyzing: return "Analyzing…"
//        case .done:      return "Done"
//        case .error:     return "Error"
//        }
//    }
//
//    var body: some View {
//        HStack(alignment: .top, spacing: 10) {
//            Image(systemName: icon)
//                .font(.system(size: 14, weight: .semibold))
//                .foregroundStyle(iconColor)
//                .frame(width: 18)
//                .symbolEffect(.pulse, isActive: phase == .listening || phase == .analyzing)
//
//            VStack(alignment: .leading, spacing: 4) {
//                // Row 1: status + ON badge
//                HStack(spacing: 6) {
//                    Text(title)
//                        .font(.dmMono(11, weight: .semibold))
//                        .foregroundStyle(.white)
//
//                    Spacer(minLength: 6)
//
//                    Text(isOn ? "ON" : "OFF")
//                        .font(.dmMono(10, weight: .medium))
//                        .foregroundStyle(isOn ? Color.catYellow : Color.appMuted)
//                        .padding(.horizontal, 6)
//                        .padding(.vertical, 2)
//                        .background(Color.white.opacity(0.06))
//                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
//                }
//
//                // Row 2: transcript
//                if !transcript.isEmpty {
//                    Text("\(transcript)")
//                        .font(.barlow(12, weight: .medium))
//                        .foregroundStyle(Color.white.opacity(0.92))
//                        .lineLimit(1)
//                }
//
//                // Row 3: result
//                if !result.isEmpty {
//                    Text(result)
//                        .font(.barlow(12))
//                        .foregroundStyle(Color.appMuted)
//                        .lineLimit(2)
//                }
//            }
//        }
//        .padding(.horizontal, 12)
//        .padding(.vertical, 10)
//        .frame(maxWidth: 340, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                .fill(.ultraThinMaterial)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 14, style: .continuous)
//                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
//                )
//        )
//        .shadow(radius: 12)
//        .transition(.move(edge: .top).combined(with: .opacity))
//        .animation(.spring(response: 0.3), value: phase)
//        .animation(.spring(response: 0.3), value: result)
//    }
//}


import SwiftUI

struct GlassHotwordOverlay: View {
    enum Phase: Equatable {
        case listening   // wake word heard, collecting command
        case heard       // command captured, about to analyze
        case analyzing   // waiting on backend
        case done        // result ready
        case error       // something went wrong
    }

    let phase: Phase
    let transcript: String   // what the user said
    let result: String       // AI response / update summary

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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 18)
                .symbolEffect(.pulse, isActive: phase == .listening || phase == .analyzing)

            VStack(alignment: .leading, spacing: 4) {
                // Status row
                Text(title)
                    .font(.dmMono(11, weight: .semibold))
                    .foregroundStyle(.white)

                // Transcript row
                if !transcript.isEmpty {
                    Text("\(transcript)")
                        .font(.barlow(12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                }

                // Result row
                if !result.isEmpty {
                    Text(result)
                        .font(.barlow(12))
                        .foregroundStyle(Color.appMuted)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(radius: 12)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: phase)
        .animation(.spring(response: 0.3), value: result)
    }
}
