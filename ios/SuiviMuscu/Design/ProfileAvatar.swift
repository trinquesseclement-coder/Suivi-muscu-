import SwiftUI
import UIKit
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
            if let image = AvatarDecoder.image(from: profile.avatar) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(ring ? Color.white : color, lineWidth: ring ? 2 : 1.5))
        .accessibilityHidden(true)
    }
}

/// Décode `data:image/jpeg;base64,…` une seule fois par photo.
enum AvatarDecoder {
    @MainActor private static let cache = NSCache<NSString, UIImage>()

    @MainActor static func image(from dataURL: String?) -> UIImage? {
        guard let dataURL, !dataURL.isEmpty else { return nil }
        let key = dataURL as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let payload = dataURL.range(of: ",").map { String(dataURL[$0.upperBound...]) } ?? dataURL
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
