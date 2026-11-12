import SwiftUI
import UIKit
import SuiviCore

/// La séance en direct (reprend `appli/src/pages/SessionPage.tsx`).
/// Chaque toucher est enregistré tout de suite sur le téléphone : rien n'est perdu si l'appli est tuée.
struct SessionView: View {
    let sessionId: String
    /// Séance libre tout juste créée par « + » : supprimée si on la quitte vide.
    var fresh = false
    /// Ouvre une autre séance à la place de celle-ci (après « Copier dans mes séances »).
    var onReplace: (String) -> Void = { _ in }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var finishing = false
    @State private var finished = false
    @State private var leaving = false
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var removing: SessionItem?
    /// Exercices dont le record a déjà été fêté (ou était déjà battu à l'ouverture).
    @State private var celebrated: Set<String>?
    /// Incrémenté à chaque nouveau record : rejoue `RecordBurst` et la vibration forte.
    @State private var recordBurst = 0
    @State private var rest = RestTimerModel()
    @State private var picking = false
    /// Durée du repos en secondes (le réglage arrive en tâche 10).
    @AppStorage("rest.seconds") private var restSeconds = 90

    var body: some View {
        Group {
            if let s = store.session(sessionId) {
                content(s)
            } else if leaving {
                Color.clear
            } else {
                notFound
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            rest.stop()
            discardIfEmpty()
        }
    }

    // MARK: Contenu

    private func content(_ s: Session) -> some View {
        let editable = s.ownerId == store.meId
        let byId = store.exerciseById
        let all = store.sessions
        let bests = Stats.previousBests(all, s)
        let prs = Stats.sessionPRs(all, s)
        let helper = Rules.helperName(store.profiles)
        let helped = Rules.needsHelp(store.profiles, id: s.ownerId)
        let progress = Rules.hasProgress(s)
        let keepAwake = editable && Rules.isLive(s)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(s, editable: editable)

                if let notes = s.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.font(.subheadline))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard()
                }

                // Affiché dès l'ouverture de sa propre séance : rien ne se décale sous le doigt
                // quand la première série est validée.
                if !s.items.isEmpty && (editable || (s.status == .done && progress)) {
                    tiles(s, byId: byId)
                }

                ForEach(s.items) { it in
                    if let ex = byId[it.exerciseId] {
                        ExerciseCard(
                            item: it,
                            exercise: ex,
                            last: Stats.lastPerformance(all, ownerId: s.ownerId, exerciseId: ex.id, excluding: s.id),
                            editable: editable,
                            helpLabel: ex.help && helped ? helper.map { "Aide \($0)" } ?? "Aide" : nil,
                            recordBest: bests[ex.id] ?? 0,
                            onChange: { transform, started in updateItem(it.id, started: started, transform) },
                            onRemove: { askRemove(it) },
                            onSetValidated: onSetValidated)
                    }
                }

                if s.items.isEmpty {
                    Text(editable ? "Ajoute ton premier exercice." : "Séance vide.")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassCard()
                }

                if editable {
                    Button(action: addExercise) {
                        HStack(spacing: 8) {
                            AppIcon.add.image.font(.system(size: 17, weight: .bold))
                            Text("Ajouter un exercice")
                        }
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(Theme.glass))
                        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if editable { bottomBar(s, progress: progress) }
        }
        .sheet(isPresented: $picking) {
            ExercisePicker { exercises in addExercises(exercises) }
        }
        .sheet(isPresented: $finishing, onDismiss: {
            if finished { leaving = true; dismiss() }
        }) {
            FinishSheet(session: s) { duration, rpe, notes in finish(duration: duration, rpe: rpe, notes: notes) }
        }
        .alert("Renommer la séance", isPresented: $renaming) {
            TextField("Nom", text: $newTitle)
            Button("Enregistrer") { rename() }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(removeTitle(byId), isPresented: removingBinding, titleVisibility: .visible,
                            presenting: removing) { it in
            Button("Retirer", role: .destructive) { removeItem(it.id) }
            Button("Annuler", role: .cancel) {}
        }
        .onAppear { if celebrated == nil { celebrated = Set(prs) } }
        .onChange(of: prs) { _, now in celebrate(now) }
        .onChange(of: keepAwake, initial: true) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
        // Au centre de l'écran, par-dessus tout, sans capter les touchers.
        .overlay { RecordBurst(trigger: recordBurst) }
        .sensoryFeedback(.impact(weight: .heavy), trigger: recordBurst)
    }

