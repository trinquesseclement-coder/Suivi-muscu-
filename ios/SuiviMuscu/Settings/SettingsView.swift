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
                Picker("Profil actif", selection: Binding(get: { store.meId }, set: { store.switchProfile(to: $0) })) {
                    ForEach(store.profiles) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: Theme.minTouch)
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
            SwiftUI.Stepper(value: $restSeconds, in: 30...180, step: 15) {
                Text("Temps de repos par défaut : \(restSeconds) s").font(Theme.font(.body))
            }
            .frame(minHeight: Theme.minTouch)
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

            SwiftUI.Stepper(value: Binding(
                get: { current.settings?.weeklyGoal ?? 3 },
                set: { v in var p = current; var s = p.settings ?? ProfileSettings(); s.weeklyGoal = v
                    p.settings = s; store.saveProfile(p) }), in: 1...7) {
                Text("Objectif : \(current.settings?.weeklyGoal ?? 3) séance\((current.settings?.weeklyGoal ?? 3) > 1 ? "s" : "") par semaine")
            }
            .frame(minHeight: Theme.minTouch)

            VStack(alignment: .leading, spacing: 6) {
                Text("Schéma par défaut").font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                Picker("Schéma par défaut", selection: Binding(
                    get: { Rules.defaultScheme(for: current) },
                    set: { v in var p = current; var s = p.settings ?? ProfileSettings(); s.defaultScheme = v
                        p.settings = s; store.saveProfile(p) })) {
                    Text("Pyramide 12/10/8/12").tag(RepScheme.pyramid)
                    Text("Classique").tag(RepScheme.classic)
                }
                .pickerStyle(.segmented)
                .frame(minHeight: Theme.minTouch)
            }
        }
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { name = current.name; return }
        guard trimmed != current.name else { return }
        var p = current; p.name = trimmed; store.saveProfile(p)
    }
}
