import SwiftUI
import SuiviCore

/// Réglages essentiels : profils, séance, salle (copie de `appli/src/pages/Settings.tsx`).
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("rest.seconds") private var restSeconds = 90

    private static let gymMapsURL = URL(string: "https://maps.apple.com/?q=KOMEX%2C%2064B%20rue%20Sully%2C%2021000%20Dijon")!

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    profilesCard
                    sessionCard
                    gymCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        // Une ancienne valeur hors bornes (30 à 180 s) est ramenée dans la plage.
        .onAppear { restSeconds = min(180, max(30, restSeconds)) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                AppIcon.back.image
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .background(Circle().fill(Theme.glass))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retour")
            Text("Réglages")
                .font(Theme.font(.title2, weight: .bold))
                .foregroundStyle(Color(hex: 0xEEF3F0))
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Profils").font(Theme.font(.title3, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                Text("Sur ce téléphone, je suis").font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                SettingsSegmented(options: store.profiles.map { ($0.id, $0.name) }, selection: store.meId,
                                  label: "Profil actif") { store.switchProfile(to: $0) }
            }
            ForEach(store.profiles) { p in
                Divider()
                ProfileEditor(profile: p)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Séance").font(Theme.font(.title3, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            SettingsStepper(title: "Temps de repos par défaut", valueText: "\(restSeconds) s",
                            value: $restSeconds, range: 30...180, step: 15)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var gymCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ma salle").font(Theme.font(.title3, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 2) {
                Text("KOMEX").font(Theme.font(.body, weight: .semibold))
                Text("64B rue Sully, 21000 Dijon").font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                Text("7j/7, 5h–23h · Tram : Mazen-Sully · parking gratuit à proximité")
                    .font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
            }
            Link(destination: Self.gymMapsURL) {
                HStack(spacing: 8) {
                    AppIcon.map.image
                    Text("Plans").font(Theme.font(.body, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: Theme.minTouch)
                .background(Capsule().fill(Theme.ink))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
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
        VStack(alignment: .leading, spacing: 8) {
            AvatarPicker(profile: current) { avatar in
                var p = current; p.avatar = avatar; store.saveProfile(p)
            }
            TextField("Prénom", text: $name)
                .font(Theme.font(.body, weight: .semibold))
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(commitName)
                .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.minTouch)
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Color.white.opacity(0.7)))
                .accessibilityLabel("Prénom de \(current.name)")

            Toggle("A besoin d’aide pour les disques", isOn: Binding(
                get: { Rules.profileNeedsHelp(current) },
                set: { v in var p = current; p.needsHelp = v; store.saveProfile(p) }))
                .tint(tint)
                .frame(minHeight: Theme.minTouch)

            SettingsStepper(title: "Objectif par semaine", valueText: "\(goal) séance\(goal > 1 ? "s" : "")",
                            value: Binding(
                get: { goal },
                set: { v in var p = current; var s = p.settings ?? ProfileSettings(); s.weeklyGoal = v
                    p.settings = s; store.saveProfile(p) }), range: 1...7, step: 1)

            VStack(alignment: .leading, spacing: 6) {
                Text("Schéma par défaut").font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                SettingsSegmented(options: [(RepScheme.pyramid, "Pyramide 12/10/8/12"), (RepScheme.classic, "Classique")],
                                  selection: Rules.defaultScheme(for: current), label: "Schéma par défaut") { v in
                    var p = current; var s = p.settings ?? ProfileSettings(); s.defaultScheme = v
                    p.settings = s; store.saveProfile(p)
                }
            }
        }
        .onDisappear(perform: commitName)
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

    private func set(_ v: Int) { value = min(range.upperBound, max(range.lowerBound, v)) }

    private func button(_ icon: AppIcon, delta: Int, label: String) -> some View {
        let next = value + delta
        let enabled = range.contains(next)
        return Button { set(next) } label: {
            icon.image.font(.system(size: 17, weight: .bold))
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
