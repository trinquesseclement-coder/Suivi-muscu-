import SwiftUI
import SuiviCore

enum AppTab: Hashable, CaseIterable {
    case home, planning, load, machines

    var icon: AppIcon {
        switch self {
        case .home: .home
        case .planning: .planning
        case .load: .load
        case .machines: .machines
        }
    }

    var label: String {
        switch self {
        case .home: "Accueil"
        case .planning: "Planning"
        case .load: "Charge"
        case .machines: "Machines"
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: AppTab = .home
    @State private var bounce = 0
    @State private var path: [SessionRoute] = []
    @Namespace private var zoom

    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionView(sessionId: route.id, fresh: route.fresh) { id in
                    path = [SessionRoute(id: id, source: route.source)]
                }
                .navigationTransition(.zoom(sourceID: route.source, in: zoom))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if let problem = store.loadProblem { banner(problem) }
                if store.lastSaveError != nil { banner("Enregistrement impossible sur le téléphone") }
            }
        }
        .sensoryFeedback(.selection, trigger: tab)
        .task { openFromLaunchArguments() }
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.footnote, weight: .semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.red.opacity(0.85))
            .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .home:
            HomeView(zoom: zoom, onOpenSession: open, onFreeSession: { startFreeSession(source: "free") },
                     onAvatar: { showSettings = true })
        case .planning, .load, .machines:
            ComingSoon(tab: tab)
        }
    }

    private func open(_ route: SessionRoute) {
        path.append(route)
    }

    /// « + » ou « Séance libre » : une séance vide pour moi aujourd'hui, ouverte aussitôt.
    private func startFreeSession(source: String) {
        let now = Date()
        let me = store.meId
        let session = Session(id: UUID().uuidString.lowercased(), ownerId: me, createdBy: me,
                              date: Dates.isoDate(now), title: "Séance", status: .planned, items: [],
                              updatedAt: AppStore.timestamp(now))
        store.saveSession(session)
        path.append(SessionRoute(id: session.id, source: source, fresh: true))
    }

    /// Mise au point : `-open-next` ouvre la séance en cours ou la prochaine prévue,
    /// `-open-session <id>` ouvre une séance précise.
    private func openFromLaunchArguments() {
        #if DEBUG
        guard path.isEmpty else { return }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-open-settings") { showSettings = true; return }
        if let i = args.firstIndex(of: "-open-session"), i + 1 < args.count {
            path = [SessionRoute(id: args[i + 1], source: "launch")]
        } else if args.contains("-open-next"),
                  let s = HomeView.nextSession(store.sessions, meId: store.meId, now: Date()) {
            path = [SessionRoute(id: s.id, source: "next")]
        }
        #endif
    }

    /// Barre d'onglets flottante : cinq cases de même largeur, alignées sur les cartes (16 pt de marge),
    /// chaque onglet avec son nom, et le « + » orange au centre.
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.planning)
            addButton.frame(maxWidth: .infinity)
            tabButton(.load)
            tabButton(.machines)
        }
        .padding(5)
        .background(Capsule().fill(Theme.barFill))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 6)
        .background { BottomFade() }
        // Comme la barre d'onglets du système, elle ne grossit pas au-delà des tailles standards.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func tabButton(_ t: AppTab) -> some View {
        let active = tab == t
        return Button {
            if tab != t { bounce += 1 }
            withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { tab = t }
        } label: {
            VStack(spacing: 2) {
                t.icon.image
                    .symbolVariant(active ? .fill : .none)
                    .font(Theme.icon(18, weight: .medium))
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: active && !reduceMotion && bounce > 0)
                Text(t.label)
                    .font(Theme.font(.caption2, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(active ? Color.white : Theme.ink2)
            .background(Capsule().fill(active ? Theme.ink : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var addButton: some View {
        Button { startFreeSession(source: "add") } label: {
            AppIcon.add.image
                .font(Theme.icon(22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.orange))
        }
        .buttonStyle(PressableStyle())
        .zoomSource("add", in: zoom)
        .accessibilityLabel("Séance libre")
    }
}

/// Onglet pas encore construit : dit ce qui arrive, plutôt qu'un écran muet.
private struct ComingSoon: View {
    let tab: AppTab

    private var text: String {
        switch tab {
        case .planning: "Le planning de la semaine arrive : tu pourras préparer une séance pour toi, pour l’autre ou pour vous deux."
        case .load: "Le tableau de charge arrive : tes séances, tes heures et ta progression machine par machine."
        case .machines: "Le catalogue des machines arrive : photos, réglages du siège et corrections."
        case .home: ""
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            tab.icon.image
                .font(Theme.icon(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.white.opacity(0.7)))
            Text(tab.label).font(Theme.font(.title3, weight: .bold))
            Text(text)
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
            Text("Bientôt")
                .font(Theme.font(.caption, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Theme.ink.opacity(0.08)))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}