    // MARK: En-tête

    private func header(_ s: Session, editable: Bool) -> some View {
        let owner = store.profiles.first { $0.id == s.ownerId }
        return HStack(alignment: .top, spacing: 10) {
            circleButton(.back, label: "Retour") { dismiss() }
            VStack(alignment: .leading, spacing: 6) {
                Text(s.title)
                    .font(Theme.font(.title2, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 8) {
                    HStack(spacing: 6) {
                        if let owner { ProfileAvatar(profile: owner, size: 22) }
                        Text(owner?.name ?? "?").font(Theme.font(.subheadline, weight: .semibold))
                        if editable { Text("(toi)").font(Theme.font(.subheadline)) }
                    }
                    Text(Format.day(s.date, today: Dates.isoDate(Date())))
                        .font(Theme.font(.subheadline))
                        .opacity(0.8)
                }
                // Ligne réservée : « Prévue » devient « En cours » sans décaler l'écran.
                Group {
                    if Rules.isLive(s) {
                        LivePill()
                    } else if s.status == .planned {
                        Pill(text: "Prévue")
                    }
                }
                .frame(height: 26)
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            optionsMenu(s, editable: editable)
        }
        .foregroundStyle(.white)
        .padding(.bottom, 4)
    }

    private func circleButton(_ icon: AppIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circle(icon)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private func circle(_ icon: AppIcon) -> some View {
        icon.image
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 52, height: 52)
            .background(Circle().fill(Theme.glass))
            .overlay(Circle().strokeBorder(Theme.glassBorder, lineWidth: 1))
    }

    private func optionsMenu(_ s: Session, editable: Bool) -> some View {
        Menu {
            if editable {
                Button {
                    newTitle = s.title
                    renaming = true
                } label: { Label { Text("Renommer") } icon: { AppIcon.rename.image } }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label { Text("Supprimer") } icon: { AppIcon.delete.image }
                }
            } else {
                Button { copyToMe(s) } label: {
                    Label { Text("Copier dans mes séances") } icon: { AppIcon.copy.image }
                }
            }
        } label: {
            circle(.more)
        }
        .accessibilityLabel("Options")
        .confirmationDialog("Supprimer cette séance ? C’est définitif.", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Supprimer la séance", role: .destructive) { deleteSession() }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: Bilan

    private func tiles(_ s: Session, byId: [String: Exercise]) -> some View {
        let done = Stats.startedItemCount(s)
        let sets = Stats.sessionSetCount(s)
        let cardio = Stats.sessionCardioMinutes(s, byId: byId)
        return HStack(spacing: 8) {
            tile("\(done)/\(s.items.count)", "exercices", value: Double(done))
            tile(Format.tonnage(Stats.sessionTonnage(s)), "\(sets) série\(sets > 1 ? "s" : "")",
                 value: Stats.sessionTonnage(s))
            tile("\(cardio) min", "cardio", value: Double(cardio))
        }
        .padding(8)
        .glassCard()
    }

    private func tile(_ big: String, _ small: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(big)
                .font(Theme.font(.title3, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(small).font(Theme.font(.caption)).foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .fill(Color.white.opacity(0.6)))
        .accessibilityElement(children: .combine)
    }

    // MARK: Barre du bas

    private func bottomBar(_ s: Session, progress: Bool) -> some View {
        HStack(spacing: 10) {
            if rest.isActive {
                RestTimer(model: rest)
                    .transition(.opacity)
            }
            Button {
                if progress { finishing = true } else { dismiss() }
            } label: {
                Text(progress ? (s.endedAt == nil ? "Terminer" : "Modifier le bilan") : "Fermer")
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(progress ? Color.white : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(progress ? Theme.ink : Color.white.opacity(0.8)))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(6)
        .background(Capsule().fill(Theme.glass))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .motion(Motion.spring, value: rest.isActive)
    }

    private var notFound: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                circleButton(.back, label: "Retour") { dismiss() }
                Text("Séance introuvable").font(Theme.font(.title2, weight: .bold))
            }
            Text("Elle a peut-être été supprimée.").font(Theme.font(.subheadline)).opacity(0.8)
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: Repos et ajout d'exercices

    /// Une série vient d'être validée : le repos repart de zéro.
    private func onSetValidated() { rest.start(seconds: restSeconds) }

    private func addExercise() { picking = true }

    /// Chaque exercice choisi est préparé depuis l'historique du propriétaire et son schéma par défaut
    /// (`Rules.newItem`), dans l'ordre de sélection, puis la séance est enregistrée une seule fois.
    private func addExercises(_ exercises: [Exercise]) {
        guard let s = store.session(sessionId), !exercises.isEmpty else { return }
        let owner = store.profiles.first { $0.id == s.ownerId } ?? store.me
        let scheme = Rules.defaultScheme(for: owner)
        let history = store.sessions
        let items = exercises.map { Rules.newItem($0, ownerId: s.ownerId, sessions: history, scheme: scheme) }
        update { $0.items.append(contentsOf: items) }
    }

    // MARK: Écriture

    /// Relit la séance dans le stockage, applique la modification et l'enregistre en une seule écriture.
    private func update(_ change: (inout Session) -> Void) {
        guard var s = store.session(sessionId) else { return }
        change(&s)
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { store.saveSession(s) }
    }

    private func updateItem(_ itemId: String, started: Bool, _ transform: (SessionItem) -> SessionItem) {
        update { s in
            guard let i = s.items.firstIndex(where: { $0.id == itemId }) else { return }
            s.items[i] = transform(s.items[i])
            if started { Self.markStarted(&s) }
        }
    }

    /// Même effet que `AppStore.startOrResume`, appliqué à la copie qu'on enregistre
    /// (une seule écriture, pas deux copies concurrentes). Comme le web, une séance prévue
    /// pour plus tard et commencée aujourd'hui passe à aujourd'hui.
    static func markStarted(_ s: inout Session, now: Date = Date()) {
        if s.startedAt == nil { s.startedAt = AppStore.timestamp(now) }
        s.status = .done
        let today = Dates.isoDate(now)
        if s.date > today { s.date = today }
    }

    private func finish(duration: Int, rpe: Int?, notes: String?) {
        update { s in
            s.durationMin = duration
            s.rpe = rpe
            s.notes = notes
            if s.endedAt == nil { s.endedAt = AppStore.timestamp(Date()) }
            s.status = .done
        }
        finished = true
        finishing = false
    }

    private func rename() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        update { $0.title = title }
    }

    private func deleteSession() {
        leaving = true
        store.deleteSession(id: sessionId)
        dismiss()
    }

    /// Comme `copyToMe` du web : une séance prévue pour moi aujourd'hui avec les mêmes exercices,
    /// chacun préparé depuis **mon** historique et mon schéma par défaut (`Rules.newItem`),
    /// jamais avec les charges de l'autre.
    private func copyToMe(_ s: Session) {
        let now = Date()
        let me = store.meId
        let byId = store.exerciseById
        let history = store.sessions
        let scheme = Rules.defaultScheme(for: store.me)
        let copy = Session(
            id: UUID().uuidString.lowercased(), ownerId: me, createdBy: me, date: Dates.isoDate(now),
            title: s.title, status: .planned,
            items: s.items.compactMap { it in
                byId[it.exerciseId].map { Rules.newItem($0, ownerId: me, sessions: history, scheme: scheme) }
            },
            updatedAt: AppStore.timestamp(now))
        store.saveSession(copy)
        onReplace(copy.id)
    }

    private func askRemove(_ it: SessionItem) {
        if it.sets.contains(where: \.done) || it.cardio?.done == true {
            removing = it
        } else {
            removeItem(it.id)
        }
    }

    private func removeItem(_ id: String) {
        update { $0.items.removeAll { $0.id == id } }
    }

    private var removingBinding: Binding<Bool> {
        Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
    }

    private func removeTitle(_ byId: [String: Exercise]) -> String {
        let name = removing.flatMap { byId[$0.exerciseId]?.name } ?? "cet exercice"
        return "Retirer \(name) de la séance ?"
    }

    /// Séance libre abandonnée sans exercice : on ne la garde pas (comme le web).
    private func discardIfEmpty() {
        guard fresh, let s = store.session(sessionId), s.status == .planned, s.items.isEmpty else { return }
        store.deleteSession(id: s.id)
    }

    // MARK: Records

    private func celebrate(_ prs: [String]) {
        guard var seen = celebrated else { celebrated = Set(prs); return }
        let fresh = prs.filter { !seen.contains($0) }
        guard !fresh.isEmpty else { return }
        seen.formUnion(fresh)
        celebrated = seen
        recordBurst += 1
        AccessibilityNotification.Announcement("Nouveau record").post()
    }
}
