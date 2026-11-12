import SwiftUI
import UIKit
import ImageIO

/// Le seul décodeur des images stockées en data URL (`data:image/jpeg;base64,…`) : photos de profil
/// et photos de machines. Le décodage se fait hors du fil principal, réduit à la taille affichée
/// (une vignette de 52 pt ne garde pas en mémoire une photo de 800 px), et une seule fois par
/// (image, taille) grâce au cache.
@MainActor
enum DataURLImage {
    private static let cache = NSCache<NSString, UIImage>()

    /// Clé de cache sans hacher les ~40 Ko du data URL à chaque affichage : propriétaire (profil ou
    /// machine), longueur, deux extraits du contenu, et la taille en pixels demandée.
    static func key(owner: String, dataURL: String, maxPixels: Int) -> NSString {
        let utf8 = dataURL.utf8
        let middle = String(decoding: utf8.dropFirst(utf8.count / 2).prefix(48), as: UTF8.self)
        let end = String(decoding: utf8.suffix(48), as: UTF8.self)
        return "\(owner)|\(utf8.count)|\(middle)|\(end)|\(maxPixels)" as NSString
    }

    /// Côté le plus long en pixels pour `points` affichés, arrondi au palier de 64 au-dessus : deux
    /// tailles voisines partagent la même entrée du cache.
    static func pixels(for points: CGFloat, scale: CGFloat) -> Int {
        let raw = Int((points * max(scale, 1)).rounded(.up))
        return max(64, (raw + 63) / 64 * 64)
    }

    static func cached(_ key: NSString) -> UIImage? { cache.object(forKey: key) }

    /// Décode et réduit hors du fil principal ; `nil` si le contenu n'est pas une image lisible.
    static func load(dataURL: String, maxPixels: Int, key: NSString) async -> UIImage? {
        if let hit = cache.object(forKey: key) { return hit }
        let image = await Task.detached(priority: .userInitiated) {
            decode(dataURL, maxPixels: maxPixels)
        }.value
        if let image { cache.setObject(image, forKey: key) }
        return image
    }

    private nonisolated static func decode(_ dataURL: String, maxPixels: Int) -> UIImage? {
        let payload = dataURL.range(of: ",").map { String(dataURL[$0.upperBound...]) } ?? dataURL
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
              let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        // Vignette décodée tout de suite (pas au premier dessin, qui serait sur le fil principal).
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Affiche une image en data URL à la taille voulue ; `placeholder` tant qu'elle n'est pas prête
/// (rien ne clignote si elle est déjà dans le cache), ou si elle est illisible.
struct DataURLImageView<Placeholder: View>: View {
    let owner: String
    let dataURL: String
    /// Côté le plus long affiché, en points.
    let points: CGFloat
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var scale
    @State private var image: UIImage?
    @State private var loadedKey: NSString?

    var body: some View {
        let maxPixels = DataURLImage.pixels(for: points, scale: scale)
        let key = DataURLImage.key(owner: owner, dataURL: dataURL, maxPixels: maxPixels)
        // Lecture directe du cache au premier affichage : pas de passage par le substitut.
        let shown = loadedKey == key ? image : DataURLImage.cached(key)
        Group {
            if let shown {
                Image(uiImage: shown).resizable().aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .task(id: key) {
            let loaded = await DataURLImage.load(dataURL: dataURL, maxPixels: maxPixels, key: key)
            image = loaded
            loadedKey = key
        }
    }
}
