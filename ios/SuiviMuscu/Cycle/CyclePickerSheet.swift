import SwiftUI
import SuiviCore

/// « Une autre séance » : les séances types du cycle. En toucher une la choisit pour la carte de
/// l'accueil, pour cette fois ; le cycle ne change pas.
struct CyclePickerSheet: View {
    let cycle: Cycle
    /// La séance type que le cycle propose (marquée « Suivante »).
    let nextId: String?
    /// Séance type choisie (`nil` = la suivante).
    @Binding var selection: String?
    let onEditCycle: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let byId = store.exerciseById
        let chosen = selection ?? nextId
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(Array(cycle.templates.enumerated()), id: \.element.id) { i, t in
                            if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)) }
                            row(t, count: CycleCard.availableCount(t, byId: byId), chosen: t.id == chosen)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Theme.softFill))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

                    editButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.sheetBackground.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Une autre séance")
                .font(Theme.font(.title3, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                AppIcon.close.image
                    .font(Theme.icon(17, weight: .semibold))
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

    private func row(_ t: CycleTemplate, count: Int, chosen: Bool) -> some View {
        let isNext = t.id == nextId
        return Button {
            selection = isNext ? nil : t.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(t.title)
                            .font(Theme.font(.body, weight: .semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if isNext { nextTag }
                    }
                    Text(CycleCard.exercises(count))
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 0)
                AppIcon.check.image
                    .font(Theme.icon(16, weight: .bold))
                    .foregroundStyle(Theme.profile1)
                    .opacity(chosen ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t.title)\(isNext ? ", suivante" : ""), \(CycleCard.exercises(count))")
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    private var nextTag: some View {
        Text("Suivante")
            .font(Theme.font(.caption, weight: .semibold))
            .foregroundStyle(Color(hex: 0x00594A))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.profile1.opacity(0.16)))
    }

    private var editButton: some View {
        Button {
            onEditCycle()
            dismiss()
        } label: {
            HStack(spacing: 10) {
                AppIcon.rename.image
                    .font(Theme.icon(15, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Modifier le cycle")
                    .font(Theme.font(.body, weight: .semibold))
                Spacer(minLength: 0)
                AppIcon.forward.image
                    .font(Theme.icon(13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(Theme.softFill))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
