import SwiftUI
import SuiviCore

/// Une carte des Réglages à montrer dès l'ouverture.
enum SettingsFocus: Hashable {
    /// « Modifier le cycle », depuis l'accueil.
    case cycle
}

/// Réglages essentiels : profils, séance, cycle, salle (copie de `appli/src/pages/Settings.tsx`).
struct SettingsView: View {
    /// Carte amenée en haut à l'ouverture (`nil` : le haut des Réglages).
    var focus: SettingsFocus? = nil

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rest.seconds") private var restSeconds = 90

    private static let gymMapsURL = URL(string: "https://maps.apple.com/?q=KOMEX%2C%2064B%20rue%20Sully%2C%2021000%20Dijon")!

    /// L'autre profil est replié par défaut : on règle surtout le sien.
    @State private var showPartner = false
    /// La carte demandée n'est amenée qu'une fois (pas au retour de l'éditeur du cycle).
    @State private var focused = false

    var body: some View {
        let me = store.me
        let partner = store.partner
        return ZStack {
            Theme.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        whoCard
                        card("Mon profil") { ProfileEditor(profile: me).id(me.id) }
                        partnerCard(partner)
                        card("Séance") {
                            SettingsStepper(title: "Temps de repos", valueText: Self.restText(restSeconds),
                                            value: $restSeconds, range: 30...180, step: 15)
                        }
                        // Repère 12 pt au-dessus de la carte : amenée en haut, elle ne colle pas au bord.
                        Color.clear.frame(height: 0).padding(.bottom, -12).id(SettingsFocus.cycle)
                        CycleSection()
                        BackupSection()
                        gymCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear {
                    guard let focus, !focused else { return }
                    focused = true
                    proxy.scrollTo(focus, anchor: .top)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // Une ancienne valeur hors bornes (30 à 180 s) est ramenée dans la plage.
        .onAppear { restSeconds = min(180, max(30, restSeconds)) }
    }

    private static func restText(_ s: Int) -> String {
        s < 60 ? "\(s) s" : s % 60 == 0 ? "\(s / 60) min" : "\(s / 60) min \(s % 60) s"
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                AppIcon.back.image
                    .font(Theme.icon(17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .background(Circle().fill(Theme.glass))
                    .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Retour")
            Text("Réglages")
                .font(Theme.font(.title2, weight: .bold))
                .foregroundStyle(Theme.onBackground)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    /// Une carte de réglages : un titre, puis son contenu, toujours avec le même rythme.
    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Theme.font(.headline, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var whoCard: some View {
        card("Sur ce téléphone, je suis") {
            SettingsSegmented(options: store.profiles.map { ($0.id, $0.name) }, selection: store.meId,
                              label: "Profil actif") { store.switchProfile(to: $0) }
        }
    }

    /// Le profil de l'autre, replié : une ligne à toucher pour l'ouvrir.
    private func partnerCard(_ partner: Profile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                showPartner.toggle()
            } label: {
                HStack(spacing: 12) {
                    ProfileAvatar(profile: partner, size: 36)
                    Text("Profil de \(partner.name)")
                        .font(Theme.font(.headline, weight: .semibold))
                    Spacer(minLength: 8)
                    AppIcon.back.image
                        .font(Theme.icon(13, weight: .bold))
                        .foregroundStyle(Theme.ink2)
                        .rotationEffect(.degrees(showPartner ? 90 : -90))
                }
                .frame(minHeight: Theme.minTouch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(showPartner ? "Replier" : "Déplier")
            if showPartner {
                ProfileEditor(profile: partner).id(partner.id)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, showPartner ? 16 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .motion(Motion.spring, value: showPartner)
    }

    private var gymCard: some View {
        card("Ma salle") {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KOMEX").font(Theme.font(.body, weight: .semibold))
                    Text("64B rue Sully, 21000 Dijon")
                        .font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                    Text("7j/7, 5h–23h")
                        .font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                    Text("Tram Mazen-Sully · parking gratuit à proximité")
                        .font(Theme.font(.footnote)).foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Link(destination: Self.gymMapsURL) {
                    VStack(spacing: 3) {
                        AppIcon.map.image.font(Theme.icon(17, weight: .semibold))
                        Text("Plans").font(Theme.font(.caption, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.ink))
                }
                .accessibilityLabel("Ouvrir KOMEX dans Plans")
            }
        }
    }
}

/// Un profil : prénom, photo, aide pour les disques, objectif de la semaine, schéma par défaut.
private struct ProfileEditor: View {
    @Environment(AppStore.self) private var store
    let profile: Profile
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(profile: Profile) {
        self.profile = profile
        _name = State(initialValue: profile.name)
    }

    /// Toujours la dernière version du profil (le store est la source de vérité).
    private var current: Profile { store.profiles.first { $0.id == profile.id } ?? profile }
    private var tint: Color { Theme.color(for: current) }
    private var goal: Int { current.settings?.weeklyGoal ?? 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                AvatarPicker(profile: current) { avatar in
                    var p = current; p.avatar = avatar; store.saveProfile(p)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Prénom")
                TextField("Prénom", text: $name)
                    .font(Theme.font(.body, weight: .semibold))
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(commitName)
                    .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
                    .padding(.horizontal, 14)
                    .frame(minHeight: Theme.minTouch)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.7)))
                    .accessibilityLabel("Prénom de \(current.name)")
            }

            Toggle(isOn: Binding(
                get: { Rules.profileNeedsHelp(current) },
                set: { v in var p = current; p.needsHelp = v; store.saveProfile(p) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aide pour les disques").font(Theme.font(.body, weight: .medium))
                    Text("Affiche « Aide » sur les machines à charger.")
                        .font(Theme.font(.footnote)).foregroundStyle(Theme.ink2)
                }
            }
            .tint(tint)
            .frame(minHeight: Theme.minTouch)

            SettingsStepper(title: "Objectif par semaine", valueText: "\(goal) séance\(goal > 1 ? "s" : "")",
                            value: Binding(
                get: { goal },
                set: { v in var p = current; var s = p.settings ?? ProfileSettings(); s.weeklyGoal = v
                    p.settings = s; store.saveProfile(p) }), range: 1...7, step: 1)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Façon de s’entraîner")
                SettingsSegmented(options: [(RepScheme.pyramid, "Pyramide"), (RepScheme.classic, "Classique")],
                                  selection: Rules.defaultScheme(for: current), label: "Façon de s’entraîner") { v in
                    var p = current; var s = p.settings ?? ProfileSettings(); s.defaultScheme = v
                    p.settings = s; store.saveProfile(p)
                }
                Text(Rules.defaultScheme(for: current) == .pyramid
                     ? "4 séries : 12 · 10 · 8 · 12. La dernière reprend la charge de la première."
                     : "Mêmes répétitions et même charge à chaque série.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear(perform: commitName)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { name = current.name; return }
        guard trimmed != current.name else { return }
        var p = current; p.name = trimmed; store.saveProfile(p)
    }
}

/// « − valeur + » à boutons de 48 pt (le Stepper système n'en fait que 32).
private struct SettingsStepper: View {
    let title: String
    let valueText: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                Text(valueText).font(Theme.font(.body, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
            }
            Spacer(minLength: 8)
            button(.minus, delta: -step, label: "moins")
            button(.add, delta: step, label: "plus")
        }
        .frame(minHeight: Theme.minTouch)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: set(value + step)
            case .decrement: set(value - step)
            @unknown default: break
            }
        }
    }

    private func set(_ v: Int) {
        withAnimation(Motion.reduced) { value = min(range.upperBound, max(range.lowerBound, v)) }
    }

    private func button(_ icon: AppIcon, delta: Int, label: String) -> some View {
        let next = value + delta
        let enabled = range.contains(next)
        return Button { set(next) } label: {
            icon.image.font(Theme.icon(17, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .background(Circle().fill(Color.white.opacity(0.62)))
                .opacity(enabled ? 1 : 0.3)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Sélecteur segmenté à segments de 48 pt de haut.
private struct SettingsSegmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    let label: String
    let onSelect: (T) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                let active = value == selection
                Button { if !active { onSelect(value) } } label: {
                    Text(title)
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(active ? Color.white : Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouch - 6)
                        .background(Capsule().fill(active ? Theme.ink : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(minHeight: Theme.minTouch)
        .background(Capsule().fill(Theme.ink.opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}
