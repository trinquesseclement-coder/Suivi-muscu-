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
            Text("Bientôt").font(Theme.font(.title2, weight: .semibold)).foregroundStyle(.white)
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
        if let i = args.firstIndex(of: "-open-session"), i + 1 < args.count {
            path = [SessionRoute(id: args[i + 1], source: "launch")]
        } else if args.contains("-open-next"),
                  let s = HomeView.nextSession(store.sessions, meId: store.meId, now: Date()) {
            path = [SessionRoute(id: s.id, source: "next")]
        }
        #endif
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(.home)
            tabButton(.planning)
            addButton
            tabButton(.load)
            tabButton(.machines)
        }
        .padding(4)
        .background(Capsule().fill(Theme.glass))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func tabButton(_ t: AppTab) -> some View {
        let active = tab == t
        return Button {
            if tab != t { bounce += 1 }
            withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { tab = t }
        } label: {
            HStack(spacing: 4) {
                t.icon.image
                    .font(.system(size: 20, weight: .medium))
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: active && !reduceMotion && bounce > 0)
                if active {
                    Text(t.label).font(Theme.font(.subheadline, weight: .medium))
                        .lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, active ? 12 : 0)
            .frame(minWidth: Theme.minTouch, minHeight: Theme.minTouch)
            .foregroundStyle(active ? Color.white : Theme.ink)
            .background(Capsule().fill(active ? Theme.ink : Color.white.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(active ? 0 : 0.7), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var addButton: some View {
        Button { startFreeSession(source: "add") } label: {
            AppIcon.add.image
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .background(Circle().fill(Theme.orange))
        }
        .buttonStyle(.plain)
        .zoomSource("add", in: zoom)
        .accessibilityLabel("Séance libre")
    }
}
