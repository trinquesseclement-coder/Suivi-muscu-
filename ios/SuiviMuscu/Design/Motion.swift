import SwiftUI

enum Motion {
    static let spring: Animation = .spring(duration: 0.35, bounce: 0.2)
    static func stagger(_ i: Int) -> Animation { spring.delay(0.06 * Double(i)) }
    static let reduced: Animation = .easeInOut(duration: 0.2)
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.reduced : animation, value: value)
    }
}

extension View {
    /// Anime, ou bascule sur un simple fondu si « Réduire les animations » est actif.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}
