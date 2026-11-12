import Foundation

/// Que faire quand l'heure de fin du repos est atteinte (décision pure, testable).
public struct RestEnd: Equatable, Sendable {
    /// Jouer la vibration, le son et l'annonce VoiceOver.
    public var signal: Bool
    /// Retirer la notification (programmée ou déjà affichée).
    public var cancelNotification: Bool

    /// Au-delà de ce retard, l'appli a été suspendue : la notification a déjà prévenu.
    public static let lateAfter: TimeInterval = 2

    /// - Fin en direct, appli active: signal, et la notification devient inutile.
    /// - Fin en arrière-plan (l'appli tourne encore quelques secondes): rien, la notification doit partir.
    /// - Réveil tardif après suspension: pas de signal, on ne garde pas la notification.
    public static func decide(now: Date, endDate: Date, isActive: Bool) -> RestEnd {
        let late = now.timeIntervalSince(endDate) > lateAfter
        return RestEnd(signal: isActive && !late, cancelNotification: isActive || late)
    }
}
