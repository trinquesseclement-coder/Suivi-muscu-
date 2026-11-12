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
        let byId = store.exerciseAnyById
        let today = Dates.isoDate(Date())
        let helper = Rules.helperName(store.profiles)

        ScrollView {
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
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
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
                // Le jour seul (« Demain », « Samedi ») : le sélecteur montre déjà la date complète.
                Text(Format.day(day, today: today).split(separator: " ").first.map(String.init) ?? "")
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
                    copyButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    exercisesTitle
                    copyButton
                }
            }

            if helpMatters && PlanBuilder.helpIsScattered(specs, byId: byId) {
                groupingBanner(byId: byId, helper: helper)
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

    private var copyButton: some View {
        Button { copying = true } label: {
            HStack(spacing: 6) {
                AppIcon.copy.image.font(Theme.icon(14, weight: .semibold))
                Text("Reprendre une séance").lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Capsule().fill(Theme.glass))
            .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
            .frame(minHeight: Theme.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func groupingBanner(byId: [String: Exercise], helper: String?) -> some View {
        let count = specs.filter { byId[$0.exerciseId]?.help == true }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                AppIcon.help.image.font(Theme.icon(16, weight: .semibold))
                (Text("\(count) exercices avec aide").bold()
                    + Text(helper.map { " (\($0) charge les disques) : les enchaîner évite de l’attendre." }
                        ?? " : les enchaîner évite d’attendre."))
                    .font(Theme.font(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                withAnimation(reduceMotion ? Motion.reduced : Motion.spring) {
                    specs = PlanBuilder.groupingHelp(specs, byId: byId)
                }
            } label: {
                Text(helper.map { "Regrouper les exercices avec \($0)" } ?? "Regrouper les exercices avec aide")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(Color(hex: 0xF6E6DC)))
        .foregroundStyle(Theme.ink)
    }

    // MARK: Barre du bas

    private var bottomBar: some View {
        let label = isEdit ? "Enregistrer" : target == .both ? "Planifier pour les deux" : "Planifier"
        let enabled = !specs.isEmpty
        return HStack(spacing: 8) {
            if isEdit {
                Button { confirmDelete = true } label: {
                    Text("Supprimer")
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xB3261E))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Color.white.opacity(0.9)))
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                // Accrochée au bouton : la bulle de confirmation pointe vers lui.
                .confirmationDialog("Supprimer cette séance prévue ?", isPresented: $confirmDelete,
                                    titleVisibility: .visible) {
                    Button("Supprimer la séance", role: .destructive, action: delete)
                    Button("Annuler", role: .cancel) {}
                }
            }
            Button(action: save) {
                Text(label)
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Theme.ink.opacity(enabled ? 1 : 0.35)))
            }
            .buttonStyle(PressableStyle())
            .disabled(!enabled)
            .accessibilityHint(enabled ? "" : "Ajoute au moins un exercice")
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

    private func load() {
        guard !loaded else { return }
        loaded = true
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
        guard let sessionId else { return }
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

/// « Pour qui » : contrôle segmenté de 48 pt, même style que le choix du schéma.
private struct WhoPicker: View {
    let options: [(PlanTarget, String)]
    @Binding var selection: PlanTarget

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, title in
                let active = selection == value
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .font(Theme.font(.body, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(active ? Color.white : Theme.ink2)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        .background(Capsule().fill(active ? Theme.ink : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.glass))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .motion(Motion.spring, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
