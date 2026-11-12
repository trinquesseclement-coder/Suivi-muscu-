import SwiftUI
import SuiviCore
import AudioToolbox
import UserNotifications

// MARK: - Modèle

/// Minuteur de repos d'une séance. Il se base sur l'**heure de fin** (pas sur un décompte) :
/// le temps restant reste juste après un passage en arrière-plan ou un écran verrouillé.
/// L'affichage se rafraîchit chaque seconde (`TimelineView`), le modèle ne tourne pas tout seul.
@Observable @MainActor
final class RestTimerModel {
    /// Heure de fin du repos ; `nil` = pas de minuteur.
    private(set) var endDate: Date?
    /// Durée totale (sert à dessiner l'anneau), allongée par « +30 ».
    private(set) var total: Int = 0
    /// Repos terminé, minuteur encore affiché quelques secondes.
    private(set) var finished = false
    /// Incrémenté à la fin du repos : déclenche la vibration (`.sensoryFeedback`).
    private(set) var finishCount = 0

    var isActive: Bool { endDate != nil }

    /// Secondes restantes, arrondies au-dessus (0 une fois terminé).
    var remaining: Int { remaining(at: Date()) }

    func remaining(at now: Date) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int((endDate.timeIntervalSince(now)).rounded(.up)))
    }

    private var endTask: Task<Void, Never>?
    private static let notificationId = "rest-timer"
    /// Le temps que reste affiché « Repos terminé » avant que le minuteur disparaisse.
    private static let lingerSeconds = 8.0

    /// (Re)lance le repos. Appelé à chaque série validée : une nouvelle série repart de zéro.
    func start(seconds: Int) {
        let seconds = max(1, seconds)
        finished = false
        total = seconds
        endDate = Date().addingTimeInterval(Double(seconds))
        schedule()
    }

    /// Ajoute du temps (« +30 »). Si le repos était fini, repart de ce temps seulement.
    func add(_ s: Int) {
        guard let endDate, !finished else { start(seconds: s); return }
        self.endDate = endDate.addingTimeInterval(Double(s))
        total += s
        schedule()
    }

    func stop() {
        endTask?.cancel()
        endTask = nil
        endDate = nil
        finished = false
        total = 0
        Self.cancelNotification()
    }

    // MARK: Fin du repos

    private func schedule() {
        guard let endDate else { return }
        endTask?.cancel()
        Self.requestAuthorization()
        Self.scheduleNotification(at: endDate)
        endTask = Task { [weak self] in
            // Dort jusqu'à l'heure de fin ; si l'appli était suspendue, se réveille au retour.
            while !Task.isCancelled {
                let wait = endDate.timeIntervalSinceNow
                if wait <= 0 { break }
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            self?.end()
            try? await Task.sleep(for: .seconds(Self.lingerSeconds))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    private func end() {
        finished = true
        guard let endDate else { return }
        let action = RestEnd.decide(now: Date(), endDate: endDate,
                                    isActive: UIApplication.shared.applicationState == .active)
        // En arrière-plan, la notification doit rester programmée pour partir.
        if action.cancelNotification { Self.cancelNotification() }
        guard action.signal else { return }
        finishCount += 1
        AudioServicesPlaySystemSound(1005)
        AccessibilityNotification.Announcement("Repos terminé, série suivante.").post()
    }

    // MARK: Notification locale

    private static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func scheduleNotification(at end: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        let content = UNMutableNotificationContent()
        content.title = "Repos terminé"
        content.body = "C'est reparti !"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow),
                                                        repeats: false)
        center.add(UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger))
    }

    private static func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
    }
}

/// Au premier plan, la bannière n'est pas affichée (la vibration et le son de l'appli s'en chargent).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }
}

// MARK: - Vue

/// Anneau qui se vide, temps restant, « +30 » et « × » (comme le minuteur du web).
struct RestTimer: View {
    let model: RestTimerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let end = model.endDate {
            // Les ticks tombent pile sur l'heure de fin : le chiffre change au bon moment.
            TimelineView(.periodic(from: end, by: 1)) { context in
                content(left: model.remaining(at: context.date))
            }
        }
    }

    private func content(left: Int) -> some View {
        let done = model.finished || left == 0
        let fraction = model.total > 0 ? Double(left) / Double(model.total) : 0
        // Une pulsation par seconde sur les 3 dernières (et une à la fin) ; 0 = pas de pulsation.
        let pulse = (!model.finished && left <= 3) ? left + 1 : 0
        return HStack(spacing: 6) {
            HStack(spacing: 8) {
                ring(fraction: fraction, done: done)
                Text(done ? "Repos fini" : Self.format(left))
                    .font(Theme.font(done ? .subheadline : .title3, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(done ? Theme.success : Theme.ink)
            }
            .keyframeAnimator(initialValue: Pulse(), trigger: pulse) { view, p in
                view.scaleEffect(p.scale).opacity(p.opacity)
            } keyframes: { _ in
                // Mouvement réduit : simple fondu au lieu du gonflement.
                KeyframeTrack(\.scale) {
                    CubicKeyframe(reduceMotion ? 1 : 1.08, duration: 0.14)
                    CubicKeyframe(1, duration: 0.2)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(reduceMotion ? 0.55 : 1, duration: 0.14)
                    CubicKeyframe(1, duration: 0.2)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            Button { model.add(30) } label: {
                Text("+30")
                    .font(Theme.font(.subheadline, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: Theme.minTouch, minHeight: Theme.minTouch)
                    .background(Capsule().fill(Theme.ink.opacity(0.08)))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Ajouter 30 secondes")
            Button { model.stop() } label: {
                AppIcon.close.image
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .background(Circle().fill(Theme.ink.opacity(0.08)))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Arrêter le minuteur")
        }
        .frame(minHeight: 56)
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color.white.opacity(0.8)))
        // Garde sa largeur : c'est « Terminer » qui se resserre, pas le temps restant.
        .fixedSize(horizontal: true, vertical: false)
        .sensoryFeedback(.warning, trigger: model.finishCount)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(done ? "Repos terminé" : "Repos, \(Self.spoken(left)) restantes")
        .onChange(of: left) { _, now in
            if now == 10 && !model.finished {
                AccessibilityNotification.Announcement("Plus que 10 secondes de repos.").post()
            }
        }
    }

    private func ring(fraction: Double, done: Bool) -> some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: done ? 1 : fraction)
                .stroke(done ? Theme.success : Theme.profile1, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if done { AppIcon.check.image.font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.success) }
        }
        .frame(width: 34, height: 34)
    }

    private struct Pulse { var scale = 1.0; var opacity = 1.0 }

    static func format(_ s: Int) -> String { "\(s / 60):" + String(format: "%02d", s % 60) }

    static func spoken(_ s: Int) -> String {
        s >= 60 ? "\(s / 60) minute\(s / 60 > 1 ? "s" : "") \(s % 60) secondes" : "\(s) secondes"
    }
}
