import SwiftUI
import PhotosUI
import UIKit
import SuiviCore

/// Photo de profil : recadrée en carré, réduite à 256 px, JPEG d'environ 20 Ko (data URL).
enum AvatarEncoder {
    static let side: CGFloat = 256
    static let targetBytes = 20_000

    static func dataURL(from data: Data) -> String? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let crop = AvatarCrop.squareRect(width: image.size.width, height: image.size.height)
        let scale = side / crop.side
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(x: -crop.x * scale, y: -crop.y * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        var jpeg: Data?
        for quality in [0.8, 0.7, 0.6, 0.5, 0.4, 0.3] {
            jpeg = rendered.jpegData(compressionQuality: quality)
            if let jpeg, jpeg.count <= targetBytes { break }
        }
        guard let jpeg else { return nil }
        return "data:image/jpeg;base64," + jpeg.base64EncodedString()
    }
}

/// Avatar cliquable qui ouvre la photothèque ; « Retirer » rend l'initiale.
struct AvatarPicker: View {
    let profile: Profile
    let onChange: (String?) -> Void

    @State private var item: PhotosPickerItem?
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        let actionLabel = busy ? "Envoi…" : profile.avatar == nil ? "Ajouter une photo" : "Changer la photo"
        return HStack(spacing: 14) {
            PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                ProfileAvatar(profile: profile, size: 64)
                    .frame(width: Theme.minTouch + 16, height: Theme.minTouch + 16)
            }
            .accessibilityLabel("Changer la photo de \(profile.name)")
            VStack(alignment: .leading, spacing: 2) {
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Text(actionLabel)
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .frame(minHeight: Theme.minTouch, alignment: .leading)
                }
                .disabled(busy)
                if profile.avatar != nil {
                    Button("Retirer") { onChange(nil) }
                        .font(Theme.font(.subheadline))
                        .frame(minHeight: Theme.minTouch, alignment: .leading)
                }
                if failed {
                    Text("Impossible de lire cette image.")
                        .font(Theme.font(.footnote)).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            busy = true; failed = false
            Task {
                let data = try? await new.loadTransferable(type: Data.self)
                let url = data.flatMap { AvatarEncoder.dataURL(from: $0) }
                busy = false
                item = nil
                if let url { onChange(url) } else { failed = true }
            }
        }
    }
}
