import SwiftUI
import SuiviCore

/// Photo de profil (data URL JPEG), sinon l'initiale sur la couleur du profil.
struct ProfileAvatar: View {
    let profile: Profile
    var size: CGFloat = 40
    /// Liseré blanc autour (en-tête de l'Accueil).
    var ring = false

    var body: some View {
        let color = Theme.color(for: profile)
        Group {
            if let avatar = profile.avatar, !avatar.isEmpty {
                DataURLImageView(owner: profile.id, dataURL: avatar, points: size) { initial(color) }
            } else {
                initial(color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ring ? Color.white : color, lineWidth: ring ? 2 : 1.5))
        .accessibilityHidden(true)
    }

    private func initial(_ color: Color) -> some View {
        Text(String(profile.name.prefix(1)).uppercased())
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
    }
}
