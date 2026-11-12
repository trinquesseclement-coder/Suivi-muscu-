import SwiftUI
import SuiviCore

/// Accueil : tableau de bord B (maquette `dashboard-v3.html`).
struct HomeView: View {
    /// Espace de noms de la transition « zoom » vers la séance.
    var zoom: Namespace.ID? = nil
    /// Ouvre une séance, avec la carte d'où elle part.
    var onOpenSession: (SessionRoute) -> Void = { _ in }
    /// Lance une séance libre.
    var onFreeSession: () -> Void = {}
    /// Ouvre les Réglages (tâche 10).
    var onAvatar: () -> Void = {}

    @Environment(AppStore.self) private var store

    var body: some View {
        let now = Date()
        let today = Dates.isoDate(now)
        let me = store.me
        let partner = store.partner
        let sessions = store.sessions

        // Aucune séance du tout (première ouverture) : une carte d'accueil remplace le fil vide.
        let firstRun = sessions.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(me: me, today: today)

                HStack(alignment: .top, spacing: 12) {
                    WeekRingCard(profile: me,
                                 summary: Stats.week(sessions, owner: me, containing: today, now: now),
                                 isMe: true, appearDelay: 0)
                    WeekRingCard(profile: partner,
                                 summary: Stats.week(sessions, owner: partner, containing: today, now: now),
                                 isMe: false, appearDelay: 1)
                }

                let together = Stats.together(sessions, a: me.id, b: partner.id, containing: today, now: now)
                TogetherCard(days: together.days, minutes: together.minutes)

                if firstRun {
                    WelcomeCard(zoom: zoom, onStart: onFreeSession)
                } else {
                    // Comme le web : la séance en cours de l'autre (sa séance prévue de demain passe avant
                    // dans le tri par date, d'où la recherche directe).
                    if let live = sessions.first(where: { $0.ownerId == partner.id && Rules.isLive($0, now: now) }) {
                        PartnerLiveCard(partner: partner, session: live) {
                            onOpenSession(SessionRoute(id: live.id, source: "partner"))
                        }
                        .zoomSource("partner", in: zoom)
                    }

                    // Ma séance en cours d'abord (pour y revenir après avoir quitté l'appli), sinon la prochaine prévue.
                    let next = Self.nextSession(sessions, meId: me.id, now: now)
                    NextSessionCard(session: next,
                                    live: next.map { Rules.isLive($0, now: now) } ?? false,
                                    zoom: zoom,
                                    onOpen: { if let next { onOpenSession(SessionRoute(id: next.id, source: "next")) } },
                                    onFree: onFreeSession)

                    SessionFeed(sessions: feed(sessions, today: today), zoom: zoom) { s in
                        onOpenSession(SessionRoute(id: s.id, source: "feed-\(s.id)"))
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    /// En-tête : le logo de la salle en surtitre, « Cette semaine » en grand, la photo à droite.
    private func header(me: Profile, today: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Image("KomexLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                    .accessibilityLabel("KOMEX")
                Text("Cette semaine")
                    .font(Theme.font(.title, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(Format.weekLabel(containing: today))
                    .font(Theme.font(.subheadline))
                    .opacity(0.8)
            }
            .foregroundStyle(Theme.onBackground)
            Spacer(minLength: 8)
            Button(action: onAvatar) {
                ProfileAvatar(profile: me, size: 46, ring: true)
                    .frame(width: 52, height: 52)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Réglages et profil")
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    /// Ma séance en cours, sinon ma prochaine séance prévue (aujourd'hui ou plus tard).
    static func nextSession(_ sessions: [Session], meId: String, now: Date) -> Session? {
        if let live = sessions.first(where: { $0.ownerId == meId && Rules.isLive($0, now: now) }) {
            return live
        }
        let today = Dates.isoDate(now)
        return sessions
            .filter { $0.ownerId == meId && $0.status == .planned && $0.date >= today }
            .min { $0.date < $1.date }
    }

    /// Séances terminées des 60 derniers jours, 8 au plus (comme le web).
    private func feed(_ sessions: [Session], today: String) -> [Session] {
        let limit = Dates.addDays(today, -60)
        return Array(sessions.filter { $0.status == .done && $0.date >= limit }.prefix(8))
    }
}
