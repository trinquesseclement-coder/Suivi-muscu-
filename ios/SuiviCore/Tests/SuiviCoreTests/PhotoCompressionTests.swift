import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import SuiviCore

@Suite struct PhotoCompressionTests {
    /// Image PNG de synthèse : dégradé et bruit, pour que le JPEG ait du détail à compresser
    /// (une photo de salle, pas un aplat).
    private static func png(width: Int, height: Int, noise: Bool = true) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * height)
        var seed: UInt32 = 12345
        for y in 0..<height {
            for x in 0..<width {
                seed = seed &* 1_103_515_245 &+ 12345
                let n = noise ? Int(seed >> 24) % 60 : 0
                let i = y * ctx.bytesPerRow + x * 4
                pixels[i] = UInt8(min(255, x * 255 / max(1, width) / 2 + n))
                pixels[i + 1] = UInt8(min(255, y * 255 / max(1, height) / 2 + n))
                pixels[i + 2] = UInt8(min(255, (x + y) % 200 + n / 2))
                pixels[i + 3] = 255
            }
        }
        let image = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// Décode le data URL produit et rend (octets du data URL, largeur, hauteur).
    private static func inspect(_ url: String) -> (count: Int, width: Int, height: Int)? {
        guard url.hasPrefix("data:image/jpeg;base64,"),
              let data = Data(base64Encoded: String(url.dropFirst("data:image/jpeg;base64,".count))),
              let src = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return (url.utf8.count, image.width, image.height)
    }

    @Test func largePhotoIsReducedToAbout40KB() throws {
        let url = try #require(PhotoCompression.jpegDataURL(from: Self.png(width: 3000, height: 2000)))
        let r = try #require(Self.inspect(url))
        #expect(max(r.width, r.height) <= 800)
        #expect(r.width == 800)
        #expect(r.count <= PhotoCompression.maxBytes)
    }

    @Test func portraitKeepsItsLongestSideAt800() throws {
        let url = try #require(PhotoCompression.jpegDataURL(from: Self.png(width: 1200, height: 1600)))
        let r = try #require(Self.inspect(url))
        #expect(r.height == 800)
        #expect(r.width == 600)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let url = try #require(PhotoCompression.jpegDataURL(from: Self.png(width: 300, height: 200, noise: false)))
        let r = try #require(Self.inspect(url))
        #expect(r.width == 300)
        #expect(r.height == 200)
        #expect(r.count <= PhotoCompression.targetBytes)
    }

    @Test func garbageGivesNil() {
        #expect(PhotoCompression.jpegDataURL(from: Data("pas une image".utf8)) == nil)
        #expect(PhotoCompression.jpegDataURL(from: Data()) == nil)
    }
}
