import SwiftUI

/// Carte d'un graphique du tableau de charge : titre, sous-titre, réglages éventuels, puis le graphique
/// ou son tableau (« Voir le tableau » / « Voir le graphique », l'alternative non visuelle).
/// Sans données, un état vide dessiné remplace le graphique et le bouton.
struct ChartCard<Accessory: View, Content: View, Table: View>: View {
    let title: String
    var subtitle: String? = nil
    /// État vide (icône, phrase) à la place du graphique ; `nil` quand il y a des données.
    var empty: (icon: AppIcon, text: String)? = nil
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content
    @ViewBuilder var table: Table

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showTable: Bool

    init(title: String, subtitle: String? = nil, empty: (icon: AppIcon, text: String)? = nil,
         startsWithTable: Bool = false,
         @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content,
         @ViewBuilder table: () -> Table) {
        self.title = title; self.subtitle = subtitle; self.empty = empty
        self.accessory = accessory(); self.content = content(); self.table = table()
        _showTable = State(initialValue: startsWithTable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.font(.headline, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            accessory
            if let empty {
                ChartEmpty(icon: empty.icon, text: empty.text)
            } else {
                // Le bouton (48 pt de haut) colle au graphique ; la marge basse de la carte est réduite
                // d'autant, sa zone tactile faisant déjà office de marge.
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if showTable { table } else { content }
                    }
                    .transition(.opacity)
                    toggleButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, empty == nil ? 6 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var toggleButton: some View {
        Button {
            withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { showTable.toggle() }
        } label: {
            Label {
                Text(showTable ? "Voir le graphique" : "Voir le tableau")
            } icon: {
                (showTable ? AppIcon.load : AppIcon.table).image
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(minHeight: Theme.minTouch, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ChartCard where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, empty: (icon: AppIcon, text: String)? = nil,
         startsWithTable: Bool = false,
         @ViewBuilder content: () -> Content,
         @ViewBuilder table: () -> Table) {
        self.init(title: title, subtitle: subtitle, empty: empty, startsWithTable: startsWithTable,
                  accessory: { EmptyView() }, content: content, table: table)
    }
}

/// État vide d'une carte : une icône et une phrase, pas d'axes vides.
struct ChartEmpty: View {
    let icon: AppIcon
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            icon.image
                .font(Theme.icon(17, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.softFill))
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.font(.subheadline, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
            .fill(Theme.softFill.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }
}

/// Tableau simple d'un graphique : une colonne de libellés puis des colonnes de valeurs.
/// Quand les colonnes ne tiennent plus (très grand texte), chaque ligne s'empile.
struct DataTable: View {
    let head: [String]
    let rows: [[String]]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid
            stacked
        }
    }

    private var grid: some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(head.enumerated()), id: \.offset) { i, h in
                    Text(h)
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink2)
                        .gridColumnAlignment(i == 0 ? .leading : .trailing)
                        .frame(minWidth: i == 0 ? 72 : nil, alignment: i == 0 ? .leading : .trailing)
                }
            }
            .padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { i, cell in
                        Text(cell)
                            .font(Theme.font(.subheadline, weight: i == 0 ? .regular : .semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            // La première colonne prend la place qui reste : le tableau occupe la carte.
                            .frame(maxWidth: i == 0 ? .infinity : nil, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(row))
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { n, row in
                if n > 0 { Divider() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.first ?? "").font(Theme.font(.subheadline, weight: .semibold))
                    ForEach(1..<row.count, id: \.self) { i in
                        Text("\(head[safe: i] ?? "") : \(row[i])")
                            .font(Theme.font(.subheadline))
                            .foregroundStyle(Theme.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(row))
            }
        }
    }

    /// « 9 nov., Séances 2, Heures 1h50 ».
    private func spoken(_ row: [String]) -> String {
        row.enumerated().map { i, cell in i == 0 ? cell : "\(head[safe: i] ?? "") \(cell)" }
            .joined(separator: ", ")
    }
}

fileprivate extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Pastille de couleur et prénom, pour la légende quand deux personnes sont affichées.
struct LegendDot: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name).font(Theme.font(.footnote, weight: .semibold))
        }
    }
}

/// Animation d'entrée d'un graphique, lancée quand il devient vraiment visible (son haut au-dessus
/// de la barre d'onglets, voir `probeOffset`), une fois par jeu de données (`key` : personne, mesure,
/// machine, valeurs). Si les données changent pendant qu'il est visible, l'animation repart aussitôt ;
/// hors de l'écran, le graphique est remis à son état de départ (`reset`) et rejouera en revenant.
/// Une animation interrompue (sortie de l'écran, changement rapide) n'est pas comptée comme jouée :
/// le graphique finit toujours sur ses vraies valeurs.
private struct ChartEntrance<Key: Equatable>: ViewModifier {
    let key: Key
    let reset: @MainActor () -> Void
    let play: @MainActor (_ reduceMotion: Bool) async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = false
    @State private var played: Key?

    private struct Trigger: Equatable {
        let key: Key
        let onScreen: Bool
    }

    /// La page défile sous la barre d'onglets flottante (environ 100 pt avec son fondu) : un graphique
    /// « dans » la vue défilante peut encore être caché derrière. On observe donc un point invisible
    /// placé à cette distance sous le haut du graphique : quand il entre dans la vue, les 50 premiers
    /// points du graphique sont au-dessus de la barre. Il y a toujours au moins cette hauteur de contenu
    /// sous le haut d'un graphique (cartes « Progression » et « Records » en dessous), donc le point
    /// finit toujours par entrer.
    private static var probeOffset: CGFloat { 150 }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .onScrollVisibilityChange(threshold: 1) { onScreen = $0 }
                    .padding(.top, Self.probeOffset)
                    .fixedSize()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onChange(of: key) {
                if !onScreen { played = nil; reset() }
            }
            .task(id: Trigger(key: key, onScreen: onScreen)) {
                guard onScreen, played != key else { return }
                await play(reduceMotion)
                if !Task.isCancelled { played = key }
            }
    }
}

extension View {
    /// Voir `ChartEntrance` : partagé par les barres de semaines, les muscles et la courbe.
    func chartEntrance<Key: Equatable>(key: Key, reset: @escaping @MainActor () -> Void,
                                       play: @escaping @MainActor (_ reduceMotion: Bool) async -> Void) -> some View {
        modifier(ChartEntrance(key: key, reset: reset, play: play))
    }
}
