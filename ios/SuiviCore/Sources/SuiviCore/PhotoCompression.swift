import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Photo de machine : côté le plus long ramené à 800 px (jamais agrandie), JPEG dont le data URL
/// pèse environ 40 Ko (60 Ko au plus). Pur ImageIO / CoreGraphics : appelé hors du fil principal.
public enum PhotoCompression {
    public static let maxSide = 800
    /// Taille visée du data URL stocké (en octets).
    public static let targetBytes = 40_000
    /// Taille acceptée si la photo est très détaillée : au-delà, on réduit encore l'image.
    public static let maxBytes = 60_000

    static let prefix = "data:image/jpeg;base64,"
    static let qualities: [Double] = [0.8, 0.7, 0.6, 0.5, 0.4, 0.3]

    /// `nil` si les données ne sont pas une image lisible.
    public static func jpegDataURL(from data: Data) -> String? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard !data.isEmpty,
              let src = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary),
              CGImageSourceGetCount(src) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { return nil }

        var side = min(maxSide, max(w, h))
        while side >= 200 {
            // La vignette d'ImageIO lit l'image réduite sans charger la photo entière en mémoire,
            // et applique l'orientation EXIF.
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: side,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary),
                  let flat = flattened(thumb) else { return nil }
            var smallest: String?
            for q in qualities {
                guard let jpeg = jpeg(flat, quality: q) else { return nil }
                let url = prefix + jpeg.base64EncodedString()
                smallest = url
                if url.utf8.count <= targetBytes { return url }
            }
            if let smallest, smallest.utf8.count <= maxBytes { return smallest }
            // Trop de détail même à la qualité la plus basse : on réduit l'image.
            side = side * 4 / 5
        }
        return nil
    }

    /// Sur fond blanc (une image transparente ne devient pas noire en JPEG), en sRGB.
    static func flattened(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(rect)
        ctx.draw(image, in: rect)
        return ctx.makeImage()
    }

    static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
