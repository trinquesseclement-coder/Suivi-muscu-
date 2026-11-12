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
    @State private var path = NavigationPath()
    /// Une date de la semaine affichée par le Planning (aujourd'hui au départ).
    @State private var planningWeek = Dates.isoDate(Date())
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Theme.background.ignoresSafeArea()
                content
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { route in
                SettingsView(focus: route.focus)
                    .environment(\.openCycleTemplate, OpenCycleTemplateAction { id in
                        // Depuis les Réglages seulement (une seule fois, même sur un double appui).
                        guard path.count == 1 else { return }
                        path.append(CycleRoute(templateId: id))
                    })
            }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionView(sessionId: route.id, fresh: route.fresh,
                            onReplace: { id in path = NavigationPath([SessionRoute(id: id, source: route.source)]) },
                            onEditPlan: { id in path.append(PlanRoute(sessionId: id)) })
                .navigationTransition(.zoom(sourceID: route.source, in: zoom))
            }
            .navigationDestination(for: PlanRoute.self, destination: planDestination)
            .navigationDestination(for: CycleRoute.self) { CycleTemplateEditor(templateId: $0.templateId) }
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
                     onAvatar: { openSettings() },
                     onEditCycle: { openSettings(focus: .cycle) })
        case .planning:
            PlanningView(week: $planningWeek, zoom: zoom,
                         onOpenSession: { id in open(SessionRoute(id: id, source: "planning-\(id)")) },
                         onPlan: { date in path.append(PlanRoute(date: date)) })
        case .load:
            LoadView()
        case .machines:
            MachinesView()
        }
    }

    /// Une séance qui n'est plus modifiable (commencée entre-temps) s'ouvre normalement.
    @ViewBuilder private func planDestination(_ route: PlanRoute) -> some View {
        if let id = route.sessionId, let s = store.session(id), !Rules.isEditablePlan(s, meId: store.meId) {
            SessionView(sessionId: id)
        } else {
            PlanEditorView(sessionId: route.sessionId, date: route.date) { date in
                // Retour au Planning, sur la semaine de la date choisie, d'où qu'on vienne.
                planningWeek = date
                tab = .planning
                path = NavigationPath()
            }
        }
    }

    /// Les Réglages s'ouvrent depuis l'accueil seulement : un double appui sur la photo (ou un appui
    /// pendant l'animation) n'empile pas un second écran.
    private func openSettings(focus: SettingsFocus? = nil) {
        guard path.isEmpty else { return }
        path.append(SettingsRoute(focus: focus))
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
    /// `-open-session <id>` ouvre une séance précise, `-open-plan <AAAA-MM-JJ>` et
    /// `-open-plan-session <id>` l'éditeur de séance planifiée, `-import-file <chemin>` ouvre les Réglages et lance l'import de ce fichier,
    /// `-open-cycle` les Réglages sur la carte « Mon cycle », `-open-cycle-template <id>` (ou `new`)
    /// l'éditeur d'une séance type par-dessus, `-open-tab planning` (ou `load`, `machines`) choisit l'onglet
    /// et `-planning-week <AAAA-MM-JJ>` la semaine du Planning.
    private func openFromLaunchArguments() {
        #if DEBUG
        guard path.isEmpty else { return }
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-open-tab"), i + 1 < args.count,
           let t = AppTab.allCases.first(where: { "\($0)" == args[i + 1] }) {
            tab = t
        }
        if let i = args.firstIndex(of: "-planning-week"), i + 1 < args.count {
            planningWeek = args[i + 1]
        }
        prepareDemoForCycle(args)
        if args.contains("-open-settings") || args.contains("-import-file") { openSettings(); return }
        if args.contains("-open-cycle") { openSettings(focus: .cycle); return }
        if let i = args.firstIndex(of: "-open-cycle-template"), i + 1 < args.count {
            path = NavigationPath([SettingsRoute(focus: .cycle)])
            path.append(CycleRoute(templateId: args[i + 1] == "new" ? nil : args[i + 1]))
            return
        }
        if let i = args.firstIndex(of: "-open-session"), i + 1 < args.count {
            path = NavigationPath([SessionRoute(id: args[i + 1], source: "launch")])
        } else if args.contains("-open-next"),
                  let s = HomeView.nextSession(store.sessions, meId: store.meId, now: Date()) {
            path = NavigationPath([SessionRoute(id: s.id, source: "next")])
        } else if let i = args.firstIndex(of: "-open-plan"), i + 1 < args.count {
            path.append(PlanRoute(date: args[i + 1]))
        } else if let i = args.firstIndex(of: "-open-plan-session"), i + 1 < args.count {
            path.append(PlanRoute(sessionId: args[i + 1]))
        }
        #endif
    }

    #if DEBUG
    /// Mise au point de la carte du cycle, sur les données de démo seulement : `-demo-nobody-live`
    /// supprime les séances en cours (les deux sont libres), `-demo-hide-cycle <id>` masque les
    /// machines d'une séance type (message « plus d'exercice »).
    private func prepareDemoForCycle(_ args: [String]) {
        guard args.contains("-demo") else { return }
        let now = Date()
        if args.contains("-demo-nobody-live") {
            for s in store.sessions where Rules.isLive(s, now: now) { store.deleteSession(id: s.id) }
        }
        if let i = args.firstIndex(of: "-demo-hide-cycle"), i + 1 < args.count,
           let template = store.cycle.templates.first(where: { $0.id == args[i + 1] }) {
            for item in template.items {
                guard var ex = store.exerciseById[item.exerciseId] else { continue }
                ex.deleted = true
                store.saveExercise(ex)
            }
        }
    }
    #endif

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
