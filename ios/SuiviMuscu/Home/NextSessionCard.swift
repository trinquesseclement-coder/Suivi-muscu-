import SwiftUI
import SuiviCore

/// Bandeau sombre « Prochaine séance » avec le bouton rond orange, ou « Séance libre ».
struct NextSessionCard: View {
    let session: Session?
    /// La séance est commencée : « Séance en cours », le bouton la reprend.
    var live = false
    var zoom: Namespace.ID? = nil
    let onOpen: () -> Void
    let onFree: () -> Void

    var body: some View {
        if let session {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    playBadge
                    VStack(alignment: .leading, spacing: 2) {
                        Text(live ? "Séance en cours"
                             : "Prochaine séance · \(Format.day(session.date, today: Dates.isoDate(Date())).lowercased())")
                            .font(Theme.font(.footnote))
                            .opacity(0.7)
                        Text(session.title)
                            .font(Theme.font(.headline, weight: .semibold))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .modifier(DarkBand())
                .zoomSource("next", in: zoom)
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint(live ? "Reprendre la séance" : "Ouvrir la séance")
        } else {
            HStack(spacing: 12) {
                Text("Aucune séance prévue")
                    .font(Theme.font(.headline, weight: .semibold))
                Spacer(minLength: 0)
                Button(action: onFree) {
                    HStack(spacing: 6) {
                        AppIcon.play.image.font(.system(size: 13, weight: .bold))
                        Text("Séance libre").font(Theme.font(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: Theme.minTouch)
                    .background(Capsule().fill(Theme.orange))
                    .zoomSource("free", in: zoom)
                }
                .buttonStyle(PressableStyle())
            }
            .modifier(DarkBand())
        }
    }

    private var playBadge: some View {
        AppIcon.play.image
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Theme.orange))
            .frame(width: Theme.minTouch, height: Theme.minTouch)
            .accessibilityHidden(true)
    }
}

/// Séance en cours de l'autre (comme sur le web) : prénom, pastille « En cours », avancement.
struct PartnerLiveCard: View {
    let partner: Profile
    let session: Session
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProfileAvatar(profile: partner, size: 22)
                    Text(partner.name).font(Theme.font(.subheadline, weight: .semibold))
                    LivePill()
                    Spacer(minLength: 0)
                }
                Text("\(session.title) · \(Stats.startedItemCount(session))/\(session.items.count) exercices")
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch, alignment: .leading)
            .padding(14)
            .glassCard()
        }
        .buttonStyle(PressableStyle())
    }
}

/// Pastille verte « En cours ».
struct LivePill: View {
    var body: some View {
        Text("En cours")
            .font(Theme.font(.caption, weight: .medium))
            .foregroundStyle(Color(hex: 0x00632F))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.success.opacity(0.22)))
    }
}

private struct DarkBand: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.ink))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }
}

/// Léger enfoncement au toucher, sans jamais bloquer l'action.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? Motion.reduced : Motion.spring, value: configuration.isPressed)
    }
}
