import SwiftUI
import UIKit
import SuiviCore

/// Une carte d'exercice de la séance (reprend `ExerciseBlock` du web).
struct ExerciseCard: View {
    let item: SessionItem
    let exercise: Exercise
    /// Dernière fois où le propriétaire de la séance a fait l'exercice.
    let last: (session: Session, item: SessionItem)?
    let editable: Bool
    /// « Aide Jules » quand l'exercice demande de l'aide à la personne de la séance, sinon `nil`.
    let helpLabel: String?
    /// Meilleur 1RM estimé avant la séance (0 si aucun) : sert à marquer les séries record.
    let recordBest: Double
    /// Modifie l'item ; `started` = une série (ou le cardio) vient d'être validée.
    let onChange: (_ transform: (SessionItem) -> SessionItem, _ started: Bool) -> Void
    let onRemove: () -> Void
    /// Une série vient d'être validée (le minuteur de repos s'y branchera, tâche 9).
    let onSetValidated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
                .padding(.horizontal, 12)
                .padding(.top, 12)
            if let note = exercise.note, !note.isEmpty {
                (Text("Réglage : ").bold() + Text(note))
                    .font(Theme.font(.subheadline))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.profile1.opacity(0.16)))
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }
            if let lastText {
                Text(lastText)
                    .font(Theme.font(.footnote))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
            }
            if exercise.kind == .cardio {
                CardioBlock(cardio: item.cardio ?? CardioEntry(minutes: 15, done: false),
                            editable: editable) { cardio, started in
                    onChange({ var x = $0; x.cardio = cardio; return x }, started)
                }
                .padding(12)
            } else {
                if editable {
                    SchemeToggle(scheme: item.scheme ?? .classic) { scheme in
                        onChange({ Rules.switchScheme($0, to: scheme) }, false)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                }
                sets
                    .padding(.top, 10)
                if editable { footer }
                else { Spacer().frame(height: 8) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Les lignes vertes des séries restent dans les coins arrondis de la carte.
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            if helpLabel != nil {
                // Liseré orange à gauche, comme le web, pour les exercices avec aide.
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(.clear)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.orange).frame(width: 5) }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .glassCard()
    }

    // MARK: En-tête

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            ExerciseThumb(exercise: exercise)
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(Theme.font(.headline, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 6) { badges }
            }
            Spacer(minLength: 0)
            if editable {
                Button(action: onRemove) {
                    AppIcon.close.image
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, -8)
                .padding(.trailing, -10)
                .accessibilityLabel("Retirer \(exercise.name)")
            }
        }
    }

    @ViewBuilder private var badges: some View {
        switch exercise.posture {
        case .fauteuil: Pill(text: "Fauteuil", icon: .wheelchair, fill: Theme.profile1.opacity(0.18))
        case .transfert: Pill(text: "Transfert")
        case .debout: Pill(text: "Debout")
        }
        if let helpLabel {
            Pill(text: helpLabel, icon: .help, fill: Theme.profile2.opacity(0.16))
        }
    }

    /// « Dernière fois (6 nov.) : 20×12 · 25×10 · 30×8 · 20×12 ».
    private var lastText: String? {
        guard let last else { return nil }
        let detail: String
        if exercise.kind == .cardio {
            let c = last.item.cardio
            var parts = ["\(c?.minutes ?? 0) min"]
            if let km = c?.distanceKm, km > 0 { parts.append("\(Format.number(km)) km") }
            if let lvl = c?.level, lvl > 0 { parts.append("niv. \(lvl)") }
            detail = parts.joined(separator: " · ")
        } else {
            detail = Stats.doneSets(last.item).map { "\(Format.number($0.kg))×\($0.reps)" }.joined(separator: " · ")
        }
        return "Dernière fois (\(Format.dayMonth(last.session.date))) : \(detail)"
    }

    // MARK: Séries

    private var sets: some View {
        VStack(spacing: 0) {
            ForEach(Array(item.sets.enumerated()), id: \.offset) { i, entry in
                Divider().overlay(Theme.ink.opacity(0.06))
                SetRow(index: i, entry: entry, step: exercise.step ?? 2.5, editable: editable,
                       isRecord: Stats.isRecord(entry, best: recordBest),
                       onKg: { kg in onChange({ Rules.setKg($0, index: i, kg: kg) }, false) },
                       onReps: { reps in onChange({ Rules.setReps($0, index: i, reps: reps) }, false) },
                       onToggle: { toggle(i) })
            }
            Divider().overlay(Theme.ink.opacity(0.06))
        }
    }

    private func toggle(_ i: Int) {
        guard item.sets.indices.contains(i) else { return }
        let done = !item.sets[i].done
        onChange({ x in
            var x = x
            if x.sets.indices.contains(i) { x.sets[i].done = done }
            return x
        }, done)
        if done { onSetValidated() }
    }

    private var footer: some View {
        let lastDone = item.sets.last?.done ?? true
        return HStack(spacing: 8) {
            Button {
                onChange({ x in
                    var x = x
                    let prev = x.sets.last ?? SetEntry(kg: 0, reps: 10, done: false)
                    x.sets.append(SetEntry(kg: prev.kg, reps: prev.reps, done: false))
                    return x
                }, false)
            } label: {
                HStack(spacing: 6) {
                    AppIcon.add.image.font(.system(size: 15, weight: .bold))
                    Text("Série")
                }
                .font(Theme.font(.subheadline, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(minHeight: Theme.minTouch)
                .background(Capsule().fill(Color.white.opacity(0.7)))
                .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Ajouter une série")

            if !item.sets.isEmpty {
                Button {
                    onChange({ x in
                        var x = x
                        if x.sets.last?.done == false { x.sets.removeLast() }
                        return x
                    }, false)
                } label: {
                    Text("Retirer la dernière")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(minHeight: Theme.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(lastDone)
                .opacity(lastDone ? 0.4 : 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Pyramide / Classique

/// Sélecteur compact du schéma de répétitions d'un exercice.
struct SchemeToggle: View {
    let scheme: RepScheme
    let onChange: (RepScheme) -> Void

    var body: some View {
        HStack(spacing: 4) {
            option(.pyramid, "Pyramide", icon: .pyramid)
            option(.classic, "Classique", icon: .classic)
        }
        .padding(3)
        .background(Capsule().fill(Theme.ink.opacity(0.07)))
        .fixedSize()
        .motion(Motion.spring, value: scheme)
    }

    private func option(_ value: RepScheme, _ title: String, icon: AppIcon) -> some View {
        let active = scheme == value
        return Button {
            if !active { onChange(value) }
        } label: {
            HStack(spacing: 5) {
                icon.image.font(.system(size: 11, weight: .bold))
                Text(title)
            }
            .font(Theme.font(.footnote, weight: .semibold))
            .foregroundStyle(active ? Color.white : Theme.ink2)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(active ? Theme.ink : Color.clear))
            .frame(minHeight: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Schéma \(title)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

// MARK: - Cardio

/// Durée, distance, niveau, calories et validation du cardio (comme `CardioBlock` du web).
struct CardioBlock: View {
    let cardio: CardioEntry
    let editable: Bool
    let onChange: (_ cardio: CardioEntry, _ started: Bool) -> Void

    var body: some View {
        if editable {
            VStack(spacing: 10) {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        field("Durée", unit: "min", step: 1, value: Double(cardio.minutes)) { v in
                            var c = cardio; c.minutes = Int(v.rounded()); onChange(c, false)
                        }
                        field("Distance", unit: "km", step: 0.1, value: cardio.distanceKm ?? 0) { v in
                            var c = cardio; c.distanceKm = v > 0 ? v : nil; onChange(c, false)
                        }
                    }
                    GridRow {
                        field("Niveau / résistance", unit: "", step: 1, value: Double(cardio.level ?? 0)) { v in
                            var c = cardio; c.level = v > 0 ? Int(v.rounded()) : nil; onChange(c, false)
                        }
                        field("Calories", unit: "kcal", step: 10, value: Double(cardio.calories ?? 0)) { v in
                            var c = cardio; c.calories = v > 0 ? Int(v.rounded()) : nil; onChange(c, false)
                        }
                    }
                }
                Button {
                    var c = cardio
                    c.done.toggle()
                    onChange(c, c.done)
                } label: {
                    HStack(spacing: 8) {
                        AppIcon.check.image.font(.system(size: 17, weight: .bold))
                        Text(cardio.done ? "Fait" : "Valider le cardio")
                    }
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(cardio.done ? Color.white : Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(cardio.done ? Theme.ink : Color.white.opacity(0.7)))
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.success, trigger: cardio.done) { _, done in done }
                .accessibilityAddTraits(cardio.done ? .isSelected : [])
            }
        } else {
            Text(readOnlyText)
                .font(Theme.font(.subheadline))
                .monospacedDigit()
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var readOnlyText: String {
        var text = "\(cardio.done ? "Fait" : "Prévu") : \(cardio.minutes) min"
        if let km = cardio.distanceKm, km > 0 { text += " · \(Format.number(km)) km" }
        if let lvl = cardio.level, lvl > 0 { text += " · niveau \(lvl)" }
        if let kcal = cardio.calories, kcal > 0 { text += " · \(kcal) kcal" }
        return text
    }

    private func field(_ title: String, unit: String, step: Double, value: Double,
                       set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.font(.caption, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityHidden(true)
            Stepper(label: title, unit: unit, step: step, value: Binding(get: { value }, set: { set($0) }))
        }
    }
}

// MARK: - Vignette

/// Vignette 52 pt : photo de la machine si elle existe, sinon l'illustration de départ.
struct ExerciseThumb: View {
    let exercise: Exercise

    var body: some View {
        Group {
            if let photo = AvatarDecoder.image(from: exercise.photo) {
                Image(uiImage: photo).resizable().scaledToFill()
            } else if let url = Illustrations.urls(for: exercise.id)?.start {
                RemoteImage(url: url) { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        (exercise.kind == .cardio ? AppIcon.cardio : AppIcon.machines).image
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Theme.ink2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.6))
    }
}

/// Image distante lue d'abord dans `URLCache` (même périmée), pour s'afficher hors ligne.
/// `AsyncImage` ne permet pas de choisir la politique de cache : une fois les 5 minutes de
/// GitHub passées, il retournerait sur le réseau et échouerait sans connexion.
struct RemoteImage<Placeholder: View>: View {
    let url: URL
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: UIImage?

    init(url: URL, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder
        _image = State(initialValue: ImageMemory.cache.object(forKey: url as NSURL))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            let loaded = await ImageMemory.load(url)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}

@MainActor
enum ImageMemory {
    static let cache = NSCache<NSURL, UIImage>()

    static func load(_ url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
