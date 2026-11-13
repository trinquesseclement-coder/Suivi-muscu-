import SwiftUI
import SuiviCore

/// Recherche, posture, aide et muscle (reprend `ExerciseFilters` du web). Partagé par l'onglet
/// Machines et le sélecteur d'exercices de la séance.
struct FilterState: Codable, Equatable {
    var query = ""
    var posture: Posture?
    var help: HelpFilter = .all
    var muscle: Muscle?

    enum HelpFilter: String, Codable { case all, with, without }

    /// La recherche n'est jamais enregistrée : oubliée, elle cacherait des machines sans qu'on le voie.
    enum CodingKeys: String, CodingKey { case posture, help, muscle }

    /// Un filtre (recherche comprise) réduit la liste.
    var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || posture != nil || help != .all || muscle != nil
    }

    /// `helpMatters` : le filtre d'aide ne compte que si quelqu'un a besoin d'aide (il est alors affiché).
    func apply(_ list: [Exercise], helpMatters: Bool) -> [Exercise] {
        let q = Self.norm(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return list.filter { e in
            if !q.isEmpty && !Self.norm(e.name).contains(q) && !Self.norm(Catalogue.muscleLabel(e.muscle)).contains(q) {
                return false
            }
            if let posture, e.posture != posture { return false }
            if helpMatters && help == .with && !e.help { return false }
            if helpMatters && help == .without && e.help { return false }
            if let muscle, e.muscle != muscle { return false }
            return true
        }
    }

    private static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    // MARK: Mémoire de l'écran

    /// Filtres mémorisés sous `key` (JSON) : posture, aide et muscle (onglet Machines).
    static func stored(_ key: String) -> FilterState {
        UserDefaults.standard.string(forKey: key)
            .flatMap { try? JSONDecoder().decode(FilterState.self, from: Data($0.utf8)) } ?? FilterState()
    }

    func store(_ key: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: key)
        }
    }
}

struct ExerciseFilters: View {
    @Binding var state: FilterState
    /// Le prénom de l'aidant : sans lui (personne n'a besoin d'aide), pas de filtre d'aide.
    let helperName: String?
    /// Suit le clavier de la recherche (le sélecteur cache son bouton du bas quand il est ouvert).
    var searching: FocusState<Bool>.Binding? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            search
                .padding(.bottom, 4)

            // Posture et aide sur une seule rangée qui défile : la liste commence plus haut.
            chips(selected: state.posture?.rawValue ?? (state.help == .all ? nil : "help-\(state.help.rawValue)")) {
                postureChip("Depuis le fauteuil", .fauteuil, icon: .wheelchair)
                postureChip("Transfert", .transfert, icon: nil)
                postureChip("Debout", .debout, icon: nil)
                if let helperName {
                    Capsule().fill(Theme.ink.opacity(0.12)).frame(width: 1.5, height: 22)
                        .accessibilityHidden(true)
                    chip("Avec \(helperName)", id: "help-with", on: state.help == .with, icon: .help) {
                        state.help = state.help == .with ? .all : .with
                    }
                    chip("Sans aide", id: "help-without", on: state.help == .without, icon: nil) {
                        state.help = state.help == .without ? .all : .without
                    }
                }
            }
            chips(selected: state.muscle?.rawValue ?? "tout") {
                chip("Tout", id: "tout", on: state.muscle == nil, icon: nil) { state.muscle = nil }
                ForEach(Muscle.allCases, id: \.self) { m in
                    chip(Catalogue.muscleLabel(m), id: m.rawValue, on: state.muscle == m, icon: nil) { state.muscle = m }
                }
            }
        }
        .padding(.top, 8)
    }

    private var search: some View {
        HStack(spacing: 8) {
            AppIcon.search.image.foregroundStyle(Theme.ink2)
            field
            if !state.query.isEmpty {
                Button { state.query = "" } label: {
                    AppIcon.close.image.font(Theme.icon(14, weight: .bold))
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, state.query.isEmpty ? 16 : 0)
        .frame(minHeight: Theme.minTouch)
        .background(Capsule().fill(Color.white.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private var field: some View {
        let text = TextField("Chercher une machine…", text: $state.query)
            .font(Theme.font(.body))
            .submitLabel(.search)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityLabel("Chercher")
        if let searching { text.focused(searching) } else { text }
    }

    /// Rangée de puces qui défile ; la puce choisie est ramenée en vue à l'ouverture et quand elle
    /// change (un filtre mémorisé, ou touché à moitié visible, ne reste jamais caché hors de l'écran).
    private func chips<Content: View>(selected: String?, @ViewBuilder _ content: () -> Content) -> some View {
        let row = content()
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) { row }
                    .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear { if let selected { proxy.scrollTo(selected, anchor: .center) } }
            .onChange(of: selected) { _, new in
                guard let new else { return }
                withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { proxy.scrollTo(new, anchor: .center) }
            }
        }
        .padding(.horizontal, -16)
    }

    private func postureChip(_ title: String, _ value: Posture, icon: AppIcon?) -> some View {
        chip(title, id: value.rawValue, on: state.posture == value, icon: icon) { state.posture = state.posture == value ? nil : value }
    }

    private func chip(_ title: String, id: String, on: Bool, icon: AppIcon?,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { icon.image.font(Theme.icon(13, weight: .semibold)) }
                Text(title)
            }
            .font(Theme.font(.subheadline, weight: .medium))
            .foregroundStyle(on ? Color.white : Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(Capsule().fill(on ? Theme.ink : Color.white.opacity(0.85)))
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(on ? 0 : 0.1), lineWidth: 1))
            // La puce fait 38 pt de haut, sa zone tactile 48.
            .frame(minHeight: Theme.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .motion(Motion.spring, value: on)
        .id(id)
    }
}
