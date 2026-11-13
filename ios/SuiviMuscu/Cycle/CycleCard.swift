import SwiftUI
import SuiviCore

/// Accueil : la prochaine séance du cycle, à lancer d'un appui, à deux ou seul.
/// Même bandeau foncé que « Prochaine séance », en plus haut. L'accueil ne l'affiche que si
/// `CyclePlanner.offersCycle` est vrai et que le cycle n'est pas vide.
struct CycleCard: View {
    /// L'heure de l'accueil (relue au retour au premier plan) : « aujourd'hui » vient d'elle.
    let now: Date
    var zoom: Namespace.ID? = nil
    let onOpenSession: (SessionRoute) -> Void
    let onEditCycle: () -> Void
    /// Au moment de l'appui, l'accueil n'était plus à jour (j'ai déjà une séance aujourd'hui) :
    /// il relit l'heure et se redessine.
    let onOutdated: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Séance type choisie par « Une autre séance », pour cette fois seulement (`nil` = la suivante).
    @State private var pickedId: String?
    @State private var showPicker = false
    /// « Modifier le cycle » touché dans la feuille : on l'ouvre une fois la feuille fermée.
    @State private var editAfterPicker = false
    @State private var visible = false

    var body: some View {
        let cycle = store.cycle
        let me = store.me
        let next = CyclePlanner.next(cycle, sessions: store.sessions, ownerId: me.id)
        if let next {
            let template = cycle.templates.first { $0.id == pickedId } ?? next
            card(template: template, next: next, cycle: cycle)
                .onChange(of: next.id) { _, _ in pickedId = nil }
                .onChange(of: cycle) { _, _ in pickedId = nil }
                .onChange(of: me.id) { _, _ in pickedId = nil }
        }
    }

    // MARK: Carte

