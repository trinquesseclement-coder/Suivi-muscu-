import Foundation

/// Calcul du recadrage carré de la photo de profil (même règle que `appli/src/lib/image.ts`).
public enum AvatarCrop {
    public struct Rect: Equatable, Sendable {
        public var x: Double, y: Double, side: Double
    }

    /// Carré du plus petit côté. Centré, sauf sur un portrait : le visage est dans le haut,
    /// donc on remonte le carré (40 % de l'écart au lieu de 50 %).
    public static func squareRect(width: Double, height: Double) -> Rect {
        let side = min(width, height)
        let x = (width - side) / 2
        let y = (height - side) * (height > width ? 0.4 : 0.5)
        return Rect(x: x, y: y, side: side)
    }
}
