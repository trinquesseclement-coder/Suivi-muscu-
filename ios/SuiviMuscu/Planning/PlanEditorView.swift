import SwiftUI
import SuiviCore

/// Préparer une séance pour moi, pour l'autre ou pour les deux, ou modifier une séance prévue
/// (reprend `appli/src/pages/PlanEditor.tsx`, maquette `04-plan-editeur.jpg`).
/// Toute la construction des séances passe par `PlanBuilder` ; l'écran ne fait que la saisie.
struct PlanEditorView: View {
    let sessionId: String?
    let date: String?
    /// Enregistrée ou supprimée : retour au Planning, sur la semaine de cette date.
    var onDone: (_ date: String) -> Void = { _ in }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var loaded = false
    /// La séance à modifier n'existe plus (supprimée, ou jamais trouvée) : on quitte l'écran.
    @State private var missing = false
    /// Date d'origine d'une séance existante : la seule date passée qu'on peut garder.
    @State private var originalDate: String?
    @State private var day = Dates.isoDate(Date())
    @State private var target: PlanTarget = .both
    @State private var title = ""
    @State private var notes = ""
    @State private var specs: [PlanSpec] = []
    @State private var picking = false
    @State private var copying = false
    @State private var confirmDelete = false

    #if DEBUG
    private static var debugHooksDone = false
    #endif

    private var existing: Session? { sessionId.flatMap { store.session($0) } }
    private var isEdit: Bool { sessionId != nil }

    private var singleOwner: Profile? {
        switch target {
        case .me: store.me
        case .partner: store.partner
        case .both: nil
        }
    }

    private var owners: [Profile] { singleOwner.map { [$0] } ?? [store.me, store.partner] }
    /// L'aide ne concerne que les séances de la personne qui en a besoin.
    private var helpMatters: Bool { owners.contains(where: Rules.profileNeedsHelp) }

