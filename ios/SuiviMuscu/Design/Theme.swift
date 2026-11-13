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
    /// Texte posé directement sur le fond dégradé.
    static let onBackground = Color(hex: 0xEEF3F0)
    /// Fond des barres flottantes (onglets, barre de séance) : presque opaque, pour rester lisible.
    static let barFill = Color(hex: 0xECF1EF, opacity: 0.96)
    static let profile1 = Color(hex: 0x00806A)
    static let profile2 = Color(hex: 0xD65A1F)
    static let orange = profile2
    static let success = Color(hex: 0x0CA30C)
    /// Texte des actions qui suppriment (« Supprimer ») : rouge lisible sur fond clair.
    static let destructive = Color(hex: 0xB3261E)
    /// Fond des encarts sur l'aide (regrouper les exercices avec aide) : orange très pâle.
    static let helpTint = Color(hex: 0xF6E6DC)
    /// Fond des feuilles (sélecteur d'exercices, « Reprendre une séance »).
    static let sheetBackground = Color(hex: 0xECF1EF)
    /// Fond blanc léger d'une liste ou d'un champ posé sur une carte ou une feuille.
    static let softFill = Color.white.opacity(0.6)
    /// Bouton secondaire posé sur une barre flottante : presque blanc, pour se détacher.
    static let raisedFill = Color.white.opacity(0.9)

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

    /// Icône calée sur le style de texte le plus proche de `size` : elle grossit avec la taille de
    /// texte choisie sur le téléphone, comme le texte qui l'accompagne.
    static func icon(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let style: Font.TextStyle = switch size {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<13.5: .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<17.5: .body
        case ..<20.5: .title3
        default: .title2
        }
        return .system(style, weight: weight)
    }
}
