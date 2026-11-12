import SwiftUI
import SuiviCore

/// Planning de la semaine (copie de `appli/src/pages/Planning.tsx`, maquette `03-planning.jpg`).
struct PlanningView: View {
    /// Une date (AAAA-MM-JJ) de la semaine affichée ; gardée par `RootView` pour y revenir.
    @Binding var week: String
    /// Espace de noms de la transition « zoom » vers la séance.
    var zoom: Namespace.ID? = nil
    var onOpenSession: (String) -> Void
    var onPlan: (_ date: String) -> Void
    var onEditPlan: (_ sessionId: String) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Sens du dernier changement de semaine : +1 vers l'avant, -1 vers l'arrière.
    @State private var direction = 1
    @ScaledMetric(relativeTo: .subheadline) private var dotSize: CGFloat = 10

    var body: some View {
        let now = Date()
        let today = Dates.isoDate(now)
        let days = PlanningWeek.days(containing: week)
        let isCurrent = days[0] == Dates.weekStart(today)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(days)
                navigation(isCurrent: isCurrent, today: today)
                legend
                // Les lignes entrent du côté où l'on va ; l'ancienne semaine s'efface sur place.
                ZStack(alignment: .top) {
                    DayRows(days: days, today: today, now: now, zoom: zoom,
                            onSession: tap, onPlan: onPlan)
                        .id(days[0])
                        .transition(.asymmetric(insertion: insertion, removal: .opacity))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                .foregroundStyle(Theme.ink)
                // Le verre en fond seul : son ombre ne doit pas déborder sur les séances ni les chiffres.
                .background { Color.clear.glassCard() }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        // Balayage horizontal pour changer de semaine, sans gêner le défilement vertical.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > 2 * abs(dy) else { return }
                go(dx < 0 ? 1 : -1)
            }
        )
        .sensoryFeedback(.selection, trigger: days[0])
    }

    private var insertion: AnyTransition {
        reduceMotion ? .opacity : .offset(x: CGFloat(direction) * 48).combined(with: .opacity)
    }

    private func go(_ n: Int) {
        direction = n
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) {
            week = Dates.addDays(Dates.weekStart(week), 7 * n)
        }
    }

    private func goToday(_ today: String) {
        direction = today < week ? -1 : 1
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { week = today }
    }

    /// Séance prévue que j'ai créée et pas encore commencée : l'éditeur ; le reste s'ouvre normalement.
    private func tap(_ s: Session) {
        if Rules.isEditablePlan(s, meId: store.meId) {
            onEditPlan(s.id)
        } else {
            onOpenSession(s.id)
        }
    }

    private func header(_ days: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Planning")
                .font(Theme.font(.title, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("Semaine du \(Format.dayMonth(days[0])) au \(Format.dayMonth(days[6])) · KOMEX")
                .font(Theme.font(.subheadline))
                .opacity(0.8)
        }
        .foregroundStyle(Theme.onBackground)
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    /// ‹ « Cette semaine » › : le bouton du milieu ne sert à rien sur la semaine en cours.
    private func navigation(isCurrent: Bool, today: String) -> some View {
        HStack(spacing: 10) {
            roundButton(.back, label: "Semaine précédente") { go(-1) }
            Button { goToday(today) } label: {
                Text("Cette semaine")
                    .font(Theme.font(.body, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isCurrent ? Theme.onBackground.opacity(0.7) : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                    .background(Capsule().fill(isCurrent ? Color.white.opacity(0.16) : Theme.glass))
                    .overlay(Capsule().strokeBorder(isCurrent ? Color.white.opacity(0.2) : Theme.glassBorder,
                                                    lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(isCurrent)
            .accessibilityHint(isCurrent ? "" : "Revenir à la semaine en cours")
            roundButton(.forward, label: "Semaine suivante") { go(1) }
        }
    }

    private func roundButton(_ icon: AppIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon.image
                .font(Theme.icon(17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .background(Circle().fill(Theme.glass))
                .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    /// Une pastille par profil, puis ce que veulent dire les pointillés.
    private var legend: some View {
        FlowLayout(spacing: 14) {
            ForEach(store.profiles) { p in
                HStack(spacing: 6) {
                    Circle().fill(Theme.color(for: p)).frame(width: dotSize, height: dotSize)
                    Text(p.id == store.meId ? "\(p.name) (toi)" : p.name)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Pointillés = prévue")
        }
        .font(Theme.font(.subheadline, weight: .medium))
        .foregroundStyle(Theme.onBackground)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
}

/// Les sept jours de la carte, séparés par un filet.
private struct DayRows: View {
    let days: [String]
    let today: String
    let now: Date
    let zoom: Namespace.ID?
    let onSession: (Session) -> Void
    let onPlan: (String) -> Void

    @Environment(AppStore.self) private var store
    @ScaledMetric(relativeTo: .title3) private var labelWidth: CGFloat = 48
    @ScaledMetric(relativeTo: .title3) private var todaySize: CGFloat = 36

    var body: some View {
        let profiles = store.profiles
        let all = store.sessions
        let byId = store.exerciseAnyById
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { i, d in
                if i > 0 { Rectangle().fill(Theme.ink.opacity(0.1)).frame(height: 1) }
                let list = PlanningWeek.sessions(on: d, in: all, profiles: profiles)
                if list.isEmpty && d < today {
                    // Jour passé sans séance : une seule ligne discrète, pas de grand vide.
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        compactLabel(d)
                        Text("—")
                            .font(Theme.font(.subheadline))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(Theme.ink2)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Format.day(d, today: today)), aucune séance")
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        dayLabel(d)
                        VStack(spacing: 8) {
                            ForEach(list) { s in
                                let owner = profiles.first { $0.id == s.ownerId }
                                SessionChip(session: s, owner: owner, live: Rules.isLive(s, now: now),
                                            help: PlanningWeek.helpCount(s, profiles: profiles, byId: byId),
                                            editable: Rules.isEditablePlan(s, meId: store.meId)) {
                                    onSession(s)
                                }
                                .zoomSource("planning-\(s.id)", in: zoom)
                            }
                            if d >= today { planButton(d) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    /// « JEU » au-dessus de « 12 » ; aujourd'hui dans une pastille foncée.
    private func dayLabel(_ d: String) -> some View {
        let isToday = d == today
        return VStack(spacing: 2) {
            Text(Format.weekdayShort(d).uppercased())
                .font(Theme.font(.caption2, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            Text(Format.dayOfMonth(d))
                .font(Theme.font(isToday ? .callout : .title3, weight: isToday ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.white : Theme.ink)
                .frame(width: isToday ? todaySize : nil, height: isToday ? todaySize : nil)
                .background { if isToday { Circle().fill(Theme.ink) } }
        }
        .fixedSize()
        .frame(width: labelWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.day(d, today: today))
        .accessibilityAddTraits(.isHeader)
    }

    /// « LUN 9 » sur une ligne, centré dans la même colonne que les jours pleins.
    private func compactLabel(_ d: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Format.weekdayShort(d).uppercased())
                .font(Theme.font(.caption2, weight: .semibold))
            Text(Format.dayOfMonth(d))
                .font(Theme.font(.subheadline, weight: .semibold))
                .monospacedDigit()
        }
        .lineLimit(1)
        .fixedSize()
        .frame(width: labelWidth)
    }

    private func planButton(_ d: String) -> some View {
        Button { onPlan(d) } label: {
            HStack(spacing: 6) {
                AppIcon.add.image.font(Theme.icon(15, weight: .semibold))
                Text("Planifier")
            }
            .font(Theme.font(.body, weight: .medium))
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Planifier une séance, \(Format.day(d, today: today))")
    }
}

/// Une séance du jour : barre de la couleur du propriétaire, titre, « Jules · 3 exos · faite ».
private struct SessionChip: View {
    let session: Session
    let owner: Profile?
    let live: Bool
    let help: Int
    let editable: Bool
    let action: () -> Void

    private var planned: Bool { session.status == .planned }

    private var detail: String {
        let n = session.items.count
        var text = "\(owner?.name ?? "?") · \(n) exo\(n > 1 ? "s" : "")"
        if !planned { text += live ? " · en cours" : " · faite" }
        return text
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
        Button(action: action) {
            HStack(spacing: 12) {
                Capsule()
                    .fill(owner.map { Theme.color(for: $0) } ?? Theme.ink2)
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Text(detail)
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if help > 0 {
                    Pill(text: "\(help)", icon: .help, fill: Theme.profile2.opacity(0.16))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(shape.fill(Color.white.opacity(planned ? 0.45 : 0.7)))
            .overlay {
                if planned {
                    shape.strokeBorder(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                } else {
                    shape.strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(editable ? "Modifier la séance prévue" : "Ouvrir la séance")
    }

    private var accessibilityText: String {
        var parts = [session.title, detail.replacingOccurrences(of: " · ", with: ", ")]
        if planned { parts.append("prévue") }
        if help > 0 { parts.append("\(help) exercice\(help > 1 ? "s" : "") avec aide") }
        return parts.joined(separator: ", ")
    }
}
