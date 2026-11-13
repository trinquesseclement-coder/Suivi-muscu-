import SwiftUI
import SuiviCore
import UniformTypeIdentifiers

/// Le fichier de sauvegarde à partager : il n'est construit (et écrit dans le dossier temporaire)
/// qu'au moment où l'on envoie vraiment, pas à chaque affichage des Réglages.
private struct BackupExport: Transferable {
    let store: AppStore
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            let data = await item.store.exportData()
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sauvegarde", isDirectory: true)
            // Jamais de suppression du dossier : le système peut appeler ce bloc deux fois (aperçu,
            // puis destination) et l'un effacerait le fichier que l'autre vient d'écrire. On écrase
            // le fichier du jour, d'un coup (`.atomic`).
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(item.fileName)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Carte « Sauvegarde » des Réglages : exporter toutes les données dans un fichier JSON, en importer un.
struct BackupSection: View {
    @Environment(AppStore.self) private var store

    /// Un fichier lu et décodé, en attente de la confirmation de l'utilisateur.
    private struct Pending: Identifiable {
        let id = UUID()
        let data: Data
        let content: String
    }

    private struct Message: Equatable {
        let id = UUID()
        let isError: Bool
        let title: String?
        let text: String
    }

    private enum Phase { case idle, reading, importing }

    @State private var phase = Phase.idle
    @State private var showImporter = false
    @State private var pending: Pending?
    @State private var message: Message?
    #if DEBUG
    @State private var launched = false
    #endif

    private static let notABackup = "Ce fichier n'est pas une sauvegarde Suivi Muscu."
    private static let locked = "Les données de ce téléphone n'ont pas pu être lues : l'import est bloqué pour ne rien écraser."
    private static let notSaved = "L'import n'a pas pu être enregistré sur ce téléphone."
    private static let replacesNote = "Les réglages et photos de machines du fichier remplacent ceux de ce téléphone. Les séances plus récentes sur ce téléphone sont gardées."

    private var busy: Bool { phase != .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sauvegarde")
                .font(Theme.font(.headline, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Fais un export de temps en temps : il contient toutes vos séances, les réglages des machines et vos photos.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                exportRow
                importRow
            }
            if let message { messageView(message) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .motion(Motion.spring, value: message)
        .sensoryFeedback(trigger: message) { _, new in
            guard let new else { return nil }
            return new.isError ? .error : .success
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): read(url)
            case .failure: show(error: Self.notABackup)
            }
        }
        .confirmationDialog("Importer cette sauvegarde ?", isPresented: confirming,
                            titleVisibility: .visible, presenting: pending) { p in
            Button("Importer") { runImport(p) }
            Button("Annuler", role: .cancel) {}
        } message: { p in
            Text("Ce fichier contient \(p.content). \(Self.replacesNote)")
        }
        #if DEBUG
        // Mise au point : `-import-file <chemin>` lance le même parcours sans passer par Fichiers.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard !launched, let i = args.firstIndex(of: "-import-file"), i + 1 < args.count else { return }
            launched = true
            read(URL(fileURLWithPath: args[i + 1]))
        }
        #endif
    }

    // MARK: Lignes

    private var exportRow: some View {
        ShareLink(item: BackupExport(store: store, fileName: BackupText.fileName(today: Dates.isoDate(Date()))),
                  preview: SharePreview(BackupText.fileName(today: Dates.isoDate(Date())))) {
            rowLabel(icon: AppIcon.export.image, title: "Exporter")
        }
        .buttonStyle(PressableStyle())
        .disabled(busy)
        .accessibilityHint("Envoie le fichier par AirDrop, Fichiers ou WhatsApp")
    }

    private var importRow: some View {
        Button { showImporter = true } label: {
            if busy {
                rowLabel(icon: ProgressView().tint(Theme.ink),
                         title: phase == .reading ? "Lecture du fichier…" : "Import en cours…")
            } else {
                rowLabel(icon: AppIcon.importFile.image, title: "Importer")
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(busy)
        .accessibilityHint("Choisir un fichier de sauvegarde .json")
    }

    private func rowLabel<Icon: View>(icon: Icon, title: String) -> some View {
        HStack(spacing: 12) {
            icon
                .font(Theme.icon(17, weight: .semibold))
                .frame(minWidth: 24)
            Text(title).font(Theme.font(.body, weight: .semibold))
            Spacer(minLength: 8)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: Theme.minTouch)
        .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.softFill))
        .contentShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
    }

    private func messageView(_ m: Message) -> some View {
        let tint = m.isError ? Theme.destructive : Theme.success
        return HStack(alignment: .top, spacing: 10) {
            (m.isError ? AppIcon.warning : AppIcon.check).image
                .font(Theme.icon(15, weight: .bold))
                .foregroundStyle(tint)
                .frame(minWidth: 22, minHeight: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                if let title = m.title {
                    Text(title).font(Theme.font(.subheadline, weight: .semibold))
                }
                Text(m.text).font(Theme.font(.subheadline))
            }
            .foregroundStyle(m.isError ? Theme.destructive : Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Fond clair : le texte rouge y garde un contraste d'au moins 4,5:1.
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .transition(.opacity)
    }

    // MARK: Import

    /// La confirmation est affichée tant qu'un fichier lu attend ; l'écarter l'abandonne.
    private var confirming: Binding<Bool> {
        Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })
    }

    private func show(error text: String) {
        phase = .idle
        message = Message(isError: true, title: nil, text: text)
        AccessibilityNotification.Announcement(text).post()
    }

    /// Lecture et décodage hors du fil principal (un fichier avec photos pèse plusieurs Mo).
    private func read(_ url: URL) {
        guard phase == .idle else { return }
        message = nil
        phase = .reading
        Task {
            let loaded = await Task.detached(priority: .userInitiated) { Self.load(url) }.value
            phase = .idle
            if let loaded { pending = loaded } else { show(error: Self.notABackup) }
        }
    }

    private nonisolated static func load(_ url: URL) -> Pending? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let content = try? Backup.decode(data) else { return nil }
        return Pending(data: data, content: BackupText.content(content))
    }

    private func runImport(_ p: Pending) {
        guard phase == .idle else { return }
        phase = .importing
        Task {
            // Laisse le temps d'afficher « Import en cours… » avant le travail sur le fil principal.
            try? await Task.sleep(for: .milliseconds(80))
            defer { phase = .idle }
            do {
                let summary = try store.importData(p.data)
                if store.lastSaveError != nil {
                    show(error: Self.notSaved)
                } else {
                    let text = BackupText.summary(summary)
                    message = Message(isError: false, title: "Import terminé", text: text)
                    AccessibilityNotification.Announcement("Import terminé. \(text)").post()
                }
            } catch BackupError.storeLocked {
                show(error: Self.locked)
            } catch {
                show(error: Self.notABackup)
            }
        }
    }
}
