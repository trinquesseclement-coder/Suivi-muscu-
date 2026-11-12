import SwiftUI
import SuiviCore

/// Choix des exercices à ajouter à la séance (reprend `ExercisePicker` et `ExerciseFilters` du web).
/// La sélection est multiple ; « Ajouter (n) » renvoie les exercices dans l'ordre où on les a choisis.
struct ExercisePicker: View {
    let onAdd: ([Exercise]) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Posture retenue d'une ouverture à l'autre : « fauteuil », « transfert », « debout » ou vide (tout).
    @AppStorage("picker.posture") private var postureRaw = ""
    @State private var query = ""
    @State private var help: HelpFilter = .all
    @State private var muscle: Muscle?
    @State private var picked: [String] = []
    @FocusState private var searching: Bool

    enum HelpFilter { case all, with, without }

    private var posture: Posture? { Posture(rawValue: postureRaw) }

    private var list: [Exercise] {
        let q = Self.norm(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return store.exercises.filter { e in
            if !q.isEmpty && !Self.norm(e.name).contains(q) && !Self.norm(Catalogue.muscleLabel(e.muscle)).contains(q) {
                return false
            }
            if let posture, e.posture != posture { return false }
            if help == .with && !e.help { return false }
            if help == .without && e.help { return false }
            if let muscle, e.muscle != muscle { return false }
            return true
        }
    }

    var body: some View {
        let shown = list
        let byId = store.exerciseById
        return VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    filters
                        .padding(.bottom, 10)
                    if shown.isEmpty {
                        Text("Aucun exercice avec ces filtres.")
                            .font(Theme.font(.subheadline))
                            .foregroundStyle(Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(shown.enumerated()), id: \.element.id) { i, ex in
                                if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)) }
                                row(ex)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill(Color.white.opacity(0.6)))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            // Le clavier ouvert laisse peu de place : le bouton revient quand la recherche est fermée.
            if !searching { footer(byId) }
        }
        .background(Color(hex: 0xECF1EF).ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: En-tête et filtres

    private var header: some View {
        HStack {
            Text("Ajouter des exercices")
                .font(Theme.font(.title3, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                AppIcon.close.image
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Fermer")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 14)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AppIcon.search.image.foregroundStyle(Theme.ink2)
                TextField("Chercher une machine…", text: $query)
                    .font(Theme.font(.body))
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($searching)
                    .accessibilityLabel("Chercher")
                if !query.isEmpty {
                    Button { query = "" } label: {
                        AppIcon.close.image.font(.system(size: 14, weight: .bold))
                            .frame(width: Theme.minTouch, height: Theme.minTouch)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Effacer la recherche")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, query.isEmpty ? 16 : 0)
            .frame(minHeight: 52)
            .background(Capsule().fill(Color.white.opacity(0.85)))
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))

            chips {
                postureChip("Depuis le fauteuil", .fauteuil, icon: .wheelchair)
                postureChip("Transfert", .transfert, icon: nil)
                postureChip("Debout", .debout, icon: nil)
            }
            chips {
                chip("Avec aide", on: help == .with, icon: .help) { help = help == .with ? .all : .with }
                chip("Sans aide", on: help == .without, icon: nil) { help = help == .without ? .all : .without }
            }
            chips {
                chip("Tout", on: muscle == nil, icon: nil) { muscle = nil }
                ForEach(Muscle.allCases, id: \.self) { m in
                    chip(Catalogue.muscleLabel(m), on: muscle == m, icon: nil) { muscle = m }
                }
            }
        }
        .padding(.top, 8)
    }

    private func chips<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -12)
    }

    private func postureChip(_ title: String, _ value: Posture, icon: AppIcon?) -> some View {
        chip(title, on: posture == value, icon: icon) { postureRaw = posture == value ? "" : value.rawValue }
    }

    private func chip(_ title: String, on: Bool, icon: AppIcon?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { icon.image.font(.system(size: 13, weight: .semibold)) }
                Text(title)
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(on ? Color.white : Theme.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: Theme.minTouch)
            .background(Capsule().fill(on ? Theme.ink : Color.white.opacity(0.85)))
            .overlay(Capsule().strokeBorder(Theme.ink.opacity(on ? 0 : 0.1), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .motion(Motion.spring, value: on)
    }

    // MARK: Lignes

    private func row(_ ex: Exercise) -> some View {
        let on = picked.contains(ex.id)
        return Button {
            if let i = picked.firstIndex(of: ex.id) { picked.remove(at: i) } else { picked.append(ex.id) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(on ? Color.clear : Theme.ink.opacity(0.3), lineWidth: 1.5)
                    Circle().fill(on ? Theme.profile1 : Color.clear)
                    if on { AppIcon.check.image.font(.system(size: 13, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 28, height: 28)
                ExerciseThumb(exercise: ex)
                VStack(alignment: .leading, spacing: 5) {
                    Text(ex.name)
                        .font(Theme.font(.headline, weight: .semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(spacing: 6) {
                        Pill(text: Catalogue.muscleLabel(ex.muscle))
                        switch ex.posture {
                        case .fauteuil: Pill(text: "Fauteuil", icon: .wheelchair, fill: Theme.profile1.opacity(0.18))
                        case .transfert: Pill(text: "Transfert")
                        case .debout: Pill(text: "Debout")
                        }
                        if ex.help { Pill(text: "Avec aide", icon: .help, fill: Theme.profile2.opacity(0.16)) }
                    }
                    Text(Self.machineLabel(ex))
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(on ? Theme.profile1.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .motion(Motion.spring, value: on)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(ex.name), \(Catalogue.muscleLabel(ex.muscle)), \(Self.postureText(ex.posture))\(ex.help ? ", avec aide" : "")")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Bouton du bas

    private func footer(_ byId: [String: Exercise]) -> some View {
        let n = picked.count
        return Button {
            let chosen = picked.compactMap { byId[$0] }
            guard !chosen.isEmpty else { return }
            onAdd(chosen)
            dismiss()
        } label: {
            Text(n > 0 ? "Ajouter (\(n))" : "Ajouter")
                .font(Theme.font(.headline, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(Theme.ink.opacity(n > 0 ? 1 : 0.35)))
        }
        .buttonStyle(PressableStyle())
        .disabled(n == 0)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(hex: 0xECF1EF).shadow(.drop(color: .black.opacity(0.08), radius: 6, y: -2)))
    }

    // MARK: Textes

    private static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
    }

    private static func postureText(_ p: Posture) -> String {
        switch p {
        case .fauteuil: "depuis le fauteuil"
        case .transfert: "transfert"
        case .debout: "debout"
        }
    }

    /// « Hammer Strength · Machine à disques » (comme `machineLabel` du web).
    private static func machineLabel(_ ex: Exercise) -> String {
        let equipment: String = switch ex.equipment {
        case .machine: "Machine guidée"
        case .disques: "Machine à disques"
        case .poulie: "Poulie"
        case .smith: "Smith machine"
        case .halteres: "Haltères"
        case .cardio: "Cardio"
        }
        let brand: String? = switch ex.brand {
        case .technogym: "Technogym"
        case .hammer: "Hammer Strength"
        case .autre, nil: nil
        }
        return brand.map { "\($0) · \(equipment)" } ?? equipment
    }
}
