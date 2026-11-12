import SwiftUI
import SuiviCore

/// Corriger une machine du catalogue ou créer une machine perso (reprend `ExerciseEditor` du web,
/// maquette `14-machine-edition.jpg`). Rien n'est écrit avant « Enregistrer » : revenir en arrière
/// abandonne les changements.
struct MachineEditor: View {
    let exercise: Exercise
    let isNew: Bool

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Exercise
    @State private var confirmRemove = false

    init(exercise: Exercise, isNew: Bool) {
        self.exercise = exercise
        self.isNew = isNew
        _draft = State(initialValue: exercise)
    }

    /// Machine du catalogue (« Masquer ») ou machine perso (« Supprimer »).
    private var isBase: Bool { Catalogue.base.contains { $0.id == exercise.id } }
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let helper = Rules.helperName(store.profiles)
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                field("Nom") {
                    // Sur plusieurs lignes en très grand texte : le nom reste lisible en entier.
                    TextField("Nom", text: $draft.name,
                              prompt: Text("Ex. : Chest press Technogym").foregroundStyle(Theme.ink2),
                              axis: .vertical)
                        .font(Theme.font(.body))
                        .lineLimit(1...3)
                        .submitLabel(.done)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill(Theme.glass))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(Theme.glassBorder, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                if draft.custom == true {
                    field("Type") {
                        WhoPicker(options: [(Kind.muscu, "Musculation"), (Kind.cardio, "Cardio")],
                                  selection: Binding(get: { draft.kind }, set: setKind))
                    }
                }
                field("Comment tu la fais") {
                    WhoPicker(options: [(Posture.fauteuil, "Fauteuil"), (.transfert, "Transfert"), (.debout, "Debout")],
                              selection: $draft.posture)
                    hint("Fauteuil = sans quitter le fauteuil · Transfert = s’installer sur le siège · Debout = appui court")
                }
                field("Besoin d’aide ?") {
                    WhoPicker(options: [(false, "Seul"), (true, helper.map { "Avec \($0)" } ?? "Avec aide")],
                              selection: $draft.help)
                }
                if draft.kind == .muscu {
                    field("Muscle principal") {
                        menu(MachineText.muscles.map { ($0, Catalogue.muscleLabel($0)) }, selection: $draft.muscle)
                    }
                    field("Équipement") {
                        menu(MachineText.equipments.map { ($0, MachineText.equipment($0)) }, selection: $draft.equipment)
                    }
                    field("Marque") {
                        menu(MachineText.brands.map { ($0, MachineText.brand($0)) },
                             selection: Binding(get: { draft.brand ?? .autre }, set: { draft.brand = $0 }))
                    }
                    field("Pas des boutons +/−") {
                        Stepper(label: "Pas des boutons", unit: "kg", step: 1.25,
                                value: Binding(get: { draft.step ?? 2.5 },
                                               set: { draft.step = Self.nextStep(from: draft.step ?? 2.5, to: $0) }),
                                range: 0.5...10)
                        // Posé sur le même verre que les autres champs (sinon il paraît grisé sur le fond).
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.glass))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.glassBorder, lineWidth: 1))
                    }
                }
                field("Note (réglages, numéro de la machine…)") {
                    TextField("Note", text: Binding(get: { draft.note ?? "" }, set: { draft.note = $0 }),
                              prompt: Text("Ex. : siège cran 4, dossier cran 2, retirer le siège pour le fauteuil")
                                .foregroundStyle(Theme.ink2),
                              axis: .vertical)
                        .font(Theme.font(.body))
                        .lineLimit(3...8)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                            .fill(Theme.glass))
                        .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                            .strokeBorder(Theme.glassBorder, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
    }

    // MARK: En-tête et champs

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button { dismiss() } label: {
                AppIcon.back.image
                    .font(Theme.icon(17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: Theme.minTouch, height: Theme.minTouch)
                    .background(Circle().fill(Theme.glass))
                    .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Retour sans enregistrer")
            Text(isNew ? "Nouvelle machine" : "Modifier")
                .font(Theme.font(.title, weight: .bold))
                .foregroundStyle(Theme.onBackground)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.onBackground)
                .padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.footnote))
            .foregroundStyle(Theme.onBackground.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    /// Liste déroulante en capsule de 52 pt, comme les autres champs.
    private func menu<Value: Hashable>(_ options: [(Value, String)], selection: Binding<Value>) -> some View {
        Menu {
            Picker(selection: selection) {
                ForEach(options, id: \.0) { value, title in Text(title).tag(value) }
            } label: { EmptyView() }
        } label: {
            HStack {
                Text(options.first { $0.0 == selection.wrappedValue }?.1 ?? "")
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                AppIcon.expand.image
                    .font(Theme.icon(13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .background(Capsule().fill(Theme.glass))
            .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
            .contentShape(Capsule())
        }
        .sensoryFeedback(.selection, trigger: selection.wrappedValue)
    }

    // MARK: Barre du bas

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if !isNew {
                Button { confirmRemove = true } label: {
                    Text(isBase ? "Masquer" : "Supprimer")
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Theme.destructive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Theme.raisedFill))
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .confirmationDialog(isBase ? "Masquer cette machine du catalogue ?" : "Supprimer cette machine ?",
                                    isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button(isBase ? "Masquer" : "Supprimer", role: .destructive, action: remove)
                    Button("Annuler", role: .cancel) {}
                } message: {
                    Text(isBase ? "Elle reste dans l’historique. Tu pourras la réafficher en bas de la liste."
                                : "Elle sort de la liste ; les séances où tu l’as faite la gardent.")
                }
            }
            Button(action: save) {
                Text("Enregistrer")
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Theme.ink.opacity(canSave ? 1 : 0.35)))
            }
            .buttonStyle(PressableStyle())
            .disabled(!canSave)
            .accessibilityHint(canSave ? "" : "Donne un nom à la machine")
        }
        .padding(5)
        .background(Capsule().fill(Theme.barFill))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 6)
        .background { BottomFade() }
    }

    // MARK: Actions

    private func setKind(_ kind: Kind) {
        draft.kind = kind
        draft.equipment = kind == .cardio ? .cardio : .machine
        if kind == .muscu && draft.muscle == .cardio { draft.muscle = .pecs }
    }

    private func save() {
        guard canSave else { return }
        var e = draft
        e.name = e.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if e.kind == .cardio { e.muscle = .cardio }
        if let note = e.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { e.note = note }
        else { e.note = nil }
        // La photo a pu changer dans la fiche pendant que l'éditeur était ouvert : on garde la dernière.
        e.photo = store.exerciseAnyById[e.id]?.photo ?? e.photo
        store.saveExercise(e)
        dismiss()
    }

    /// Masquer (catalogue) ou supprimer (perso) : `deleted = true` sur la machine enregistrée, sans les
    /// changements en cours. Elle reste lisible dans l'historique (`exerciseAnyById`).
    private func remove() {
        var e = store.exerciseAnyById[exercise.id] ?? exercise
        e.deleted = true
        store.saveExercise(e)
        dismiss()
    }

    /// Pas des boutons : 0,5 puis les multiples de 1,25 jusqu'à 10. « + » et « − » vont au cran
    /// suivant ou précédent ; une valeur tapée au clavier va au cran le plus proche.
    static let steps: [Double] = [0.5] + (1...8).map { Double($0) * 1.25 }

    static func nextStep(from old: Double, to new: Double) -> Double {
        if abs(abs(new - old) - 1.25) < 0.001 {
            return new > old ? steps.first { $0 > old + 0.001 } ?? old : steps.last { $0 < old - 0.001 } ?? old
        }
        return steps.min { abs($0 - new) < abs($1 - new) } ?? new
    }
}

/// Libellés des machines (mêmes textes que `appli/src/data/exercises.ts`).
enum MachineText {
    static let muscles: [Muscle] = Muscle.allCases.filter { $0 != .cardio }
    static let equipments: [Equipment] = [.machine, .disques, .poulie, .smith, .halteres]
    static let brands: [Brand] = [.technogym, .hammer, .autre]

    static func equipment(_ e: Equipment) -> String {
        switch e {
        case .machine: "Machine guidée"
        case .disques: "Machine à disques"
        case .poulie: "Poulie"
        case .smith: "Smith machine"
        case .halteres: "Haltères"
        case .cardio: "Cardio"
        }
    }

    static func brand(_ b: Brand) -> String {
        switch b {
        case .technogym: "Technogym"
        case .hammer: "Hammer Strength"
        case .autre: "Autre marque"
        }
    }

    /// « Hammer Strength · Machine à disques », ou l'équipement seul sans marque connue.
    static func machine(_ ex: Exercise) -> String {
        if let b = ex.brand, b != .autre { return "\(brand(b)) · \(equipment(ex.equipment))" }
        return equipment(ex.equipment)
    }
}
