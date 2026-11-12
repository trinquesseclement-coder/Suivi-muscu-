import SwiftUI
import SuiviCore

/// Fil « Activité récente », comme le web (`SessionCard.tsx`).
struct SessionFeed: View {
    let sessions: [Session]
    /// Branché à la tâche 8 (ouverture de la séance) ; sans lui, les cartes ne réagissent pas.
    var onTap: ((Session) -> Void)? = nil

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activité récente")
                .font(Theme.font(.title3, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
                .accessibilityAddTraits(.isHeader)

            if sessions.isEmpty {
                Text("Pas encore de séance. La première, c’est la plus importante.")
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassCard()
            } else {
                let byId = store.exerciseById
                let all = store.sessions
                let today = Dates.isoDate(Date())
                let now = Date()
                ForEach(sessions) { s in
                    let card = SessionFeedCard(
                        session: s,
                        owner: store.profiles.first { $0.id == s.ownerId },
                        isMe: s.ownerId == store.meId,
                        byId: byId,
                        prs: Stats.sessionPRs(all, s).count,
                        helped: Rules.needsHelp(store.profiles, id: s.ownerId),
                        today: today,
                        now: now)
                    if let onTap {
                        Button { onTap(s) } label: { card }.buttonStyle(PressableStyle())
                    } else {
                        card
                    }
                }
            }
        }
    }
}

struct SessionFeedCard: View {
    let session: Session
    let owner: Profile?
    let isMe: Bool
    let byId: [String: Exercise]
    let prs: Int
    let helped: Bool
    let today: String
    let now: Date

    var body: some View {
        let s = session
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let owner { ProfileAvatar(profile: owner, size: 22) }
                Text(owner?.name ?? "?").font(Theme.font(.subheadline, weight: .semibold))
                if isMe {
                    Text("(toi)").font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2)
                }
                Spacer(minLength: 4)
                Text(Format.day(s.date, today: today))
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(s.title).font(Theme.font(.headline, weight: .semibold))
                Spacer(minLength: 0)
                if Rules.isLive(s, now: now) { LivePill() }
                if s.status == .planned { Pill(text: "Prévue") }
            }
            .padding(.top, 2)
            if !names.isEmpty {
                Text(names)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FlowLayout(spacing: 6) { pills }
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var names: String {
        let list = session.items.compactMap { byId[$0.exerciseId]?.name }
        let shown = list.prefix(3).joined(separator: " · ")
        return session.items.count > 3 ? shown + " +\(session.items.count - 3)" : shown
    }

    @ViewBuilder private var pills: some View {
        let s = session
        if s.status == .done {
            let sets = Stats.sessionSetCount(s)
            let ton = Stats.sessionTonnage(s)
            let cardio = Stats.sessionCardioMinutes(s, byId: byId)
            if sets > 0 { Pill(text: "\(sets) séries") }
            if ton > 0 { Pill(text: Format.tonnage(ton)) }
            if cardio > 0 { Pill(text: "\(cardio) min cardio") }
            if let rpe = s.rpe { Pill(text: "Ressenti \(rpe)/10") }
        } else {
            Pill(text: "\(s.items.count) exercices")
        }
        let helpCount = helped ? s.items.filter { byId[$0.exerciseId]?.help == true }.count : 0
        if helpCount > 0 {
            Pill(text: "\(helpCount) avec aide", icon: .help, fill: Theme.profile2.opacity(0.16))
        }
        if prs > 0 {
            Pill(text: "\(prs) record\(prs > 1 ? "s" : "")", icon: .trophy,
                 fill: Color(hex: 0xFAB219, opacity: 0.3))
        }
    }
}

/// Pastille du fil (séries, tonnage, ressenti…).
struct Pill: View {
    let text: String
    var icon: AppIcon? = nil
    var fill: Color? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { icon.image.font(.system(size: 11, weight: .semibold)) }
            Text(text).monospacedDigit()
        }
        .font(Theme.font(.caption, weight: .medium))
        .foregroundStyle(fill == nil ? Theme.ink2 : Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(fill ?? Color.white.opacity(0.6)))
        .overlay(Capsule().strokeBorder(fill == nil ? Color.white.opacity(0.7) : .clear, lineWidth: 1))
        .lineLimit(1)
    }
}

/// Retour à la ligne des pastilles quand la largeur manque.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let extra = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if extra > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(i)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
