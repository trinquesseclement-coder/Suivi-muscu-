import SwiftUI
import SuiviCore

/// Onglet « Machines » : le catalogue de la salle, ses filtres, la fiche et l'éditeur de chaque
/// machine (reprend `appli/src/pages/Machines.tsx`, maquette `13-machines.jpg`).
struct MachinesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Posture, aide et muscle retenus d'une ouverture à l'autre ; la recherche repart vide.
    @State private var filters = FilterState.stored(Self.filtersKey)
    @State private var viewing: Exercise?
    @State private var editing: EditRoute?
    @State private var showHidden = false

    private static let filtersKey = "machines.filters"
    #if DEBUG
    private static var debugDone = false
    /// `-machines-hidden` ouvre la liste en bas, sur les machines masquées.
    private static let opensAtBottom = ProcessInfo.processInfo.arguments.contains("-machines-hidden")
    #else
    private static let opensAtBottom = false
    #endif

    /// Machine à corriger, ou nouvelle machine perso.
    struct EditRoute: Hashable, Identifiable {
        var exercise: Exercise
        var isNew: Bool
        var id: String { exercise.id }
    }

    var body: some View {
        let all = store.exercises
        let helper = Rules.helperName(store.profiles)
        let list = filters.apply(all, helpMatters: helper != nil)
        let hidden = store.exerciseAnyById.values
            .filter { $0.deleted == true && Catalogue.baseIds.contains($0.id) }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "fr_FR")) == .orderedAscending }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                header(count: all.count)
                ExerciseFilters(state: $filters, helperName: helper)

                if list.isEmpty {
                    emptyState
                } else {
                    section("Musculation", list.filter { $0.kind == .muscu }, helper: helper)
                    section("Cardio", list.filter { $0.kind == .cardio }, helper: helper)
                }

                if !hidden.isEmpty { hiddenSection(hidden) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .defaultScrollAnchor(Self.opensAtBottom ? .bottom : nil)
        .task { debugLaunch() }
        .onChange(of: filters) { _, new in new.store(Self.filtersKey) }
        .sheet(item: $viewing) { MachineSheet(exercise: $0) }
        .navigationDestination(item: $editing) { MachineEditor(exercise: $0.exercise, isNew: $0.isNew) }
    }

    // MARK: En-tête

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text("Machines")
                    .font(Theme.font(.title, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button(action: addMachine) {
                    AppIcon.add.image
                        .font(Theme.icon(20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Theme.glass))
                        .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Ajouter une machine")
            }
            // Sous le titre et le « + », sur toute la largeur : la ligne ne se coupe pas.
            // Espaces insécables avant chaque « · » : une ligne ne commence jamais par un point.
            Text("KOMEX\u{00A0}· \(count)\u{00A0}exercices\u{00A0}· touche pour corriger")
                .font(Theme.font(.subheadline))
                .opacity(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, -6)
        }
        .foregroundStyle(Theme.onBackground)
        .padding(.horizontal, 2)
    }

    // MARK: Liste

    @ViewBuilder
    private func section(_ title: String, _ items: [Exercise], helper: String?) -> some View {
        if !items.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.font(.title3, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(items.count)")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .opacity(0.8)
                    .accessibilityLabel("\(items.count) machines")
            }
            .foregroundStyle(Theme.onBackground)
            .padding(.horizontal, 2)

            // Paresseux aussi à l'intérieur de la carte : seules les lignes visibles sont construites.
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, ex in
                    if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)).padding(.leading, 76) }
                    row(ex, helper: helper)
                }
            }
            .glassCard()
        }
    }

    private func row(_ ex: Exercise, helper: String?) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // La vignette ouvre la fiche (photo, mouvement) ; le reste de la ligne ouvre l'éditeur.
            Button { viewing = ex } label: {
                ExerciseThumb(exercise: ex)
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Voir \(ex.name) : machine et mouvement")
            .accessibilityAddTraits(.isButton)

            Button { editing = EditRoute(exercise: ex, isNew: false) } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name)
                            .font(Theme.font(.body, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        FlowLayout(spacing: 6) { badges(ex, helper: helper) }
                        Text(MachineText.machine(ex))
                            .font(Theme.font(.footnote))
                            .foregroundStyle(Theme.ink2)
                        if let note = ex.note, !note.isEmpty {
                            Text(note)
                                .font(Theme.font(.footnote))
                                .foregroundStyle(Theme.ink2)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    AppIcon.forward.image
                        .font(Theme.icon(13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                }
                .padding(.vertical, 12)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Corriger la machine")
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder private func badges(_ ex: Exercise, helper: String?) -> some View {
        if ex.kind == .muscu { Pill(text: Catalogue.muscleLabel(ex.muscle)) }
        switch ex.posture {
        case .fauteuil: Pill(text: "Fauteuil", icon: .wheelchair, fill: Theme.profile1.opacity(0.18))
        case .transfert: Pill(text: "Transfert")
        case .debout: Pill(text: "Debout")
        }
        if ex.help { Pill(text: helper.map { "Aide \($0)" } ?? "Aide", icon: .help, fill: Theme.profile2.opacity(0.16)) }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            AppIcon.search.image
                .font(Theme.icon(20, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.softFill))
                .accessibilityHidden(true)
            Text("Aucune machine ne correspond")
                .font(Theme.font(.headline, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Essaie un autre muscle ou une autre posture.")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
            if filters.isActive {
                Button { filters = FilterState() } label: {
                    Text("Effacer les filtres")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 22)
                        .frame(minHeight: Theme.minTouch)
                        .background(Capsule().fill(Theme.ink))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: Machines masquées

    /// Une machine masquée par erreur se réaffiche d'ici (sinon, plus moyen de la retrouver).
    private func hiddenSection(_ hidden: [Exercise]) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { showHidden.toggle() }
            } label: {
                HStack(spacing: 10) {
                    AppIcon.hidden.image
                        .font(Theme.icon(15, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                    Text("Machines masquées (\(hidden.count))")
                        .font(Theme.font(.subheadline, weight: .semibold))
                    Spacer(minLength: 0)
                    AppIcon.forward.image
                        .font(Theme.icon(13, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .rotationEffect(.degrees(showHidden ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(showHidden ? .isSelected : [])
            .accessibilityHint(showHidden ? "Replier" : "Déplier")

            if showHidden {
                ForEach(hidden) { ex in
                    Divider().overlay(Theme.ink.opacity(0.08))
                    HStack(spacing: 12) {
                        ExerciseThumb(exercise: ex, size: 40)
                        Text(ex.name)
                            .font(Theme.font(.subheadline, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Button {
                            var e = ex
                            e.deleted = false
                            store.saveExercise(e)
                        } label: {
                            Text("Réafficher")
                                .font(Theme.font(.subheadline, weight: .semibold))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 38)
                                .background(Capsule().fill(Theme.raisedFill))
                                .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
                                .frame(minHeight: Theme.minTouch)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Réafficher \(ex.name)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .transition(.opacity)
                }
            }
        }
        .glassCard()
        .padding(.top, 8)
    }

    // MARK: Actions

    private func addMachine() {
        let ex = Exercise(id: "perso-\(UUID().uuidString.lowercased())", name: "", kind: .muscu, muscle: .pecs,
                          posture: .transfert, help: false, equipment: .machine, step: 5, custom: true)
        editing = EditRoute(exercise: ex, isNew: true)
    }

    /// Mise au point (DEBUG) : `-machines-sheet <id>` ouvre la fiche, `-machines-edit <id>` l'éditeur,
    /// `-machines-new` une nouvelle machine (`-machines-name` son nom), `-machines-filter <posture|vide>` règle la posture,
    /// `-machines-query <texte>` cherche, `-machines-hidden` déplie les machines masquées en bas.
    private func debugLaunch() {
        #if DEBUG
        // Une seule fois par lancement : pas à chaque retour sur l'onglet.
        guard !Self.debugDone else { return }
        Self.debugDone = true
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            args.firstIndex(of: key).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        let byId = store.exerciseAnyById
        if let p = value("-machines-filter") { filters.posture = Posture(rawValue: p) }
        if let m = value("-machines-muscle") { filters.muscle = Muscle(rawValue: m) }
        if let q = value("-machines-query") { filters.query = q }
        if let id = value("-machines-sheet") { viewing = byId[id] }
        // `-machines-note` / `-machines-name` préremplissent l'éditeur (le simulateur ne tape pas de texte) :
        // l'enregistrement passe ensuite par le vrai bouton « Enregistrer ».
        if let id = value("-machines-edit"), var ex = byId[id] {
            if let note = value("-machines-note") { ex.note = note }
            editing = EditRoute(exercise: ex, isNew: false)
        }
        if args.contains("-machines-new") {
            addMachine()
            if let name = value("-machines-name") { editing?.exercise.name = name }
        }
        if args.contains("-machines-hidden") { showHidden = true }
        #endif
    }
}