    private func card(template: CycleTemplate, next: CycleTemplate, cycle: Cycle) -> some View {
        let today = Dates.isoDate(now)
        let partner = store.partner
        let partnerFree = CyclePlanner.partnerIsFree(sessions: store.sessions, partnerId: partner.id,
                                                     today: today, now: now)
        let count = Self.availableCount(template, byId: store.exerciseById)
        let last = CyclePlanner.last(cycle, sessions: store.sessions, ownerId: store.me.id)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Prochaine séance du cycle")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .opacity(0.75)
                Text(template.title)
                    .font(Theme.font(.title2, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .motion(Motion.spring, value: template.id)
                    .accessibilityAddTraits(.isHeader)
                if count == 0 {
                    emptyMessage
                } else {
                    Text(Self.detail(count: count, after: last?.title))
                        .font(Theme.font(.subheadline))
                        .opacity(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                if partnerFree {
                    primaryButton("Commencer avec \(partner.name)", template: template, target: .both,
                                  enabled: count > 0)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { secondaryButtons(template: template, enabled: count > 0) }
                        VStack(spacing: 8) { secondaryButtons(template: template, enabled: count > 0) }
                    }
                } else {
                    primaryButton("Commencer seul", template: template, target: .me, enabled: count > 0)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { busyLine(partner); otherButton.fixedSize() }
                        VStack(alignment: .leading, spacing: 8) { busyLine(partner); otherButton }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).fill(Theme.ink))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .zoomSource("cycle", in: zoom)
        .opacity(visible ? 1 : 0)
        .offset(y: visible || reduceMotion ? 0 : 12)
        .onAppear {
            withAnimation(reduceMotion ? Motion.reduced : Motion.stagger(2)) { visible = true }
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showPicker, onDismiss: {
            if editAfterPicker {
                editAfterPicker = false
                onEditCycle()
            }
        }) {
            CyclePickerSheet(cycle: cycle, nextId: next.id, selection: $pickedId,
                             onEditCycle: { editAfterPicker = true })
        }
    }

    /// Point de vigilance 5 : plus aucune machine visible dans cette séance type.
    private var emptyMessage: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            AppIcon.warning.image
                .font(Theme.icon(14, weight: .semibold))
                .foregroundStyle(Theme.warningOnInk)
                .accessibilityHidden(true)
            Text("Cette séance n’a plus d’exercice. Modifie le cycle.")
                .font(Theme.font(.subheadline, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    private func busyLine(_ partner: Profile) -> some View {
        Text("\(partner.name) a déjà une séance aujourd’hui.")
            .font(Theme.font(.footnote))
            .opacity(0.8)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }

    // MARK: Boutons

    private func primaryButton(_ title: String, template: CycleTemplate, target: PlanTarget,
                               enabled: Bool) -> some View {
        Button { start(template, target: target) } label: {
            HStack(spacing: 8) {
                AppIcon.play.image
                    .font(Theme.icon(14, weight: .bold))
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .font(Theme.font(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Theme.orange))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    @ViewBuilder private func secondaryButtons(template: CycleTemplate, enabled: Bool) -> some View {
        Button { start(template, target: .me) } label: { secondaryLabel("Commencer seul") }
            .buttonStyle(PressableStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        otherButton
    }

    private var otherButton: some View {
        Button { showPicker = true } label: { secondaryLabel("Une autre séance") }
            .buttonStyle(PressableStyle())
    }

    private func secondaryLabel(_ title: String) -> some View {
        Text(title)
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .background(Capsule().fill(Color.white.opacity(0.14)))
            .contentShape(Capsule())
    }

    // MARK: Création

    /// Crée la ou les séances du jour pour la séance type, puis ouvre la mienne. Tout est revérifié
    /// à l'heure de l'appui : si j'ai déjà une séance aujourd'hui (un double appui, ou l'accueil
    /// resté d'hier), rien n'est créé et l'accueil se met à jour ; si l'autre n'est plus libre, seule
    /// la mienne est créée. Avant, les séances du cycle jamais commencées des jours passés de
    /// chacun sont retirées, pour ne pas s'entasser dans le Planning.
    private func start(_ template: CycleTemplate, target: PlanTarget) {
        let now = AppClock.now()
        let today = Dates.isoDate(now)
        let sessions = store.sessions
        let me = store.me
        let partner = store.partner
        guard CyclePlanner.offersCycle(sessions: sessions, ownerId: me.id, today: today, now: now) else {
            onOutdated()
            return
        }
        var target = target
        if target == .both,
           !CyclePlanner.partnerIsFree(sessions: sessions, partnerId: partner.id, today: today, now: now) {
            target = .me
        }
        let created = CyclePlanner.sessions(for: template, target: target, me: me, partner: partner,
                                            date: today, sessions: sessions, byId: store.exerciseById, now: now)
        // Plus aucune machine : la carte le dit déjà, rien n'est créé.
        guard let mine = created.first(where: { $0.ownerId == me.id }) else { return }
        let stale = CyclePlanner.staleSessions(sessions, ownerIds: created.map(\.ownerId), today: today)
        for s in stale { store.deleteSession(id: s.id) }
        for s in created { store.saveSession(s) }
        // Échec d'écriture : le bandeau rouge le signale, on reste sur l'accueil.
        guard store.lastSaveError == nil else { return }
        onOpenSession(SessionRoute(id: mine.id, source: "cycle"))
    }

    // MARK: Textes

    /// Exercices de la séance type encore disponibles (machines visibles).
    static func availableCount(_ template: CycleTemplate, byId: [String: Exercise]) -> Int {
        template.items.filter { byId[$0.exerciseId] != nil }.count
    }

    /// « 7 exercices », « 1 exercice », « Aucun exercice disponible » (machines toutes masquées).
    static func exercises(_ n: Int) -> String {
        n == 0 ? "Aucun exercice disponible" : n > 1 ? "\(n) exercices" : "\(n) exercice"
    }

    /// « 7 exercices · après Épaules + dos ».
    static func detail(count: Int, after last: String?) -> String {
        guard let last else { return exercises(count) }
        return "\(exercises(count)) · après \(last)"
    }
}
