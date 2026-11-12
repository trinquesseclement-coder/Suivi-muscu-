import SwiftUI
import SuiviCore

/// Carte « Mon cycle » des Réglages : les séances types dans leur ordre. Toucher une ligne ouvre
/// son éditeur ; « Monter », « Descendre » et « Supprimer » s'appliquent tout de suite.
/// Le cycle est commun aux deux profils.
struct CycleSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Pastille du rang : grandit avec le texte (jusqu'au très grand texte, où elle disparaît).
    @ScaledMetric(relativeTo: .subheadline) private var rankSize: CGFloat = 32

    /// Séance type dont on demande la suppression.
    @State private var removing: CycleTemplate?
    @State private var confirmRestore = false

    var body: some View {
        let templates = store.cycle.templates
        let byId = store.exerciseById
        VStack(alignment: .leading, spacing: 14) {
            Text("Mon cycle")
                .font(Theme.font(.headline, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            if templates.isEmpty {
                emptyState
            } else {
                Text("Vos séances tournent dans cet ordre. L’accueil propose la suivante.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(Array(templates.enumerated()), id: \.element.id) { i, t in
                        if i > 0 {
                            Divider().overlay(Theme.ink.opacity(0.08))
                                .padding(.leading, typeSize.isAccessibilitySize ? 14 : 24 + rankSize)
                        }
                        row(t, rank: i + 1, count: CycleCard.availableCount(t, byId: byId),
                            isFirst: i == 0, isLast: i == templates.count - 1)
                    }
                }
                .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                    .fill(Theme.softFill))
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                addButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .confirmationDialog("Remettre le cycle de départ ?", isPresented: $confirmRestore,
                            titleVisibility: .visible) {
            Button("Remettre") { update { $0 = .standard } }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(Self.keepTogether("Épaules + dos, Pecs + bras et Cardio reviennent dans le cycle."))
        }
    }

    // MARK: Lignes

    private func row(_ t: CycleTemplate, rank: Int, count: Int, isFirst: Bool, isLast: Bool) -> some View {
        // En très grand texte, la place va au nom : le rang passe devant lui et le chevron disparaît
        // (la ligne reste un bouton).
        let compact = typeSize.isAccessibilitySize
        return HStack(spacing: 0) {
            NavigationLink(value: CycleRoute(templateId: t.id)) {
                HStack(spacing: 12) {
                    if !compact {
                        Text("\(rank)")
                            .font(Theme.font(.subheadline, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .frame(width: rankSize, height: rankSize)
                            .background(Circle().fill(Theme.ink.opacity(0.08)))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(compact ? "\(rank). \(t.title)" : t.title)
                            .font(Theme.font(.body, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(Self.countText(count))
                            .font(Theme.font(.footnote))
                            .foregroundStyle(count == 0 ? Theme.destructive : Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if !compact {
                        AppIcon.forward.image
                            .font(Theme.icon(13, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .padding(.leading, compact ? 14 : 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(rank). \(t.title), \(Self.countText(count))")
            .accessibilityHint("Modifier cette séance")
            .accessibilityAddTraits(.isButton)
            optionsMenu(t, isFirst: isFirst, isLast: isLast)
        }
        // Posée sur la ligne : la bulle de confirmation pointe vers la séance à supprimer.
        .confirmationDialog("Supprimer « \(Self.keepTogether(t.title)) » du cycle ?", isPresented: confirmingRemove(t),
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { remove(t) }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les séances déjà faites restent dans l’historique.")
        }
    }

    /// « … » de la ligne, comme celui des exercices de l'éditeur de séance.
    private func optionsMenu(_ t: CycleTemplate, isFirst: Bool, isLast: Bool) -> some View {
        Menu {
            Button { move(t, by: -1) } label: {
                Label { Text("Monter") } icon: { AppIcon.up.image }
            }
            .disabled(isFirst)
            Button { move(t, by: 1) } label: {
                Label { Text("Descendre") } icon: { AppIcon.down.image }
            }
            .disabled(isLast)
            Button(role: .destructive) { removing = t } label: {
                Label { Text("Supprimer") } icon: { AppIcon.delete.image }
            }
        } label: {
            AppIcon.more.image
                .font(Theme.icon(17, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .contentShape(Rectangle())
        }
        .padding(.trailing, 4)
        .accessibilityLabel("Options de \(t.title)")
    }

    private var addButton: some View {
        NavigationLink(value: CycleRoute(templateId: nil)) {
            HStack(spacing: 12) {
                AppIcon.add.image
                    .font(Theme.icon(17, weight: .semibold))
                    .frame(minWidth: 24)
                Text("Ajouter une séance").font(Theme.font(.body, weight: .semibold))
                Spacer(minLength: 8)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: Theme.minTouch)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.softFill))
            .contentShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    /// Cycle vide : l'accueil ne propose plus rien ; on peut repartir d'une séance ou du cycle de départ.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Aucune séance dans le cycle")
                .font(Theme.font(.body, weight: .semibold))
                .foregroundStyle(Theme.ink2)
            VStack(spacing: 8) {
                addButton
                Button { confirmRestore = true } label: {
                    Text("Remettre le cycle de départ")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Actions

    private func confirmingRemove(_ t: CycleTemplate) -> Binding<Bool> {
        Binding(get: { removing?.id == t.id }, set: { if !$0 { removing = nil } })
    }

    private func move(_ t: CycleTemplate, by offset: Int) {
        update { $0.moveTemplate(id: t.id, by: offset) }
    }

    private func remove(_ t: CycleTemplate) {
        update { $0.removeTemplate(id: t.id) }
        removing = nil
    }

    private func update(_ change: (inout Cycle) -> Void) {
        var cycle = store.cycle
        change(&cycle)
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { store.saveCycle(cycle) }
    }

    // MARK: Textes

    /// « Pecs + bras » ne se coupe pas après le « + » dans les bulles de confirmation.
    static func keepTogether(_ text: String) -> String {
        text.replacingOccurrences(of: " + ", with: "\u{00A0}+\u{00A0}")
    }

    /// Exercices disponibles (machines visibles), comme la carte de l'accueil.
    static func countText(_ count: Int) -> String {
        count == 0 ? "Aucun exercice disponible" : CycleCard.exercises(count)
    }
}