    var body: some View {
        Group {
            if missing { Color.clear } else { editor }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
    }

    private var editor: some View {
        let byId = store.exerciseAnyById
        let today = Dates.isoDate(Date())
        let helper = Rules.helperName(store.profiles)

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                field("Date") { dateRow(today: today) }
                field("Pour qui") {
                    WhoPicker(options: whoOptions, selection: Binding(get: { target }, set: retarget))
                    if target == .both {
                        Text("Une séance chacun, avec les charges et la façon de faire de chacun.")
                            .font(Theme.font(.footnote))
                            .foregroundStyle(Theme.onBackground.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }
                field("Nom") {
                    TextField("Nom", text: $title,
                              prompt: Text(PlanBuilder.titleSuggestion(specs, byId: byId)).foregroundStyle(Theme.ink2))
                        .font(Theme.font(.body))
                        .submitLabel(.done)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Theme.glass))
                        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                exercises(byId: byId, helper: helper)
                field("Notes") {
                    TextField("Notes", text: $notes,
                              prompt: Text("Ex. : arriver tôt, la presse est souvent prise vers 18 h")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlanEditorBottomBar(label: isEdit ? "Enregistrer" : target == .both ? "Planifier pour les deux" : "Planifier",
                                enabled: !specs.isEmpty, showsDelete: isEdit, confirmDelete: $confirmDelete,
                                onSave: save, onDelete: delete)
        }
        .sheet(isPresented: $picking) {
            ExercisePicker(owner: singleOwner ?? owners.first(where: Rules.profileNeedsHelp) ?? store.me) { add($0) }
        }
        .sheet(isPresented: $copying) { CopySessionSheet { copy(from: $0) } }
        .task { debugLaunchHooks() }
    }

    // MARK: En-tête et champs

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
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
            // Le jour est juste dessous, dans « Date » : pas besoin de le répéter ici.
            Text(isEdit ? "Modifier la séance" : "Planifier")
                .font(Theme.font(.title, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: Theme.minTouch, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(Theme.onBackground)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.onBackground)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func dateRow(today: String) -> some View {
        let lower = min(originalDate ?? today, today)
        let range = (Dates.parse(lower) ?? Date())...
        let selection = Binding<Date>(
            get: { Dates.parse(day) ?? Date() },
            set: { day = Dates.isoDate($0) })
        let picker = DatePicker("Date", selection: selection, in: range, displayedComponents: .date)
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.timeZone, TimeZone(identifier: "Europe/Paris") ?? .current)
        // En très grand texte, le jour seul laisse sa place au sélecteur, qui dit déjà tout.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                AppIcon.planning.image
                    .font(Theme.icon(17, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                // Le jour en un mot (« Demain », « Samedi ») : le sélecteur montre la date complète.
                Text(Format.dayWord(day, today: today))
                    .font(Theme.font(.body, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                picker
            }
            HStack(spacing: 0) { picker; Spacer(minLength: 0) }
        }
        .foregroundStyle(Theme.ink)
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(minHeight: 56)
        .background(Capsule().fill(Theme.glass))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
    }

    private var whoOptions: [(PlanTarget, String)] {
        let pair: [(PlanTarget, String)] = [(.me, "Moi"), (.partner, store.partner.name)]
        return isEdit ? pair : [(.both, "Les deux")] + pair
    }

    // MARK: Exercices

    private func exercises(byId: [String: Exercise], helper: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Le bouton passe sous le titre quand la place manque (très grand texte).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    exercisesTitle
                    Spacer(minLength: 8)
                    copyButton(wraps: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    exercisesTitle
                    copyButton(wraps: true)
                }
            }

            if helpMatters && PlanBuilder.helpIsScattered(specs, byId: byId) {
                HelpGroupingBanner(count: specs.filter { byId[$0.exerciseId]?.help == true }.count,
                                   helper: helper) {
                    withAnimation(reduceMotion ? Motion.reduced : Motion.spring) {
                        specs = PlanBuilder.groupingHelp(specs, byId: byId)
                    }
                }
                .transition(.opacity)
            }

            ForEach(Array(specs.enumerated()), id: \.element.id) { i, sp in
                if let ex = byId[sp.exerciseId] {
                    PlanSpecCard(spec: binding(for: sp), exercise: ex, single: singleOwner != nil,
                                 helpLabel: ex.help && helpMatters ? helper.map { "Aide \($0)" } ?? "Aide" : nil,
                                 canMoveUp: i > 0, canMoveDown: i < specs.count - 1,
                                 onMove: { move(i, by: $0) },
                                 onRemove: { remove(sp.id) })
                        .transition(.opacity)
                }
            }

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
    }

    private var exercisesTitle: some View {
        Text("Exercices")
            .font(Theme.font(.title3, weight: .bold))
            .foregroundStyle(Theme.onBackground)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }

    /// Sur une ligne à côté du titre ; sous le titre (très grand texte), le libellé peut passer à la ligne.
    private func copyButton(wraps: Bool) -> some View {
        Button { copying = true } label: {
            HStack(spacing: 6) {
                AppIcon.copy.image.font(Theme.icon(14, weight: .semibold))
                Text("Reprendre une séance")
                    .lineLimit(wraps ? nil : 1)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: wraps)
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, wraps ? 8 : 0)
            .frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.glass))
            .overlay(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                .strokeBorder(Theme.glassBorder, lineWidth: 1))
            .frame(minHeight: Theme.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        if isEdit && existing == nil {
            // Rien à modifier : ne jamais montrer un éditeur qui créerait une nouvelle séance.
            missing = true
            dismiss()
            return
        }
        if let s = existing {
            originalDate = s.date
            day = s.date
            target = s.ownerId == store.meId ? .me : .partner
            title = s.title
            notes = s.notes ?? ""
            let byId = store.exerciseAnyById
            specs = PlanBuilder.specs(from: s).filter { byId[$0.exerciseId] != nil }
        } else if let date {
            day = max(date, Dates.isoDate(Date()))
        }
    }

    /// Lien vers une spec par son identifiant : il reste juste quand la liste bouge ou rétrécit.
    private func binding(for sp: PlanSpec) -> Binding<PlanSpec> {
        Binding(get: { specs.first { $0.id == sp.id } ?? sp },
                set: { new in
                    if let j = specs.firstIndex(where: { $0.id == sp.id }) { specs[j] = new }
                })
    }

    /// « Pour qui » touché : le schéma et les charges deviennent ceux de la nouvelle personne,
    /// jamais ceux de l'autre. (Pas d'`onChange` : le chargement d'une séance ne doit rien refaire.)
    private func retarget(_ new: PlanTarget) {
        guard new != target else { return }
        target = new
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) {
            specs = PlanBuilder.retarget(specs, owner: singleOwner, sessions: store.sessions,
                                         byId: store.exerciseAnyById)
        }
    }

    private func add(_ exercises: [Exercise]) {
        let history = store.sessions
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) {
            specs += exercises.map { PlanBuilder.spec(for: $0, owner: singleOwner, sessions: history) }
        }
    }

    private func copy(from s: Session) {
        specs = PlanBuilder.specs(copying: s, owner: singleOwner, sessions: store.sessions, byId: store.exerciseById)
        if title.trimmingCharacters(in: .whitespaces).isEmpty { title = s.title }
    }

    private func move(_ i: Int, by offset: Int) {
        let j = i + offset
        guard specs.indices.contains(i), specs.indices.contains(j) else { return }
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { specs.swapAt(i, j) }
    }

    private func remove(_ id: String) {
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { specs.removeAll { $0.id == id } }
    }

    private func save() {
        guard !specs.isEmpty else { return }
        // Séance disparue pendant la modification : on n'en crée surtout pas une nouvelle.
        if isEdit && existing == nil {
            dismiss()
            return
        }
        let now = Date()
        let byId = store.exerciseAnyById
        if let s = existing, let owner = singleOwner {
            store.saveSession(PlanBuilder.edited(s, specs: specs, owner: owner, date: day, title: title,
                                                 notes: notes, sessions: store.sessions, byId: byId, now: now))
        } else {
            let built = PlanBuilder.sessions(specs: specs, target: target, me: store.me, partner: store.partner,
                                             date: day, title: title, notes: notes, sessions: store.sessions,
                                             byId: byId, now: now)
            built.forEach(store.saveSession)
        }
        onDone(day)
    }

    private func delete() {
        guard let sessionId, existing != nil else { dismiss(); return }
        store.deleteSession(id: sessionId)
        onDone(day)
    }

    /// Mise au point (DEBUG) : `-plan-add <id,id>` ajoute des exercices, `-plan-copy` ouvre
    /// « Reprendre une séance », `-plan-for me|partner|both` choisit « Pour qui ».
    private func debugLaunchHooks() {
        #if DEBUG
        // Une seule fois par lancement : pas sur les éditeurs ouverts ensuite à la main.
        guard !Self.debugHooksDone else { return }
        Self.debugHooksDone = true
        let args = ProcessInfo.processInfo.arguments
        func value(_ key: String) -> String? {
            args.firstIndex(of: key).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        if !isEdit, let who = value("-plan-for") {
            target = who == "me" ? .me : who == "partner" ? .partner : .both
        }
        if let ids = value("-plan-add") {
            let byId = store.exerciseById
            DispatchQueue.main.async {
                add(ids.split(separator: ",").compactMap { byId[String($0)] })
            }
        }
        if args.contains("-plan-copy") { copying = true }
        #endif
    }
}
