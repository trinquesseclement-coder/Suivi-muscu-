import Foundation
import UIKit
import SuiviCore

/// Photo de machine : même méthode que l'avatar (`AvatarEncoder`), sans recadrage carré.
/// Le travail se fait hors du fil principal ; la règle de taille est dans `PhotoCompression` (testée).
enum PhotoEncoder {
    /// Côté le plus long 800 px, data URL JPEG d'environ 40 Ko ; `nil` si l'image est illisible.
    static func dataURL(from data: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            PhotoCompression.jpegDataURL(from: data)
        }.value
    }

    /// Photo de l'appareil photo : passée en JPEG puis réduite, le tout hors du fil principal.
    static func dataURL(from image: UIImage) async -> String? {
        await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: 0.9).flatMap { PhotoCompression.jpegDataURL(from: $0) }
        }.value
    }
}
