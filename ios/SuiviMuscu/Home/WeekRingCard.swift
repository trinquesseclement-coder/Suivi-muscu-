import SwiftUI
import SuiviCore

/// Carte d'une personne : anneau « séances / objectif » et temps de la semaine.
struct WeekRingCard: View {
    let profile: Profile
    let summary: Stats.WeekSummary
    let isMe: Bool
    /// Rang de la carte (0, 1…) pour décaler l'apparition.
    let appearDelay: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Valeurs affichées, animées depuis 0 à chaque apparition.
    @State private var shownSessions = 0
    @State private var shownMinutes = 0
    @State private var progress: Double = 0
    @State private var visible = false
    @State private var celebrate = 0

    private var reached: Bool { summary.goal > 0 && summary.sessions >= summary.goal }
    private var target: Double {
        summary.goal > 0 ? min(1, Double(summary.sessions) / Double(summary.goal)) : 0
    }
    private var ringColor: Color { reached ? Theme.success : Theme.color(for: profile) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Theme.color(for: profile)).frame(width: 9, height: 9)
                Text(profile.name)
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            ring
                .phaseAnimator([1.0, 1.06, 1.0], trigger: celebrate) { view, scale in
                    view.scaleEffect(reduceMotion ? 1 : scale)
                } animation: { _ in .spring(duration: 0.15, bounce: 0.3) }

            HStack(spacing: 5) {
                AppIcon.time.image
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                Text(Stats.formatHours(shownMinutes))
                    .font(Theme.font(.title2, weight: .bold))
                    .contentTransition(.numericText(value: Double(shownMinutes)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassCard()
        .opacity(visible ? 1 : 0)
        .offset(y: visible || reduceMotion ? 0 : 12)
        .sensoryFeedback(.success, trigger: celebrate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onAppear { play() }
        .onDisappear { reset() }
        .onChange(of: summary) { _, _ in play() }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.1), lineWidth: 11)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(shownSessions)")
                    .font(Theme.font(.largeTitle, weight: .bold))
                    .contentTransition(.numericText(value: Double(shownSessions)))
                    .monospacedDigit()
                Text("sur \(summary.goal)")
                    .font(Theme.font(.caption, weight: .medium))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .frame(width: 96, height: 96)
        .padding(.vertical, 2)
    }

    private var accessibilityText: String {
        let who = isMe ? "\(profile.name), toi" : profile.name
        let s = summary.sessions > 1 ? "séances" : "séance"
        return "\(who) : \(summary.sessions) \(s) sur \(summary.goal) cette semaine, \(Stats.formatHours(summary.minutes))"
            + (reached ? ", objectif atteint" : "")
    }

    private func play() {
        let delay = 0.06 * Double(appearDelay)
        if reduceMotion {
            // « Réduire les animations » : valeurs posées d'un coup, la carte apparaît en fondu.
            progress = target
            shownSessions = summary.sessions
            shownMinutes = summary.minutes
            withAnimation(Motion.reduced.delay(delay)) { visible = true }
        } else {
            withAnimation(Motion.stagger(appearDelay)) {
                visible = true
                progress = target
                shownSessions = summary.sessions
                shownMinutes = summary.minutes
            }
        }
        celebrateIfNeeded(after: delay)
    }

    private func reset() {
        visible = false
        progress = 0
        shownSessions = 0
        shownMinutes = 0
    }

    /// Une seule fête par semaine et par personne, mémorisée dans UserDefaults.
    private func celebrateIfNeeded(after delay: Double) {
        guard reached else { return }
        let key = "goalCelebrated.\(profile.id)"
        let week = Dates.weekStart(Dates.isoDate(Date()))
        guard UserDefaults.standard.string(forKey: key) != week else { return }
        UserDefaults.standard.set(week, forKey: key)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay + 0.35))
            celebrate += 1
        }
    }
}
