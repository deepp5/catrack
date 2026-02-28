import SwiftUI

// MARK: - Brand Colors
extension Color {
    static let catYellow     = Color(hex: "#F5C400")
    static let catYellowDim  = Color(hex: "#C49D00")
    static let appBackground = Color(hex: "#000000")
    static let appSurface    = Color(hex: "#111111")
    static let appPanel      = Color(hex: "#1C1C1E")
    static let appBorder     = Color(hex: "#2C2C2E")
    static let appMuted      = Color(hex: "#636366")
    static let severityFail  = Color(hex: "#FF453A")
    static let severityMon   = Color(hex: "#FF9F0A")
    static let severityPass  = Color(hex: "#30D158")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Typography
extension Font {
    static func bebasNeue(size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size)
    }
    static func dmMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium: return .custom("DMMono-Medium", size: size)
        default:      return .custom("DMMono-Regular", size: size)
        }
    }
    static func barlow(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:        return .custom("Barlow-Bold", size: size)
        case .semibold:    return .custom("Barlow-SemiBold", size: size)
        case .heavy:       return .custom("Barlow-Black", size: size)
        default:           return .custom("Barlow-Regular", size: size)
        }
    }
}

// MARK: - Constants
enum K {
    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let navHeight: CGFloat = 82
}
