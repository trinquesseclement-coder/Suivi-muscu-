import SwiftUI
import SuiviCore

/// Une séance type du cycle : son nom, ses exercices et leur ordre, les minutes du cardio.
/// Comme l'éditeur de machine, rien n'est écrit avant « Enregistrer » : revenir en arrière
/// abandonne les changements. Pas de charges ici : chacun reprend les siennes.
struct CycleTemplateEditor: View {
    /// `nil` : une nouvelle séance type, ajoutée à la fin du cycle.
    let templateId: String?

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var draft = CycleTemplate(id: "", title: "", items: [])
    @State private var loaded = false
    @State private var picking = false
    @FocusState private var nameFocused: Bool

    /// Durée d'un cardio ajouté, et ses bornes.
    private static let defaultMinutes = 15
    private static let minutes = 5.0...120.0

    private var isNew: Bool { templateId == nil }
    private var trimmedTitle: String { draft.title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedTitle.isEmpty && !draft.items.isEmpty }

    var body: some View {
        let byId = store.exerciseById
        let anyById = store.exerciseAnyById
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                field("Nom") {
                    TextField("Nom", text: $draft.title,
                              prompt: Text("Ex. : Jambes").foregroundStyle(Theme.ink2),
                              axis: .vertical)
                        .font(Theme.font(.body))
                        .lineLimit(1...3)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        // Champ sur plusieurs lignes (noms longs, très grand texte) : la touche « OK »
                        // y insère un retour à la ligne ; on le retire et on ferme le clavier.
                        .onChange(of: draft.title) { _, title in
                            guard title.contains(where: \.isNewline) else { return }
                            draft.title = title.filter { !$0.isNewline }
                            nameFocused = false
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill(Theme.glass))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(Theme.glassBorder, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                field("Exercices") {
                    if !draft.items.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(draft.items.enumerated()), id: \.element.exerciseId) { i, item in
                                if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)).padding(.leading, 74) }
                                row(i, item: item, exercise: anyById[item.exerciseId],
                                    hidden: byId[item.exerciseId] == nil)
                                    .transition(.opacity)
                            }
                        }
                        .glassCard()
                    }
                    addButton
                    hint("Les charges ne se règlent pas ici : chacun retrouve les siennes de la dernière fois.")
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
        .sheet(isPresented: $picking) {
            // Le cycle est commun : l'étiquette « Aide » suit celui des deux qui en a besoin.
            ExercisePicker(owner: store.profiles.first(where: Rules.profileNeedsHelp) ?? store.me) { add($0) }
        }
        .onAppear(perform: load)
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
            Text(isNew ? "Nouvelle séance" : "Modifier la séance")
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
                .accessibilityAddTraits(.isHeader)
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

    // MARK: Exercices

    /// Vignette, nom et « … » ; dessous, les minutes pour un cardio. Une machine masquée depuis
    /// reste visible, grisée, pour pouvoir la retirer.
    private func row(_ i: Int, item: CycleItem, exercise: Exercise?, hidden: Bool) -> some View {
        let name = exercise?.name ?? "Machine supprimée"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Group {
                    if let exercise {
                        ExerciseThumb(exercise: exercise, size: 48)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.ink.opacity(0.06))
                            .frame(width: 48, height: 48)
                    }
                }
                .opacity(hidden ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Theme.font(.body, weight: .semibold))
                        .foregroundStyle(hidden ? Theme.ink2 : Theme.ink)
                        .lineLimit(2)
                    if hidden {
                        Text("Machine masquée")
                            .font(Theme.font(.footnote))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                optionsMenu(i, name: name)
            }
            if exercise?.kind == .cardio && !hidden {
                // En très grand texte, « Minutes » passe au-dessus d'un stepper pleine largeur.
                let stacked = typeSize.isAccessibilitySize
                let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                                     : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Text("Minutes")
                        .font(Theme.font(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                        .accessibilityHidden(true)
                    if !stacked { Spacer(minLength: 0) }
                    Stepper(label: "Minutes de \(name)", unit: "min", step: 5, value: minutes(at: i),
                            range: Self.minutes)
                        .frame(maxWidth: stacked ? .infinity : 220)
                }
                .padding(.leading, stacked ? 0 : 60)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func optionsMenu(_ i: Int, name: String) -> some View {
        Menu {
            Button { move(i, by: -1) } label: {
                Label { Text("Monter") } icon: { AppIcon.up.image }
            }
            .disabled(i == 0)
            Button { move(i, by: 1) } label: {
                Label { Text("Descendre") } icon: { AppIcon.down.image }
            }
            .disabled(i == draft.items.count - 1)
            Button(role: .destructive) { remove(at: i) } label: {
                Label { Text("Retirer") } icon: { AppIcon.delete.image }
            }
        } label: {
            AppIcon.more.image
                .font(Theme.icon(17, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .contentShape(Rectangle())
        }
        // Le « … » garde sa zone de 48 pt mais s'aligne sur le bord droit du stepper.
        .padding(.trailing, -12)
        .accessibilityLabel("Options de \(name)")
    }

    private var addButton: some View {
        Button { picking = true } label: {
            HStack(spacing: 8) {
                AppIcon.add.image.font(Theme.icon(17, weight: .bold))
                Text("Ajouter des exercices")
            }
            .font(Theme.font(.headline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(Theme.glass))
            .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Barre du bas

    private var bottomBar: some View {
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
        .accessibilityHint(canSave ? "" : trimmedTitle.isEmpty ? "Donne un nom à la séance" : "Ajoute un exercice")
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

    /// Une seule fois : revenir du sélecteur d'exercices ne doit pas effacer le brouillon.
    private func load() {
        guard !loaded else { return }
        loaded = true
        if let templateId, let t = store.cycle.templates.first(where: { $0.id == templateId }) {
            draft = t
        } else {
            draft = CycleTemplate(id: Cycle.newTemplateId(), title: "", items: [])
        }
    }

    private func minutes(at i: Int) -> Binding<Double> {
        Binding(get: { Double((draft.items.indices.contains(i) ? draft.items[i].minutes : nil) ?? Self.defaultMinutes) },
                set: { v in if draft.items.indices.contains(i) { draft.items[i].minutes = Int(v.rounded()) } })
    }

    private func add(_ exercises: [Exercise]) {
        let items = exercises.map {
            CycleItem(exerciseId: $0.id, minutes: $0.kind == .cardio ? Self.defaultMinutes : nil)
        }
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { draft.add(items) }
    }

    private func move(_ i: Int, by offset: Int) {
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { draft.moveItem(at: i, by: offset) }
    }

    private func remove(at i: Int) {
        guard draft.items.indices.contains(i) else { return }
        _ = withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { draft.items.remove(at: i) }
    }

    private func save() {
        guard canSave else { return }
        var t = draft
        t.title = trimmedTitle
        var cycle = store.cycle
        cycle.upsert(t)
        store.saveCycle(cycle)
        dismiss()
    }
}
