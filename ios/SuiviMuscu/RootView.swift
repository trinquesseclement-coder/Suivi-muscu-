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

    /// Appelé par le bouton « + » (séance libre), branché à la tâche 8.
    var onAdd: () -> Void = {}
    /// Ouvre une séance par son id, branché à la tâche 8.
    var onOpenSession: (String) -> Void = { _ in }
    /// Ouvre les Réglages depuis l'avatar, branché à la tâche 10.
    var onSettings: () -> Void = {}

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.lastSaveError != nil {
                Text("Enregistrement impossible sur le téléphone")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .sensoryFeedback(.selection, trigger: tab)
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .home:
            HomeView(onOpenSession: onOpenSession, onFreeSession: onAdd, onAvatar: onSettings)
        case .planning, .load, .machines:
            Text("Bientôt").font(Theme.font(.title2, weight: .semibold)).foregroundStyle(.white)
        }
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
        Button(action: onAdd) {
            AppIcon.add.image
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .background(Circle().fill(Theme.orange))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Séance libre")
    }
}
