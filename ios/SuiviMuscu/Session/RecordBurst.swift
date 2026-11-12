import SwiftUI

/// Record battu : un trophée qui grossit et 8 particules en 0,6 s.
/// Posé en superposition, il ne capte aucun toucher.
struct RecordBurst: View {
    /// Chaque incrément rejoue l'animation ; 0 = jamais déclenché.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Frame {
        var scale: Double = 0.4
        var spread: Double = 0
        var opacity: Double = 0
    }

    private static let gold = Color(hex: 0xE89B00)
    private static let colors: [Color] = [gold, Theme.profile1, Theme.orange, Theme.success]

    var body: some View {
        KeyframeAnimator(initialValue: Frame(), trigger: trigger) { f in
            ZStack {
                if !reduceMotion {
                    ForEach(0..<8, id: \.self) { i in
                        let angle = Double(i) / 8 * 2 * .pi
                        Circle()
                            .fill(Self.colors[i % Self.colors.count])
                            .frame(width: 9, height: 9)
                            .offset(x: cos(angle) * f.spread, y: sin(angle) * f.spread)
                            .opacity(f.opacity)
                    }
                }
                AppIcon.trophy.image
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Self.gold)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                    .scaleEffect(reduceMotion ? 1 : f.scale)
                    .opacity(f.opacity)
            }
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.35, duration: 0.25, spring: .snappy)
                CubicKeyframe(1.0, duration: 0.2)
                CubicKeyframe(1.0, duration: 0.15)
            }
            KeyframeTrack(\.spread) {
                CubicKeyframe(70, duration: 0.5)
                CubicKeyframe(78, duration: 0.1)
            }
            KeyframeTrack(\.opacity) {
                LinearKeyframe(1, duration: 0.08)
                LinearKeyframe(1, duration: 0.32)
                LinearKeyframe(0, duration: 0.2)
            }
        }
        .frame(width: 180, height: 180)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
