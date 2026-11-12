import SwiftUI
import SuiviCore

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let backgroundTop = Color(hex: 0x64746F)
    static let backgroundBottom = Color(hex: 0x46534F)
    static let glass = Color(hex: 0xECF1EF, opacity: 0.84)
    static let glassBorder = Color.white.opacity(0.5)
    static let ink = Color(hex: 0x17201D)
    static let ink2 = Color(hex: 0x17201D, opacity: 0.72)
    static let profile1 = Color(hex: 0x00806A)
    static let profile2 = Color(hex: 0xD65A1F)
    static let orange = profile2
    static let success = Color(hex: 0x0CA30C)

    static let cardRadius: CGFloat = 26
    static let smallRadius: CGFloat = 18
    static let minTouch: CGFloat = 48

    static var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    static func color(for profile: Profile) -> Color {
        profile.slot == 2 ? profile2 : profile1
    }

    static func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
