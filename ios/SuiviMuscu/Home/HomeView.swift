import SwiftUI
import SuiviCore

/// Accueil : tableau de bord B (maquette `dashboard-v3.html`).
struct HomeView: View {
    /// Ouvre une séance par son id (tâche 8).
    var onOpenSession: (String) -> Void = { _ in }
    /// Lance une séance libre (tâche 8).
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

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header(me: me)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cette semaine")
                        .font(Theme.font(.title3, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(Format.weekLabel(containing: today))
                        .font(Theme.font(.footnote))
                        .opacity(0.75)
                }
                .foregroundStyle(Color(hex: 0xEEF3F0))
                .padding(.horizontal, 2)

                HStack(alignment: .top, spacing: 10) {
                    WeekRingCard(profile: me,
                                 summary: Stats.week(sessions, owner: me, containing: today, now: now),
                                 isMe: true, appearDelay: 0)
                    WeekRingCard(profile: partner,
                                 summary: Stats.week(sessions, owner: partner, containing: today, now: now),
                                 isMe: false, appearDelay: 1)
                }

                let together = Stats.together(sessions, a: me.id, b: partner.id, containing: today, now: now)
                TogetherCard(days: together.days, minutes: together.minutes)

                // Comme le web : la séance en cours de l'autre (sa séance prévue de demain passe avant
                // dans le tri par date, d'où la recherche directe).
                if let live = sessions.first(where: { $0.ownerId == partner.id && Rules.isLive($0, now: now) }) {
                    PartnerLiveCard(partner: partner, session: live) { onOpenSession(live.id) }
                }

                let next = sessions
                    .filter { $0.ownerId == me.id && $0.status == .planned && $0.date >= today }
                    .min { $0.date < $1.date }
                NextSessionCard(session: next,
                                onOpen: { if let next { onOpenSession(next.id) } },
                                onFree: onFreeSession)

                SessionFeed(sessions: feed(sessions, today: today))
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func header(me: Profile) -> some View {
        HStack {
            Image("KomexLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 26)
                .accessibilityLabel("KOMEX")
            Spacer()
            Button(action: onAvatar) {
                ProfileAvatar(profile: me, size: 40, ring: true)
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Réglages et profil")
        }
    }

    /// Séances terminées des 60 derniers jours, 8 au plus (comme le web).
    private func feed(_ sessions: [Session], today: String) -> [Session] {
        let limit = Dates.addDays(today, -60)
        return Array(sessions.filter { $0.status == .done && $0.date >= limit }.prefix(8))
    }
}
