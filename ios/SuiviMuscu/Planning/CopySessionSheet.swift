import SwiftUI
import SuiviCore

/// « Reprendre une séance » : les 30 dernières séances non vides, des deux profils
/// (reprend la feuille de `PlanEditor.tsx`). Toucher une séance la renvoie à l'éditeur.
struct CopySessionSheet: View {
    let onPick: (Session) -> Void

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let list = Array(store.sessions.filter { !$0.items.isEmpty }.prefix(30))
        let today = Dates.isoDate(Date())
        return VStack(spacing: 0) {
            header
            ScrollView {
                if list.isEmpty {
                    Text("Aucune séance à reprendre.")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                            if i > 0 { Divider().overlay(Theme.ink.opacity(0.08)) }
                            row(s, today: today)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Color.white.opacity(0.6)))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(hex: 0xECF1EF).ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text("Reprendre une séance")
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

    private func row(_ s: Session, today: String) -> some View {
        let owner = store.profiles.first { $0.id == s.ownerId }
        let count = s.items.count
        let detail = "\(owner?.name ?? "?") · \(Format.day(s.date, today: today)) · \(count) exercice\(count > 1 ? "s" : "")"
        return Button {
            onPick(s)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                if let owner { ProfileAvatar(profile: owner, size: 32) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(s.title)
                        .font(Theme.font(.body, weight: .semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                AppIcon.forward.image
                    .font(Theme.icon(13, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(s.title), \(detail)")
        .accessibilityAddTraits(.isButton)
    }
}
