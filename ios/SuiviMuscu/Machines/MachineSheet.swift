import SwiftUI
import PhotosUI
import SuiviCore

/// Fiche d'une machine, en feuille (reprend `MovementSheet` du web, maquette `08-fiche-machine.jpg`) :
/// le réglage, la photo de TA machine à la salle, et le mouvement en deux temps.
struct MachineSheet: View {
    let exercise: Exercise

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var libraryItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var chooseSource = false
    @State private var confirmRemove = false
    @State private var busy = false
    @State private var failed = false

    /// La machine telle qu'elle est enregistrée (la photo change pendant que la fiche est ouverte).
    private var current: Exercise { store.exerciseAnyById[exercise.id] ?? exercise }

    var body: some View {
        let ex = current
        return VStack(spacing: 0) {
            header(ex)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let note = ex.note, !note.isEmpty {
                        (Text("Réglage : ").bold() + Text(note))
                            .font(Theme.font(.subheadline))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.profile1.opacity(0.16)))
                    }
                    photoSection(ex)
                    MovementSection(exerciseId: ex.id)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.sheetBackground.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images, photoLibrary: .shared())
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { encode { await PhotoEncoder.dataURL(from: image) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            libraryItem = nil
            encode {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
                return await PhotoEncoder.dataURL(from: data)
            }
        }
        .task { debugPhoto() }
    }

    private func header(_ ex: Exercise) -> some View {
        HStack(alignment: .top) {
            Text(ex.name)
                .font(Theme.font(.title3, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 11)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
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
        .padding(.bottom, 6)
    }

    // MARK: Photo

    private func photoSection(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Ta machine à la salle")
            if let photo = ex.photo, !photo.isEmpty {
                // Hauteur bornée : une photo en portrait ne repousse pas les boutons hors de l'écran.
                // Même décodeur que les vignettes, à la taille de la fiche (hors du fil principal).
                DataURLImageView(owner: ex.id, dataURL: photo, points: 400, contentMode: .fit) {
                    RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                        .fill(Theme.softFill)
                        .frame(height: 220)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: 300)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Photo de la machine \(ex.name)")
                HStack(spacing: 8) {
                    sourceChoice(actionButton(busy ? "Préparation…" : "Changer", icon: .photo, prominent: false, action: takePhoto))
                        .disabled(busy)
                    actionButton("Retirer", icon: .delete, prominent: false, destructive: true) {
                        confirmRemove = true
                    }
                    .disabled(busy)
                    // Accrochée au bouton : la bulle pointe vers lui.
                    .confirmationDialog("Retirer la photo ?", isPresented: $confirmRemove,
                                        titleVisibility: .visible) {
                        Button("Retirer la photo", role: .destructive) {
                            var e = current
                            e.photo = nil
                            store.saveExercise(e)
                        }
                        Button("Annuler", role: .cancel) {}
                    }
                }
            } else {
                sourceChoice(actionButton(busy ? "Préparation…" : "Prendre la machine en photo", icon: .photo,
                                          prominent: true, action: takePhoto))
                    .disabled(busy)
                Text("Pour la reconnaître du premier coup d’œil.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
            }
            if failed {
                Text("Cette photo n'a pas pu être lue.")
                    .font(Theme.font(.footnote, weight: .medium))
                    .foregroundStyle(Theme.destructive)
            }
        }
    }

    private func actionButton(_ title: String, icon: AppIcon, prominent: Bool, destructive: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon.image.font(Theme.icon(15, weight: .semibold))
                // Passe à la ligne en très grand texte plutôt que d'être coupé.
                Text(title).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .font(Theme.font(.subheadline, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : destructive ? Theme.destructive : Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(prominent ? Theme.ink : Theme.raisedFill))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.ink.opacity(prominent ? 0 : 0.1), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    /// Choix de la source, accroché au bouton qui l'ouvre (la bulle pointe vers lui).
    private func sourceChoice(_ button: some View) -> some View {
        button.confirmationDialog("Photo de la machine", isPresented: $chooseSource, titleVisibility: .hidden) {
            Button("Prendre une photo") { showCamera = true }
            Button("Choisir dans la photothèque") { showLibrary = true }
            Button("Annuler", role: .cancel) {}
        }
    }

    /// Appareil photo ou photothèque au choix ; la photothèque directement sans appareil photo.
    private func takePhoto() {
        failed = false
        if CameraPicker.isAvailable { chooseSource = true } else { showLibrary = true }
    }

    /// Encode la photo hors du fil principal, puis l'enregistre sur la machine telle qu'elle est alors.
    private func encode(_ produce: @escaping @MainActor () async -> String?) {
        busy = true
        failed = false
        Task {
            let url = await produce()
            busy = false
            guard let url else { failed = true; return }
            var e = current
            e.photo = url
            store.saveExercise(e)
        }
    }

    /// Mise au point (DEBUG) : `-machine-photo <fichier>` passe une image par le même chemin
    /// (`PhotoEncoder` puis `saveExercise`) que la photothèque, pour le simulateur.
    private func debugPhoto() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-machine-photo"), i + 1 < args.count,
              current.photo == nil else { return }
        let path = args[i + 1]
        encode {
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            return await PhotoEncoder.dataURL(from: data)
        }
        #endif
    }
}

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(Theme.font(.headline, weight: .bold))
        .accessibilityAddTraits(.isHeader)
}

// MARK: - Le mouvement

/// Départ et arrivée qui alternent toutes les 1,2 s en fondu ; côte à côte, sans minuterie,
/// si « Réduire les animations » est actif.
private struct MovementSection: View {
    let exerciseId: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showEnd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Le mouvement")
            if let urls = Illustrations.urls(for: exerciseId) {
                if reduceMotion {
                    HStack(spacing: 8) {
                        frame(urls.start, label: "Départ")
                        frame(urls.end, label: "Arrivée")
                    }
                } else {
                    ZStack(alignment: .bottomLeading) {
                        frame(urls.start, label: nil).opacity(showEnd ? 0 : 1)
                        frame(urls.end, label: nil).opacity(showEnd ? 1 : 0)
                        // Une étiquette par image, qui sort avant que l'autre n'entre : les deux
                        // textes ne sont jamais dessinés l'un sur l'autre (le tout reste ≤ 350 ms).
                        Text(showEnd ? "Arrivée" : "Départ")
                            .font(Theme.font(.caption, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.raisedFill))
                            .padding(10)
                            .id(showEnd)
                            .transition(.asymmetric(
                                insertion: .opacity.animation(.easeIn(duration: 0.15).delay(0.2)),
                                removal: .opacity.animation(.easeOut(duration: 0.15))))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Mouvement : position de départ puis d’arrivée")
                    // Annulée quand la fiche disparaît : la minuterie s'arrête avec elle.
                    .task {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(1.2))
                            if Task.isCancelled { break }
                            withAnimation(.easeInOut(duration: 0.35)) { showEnd.toggle() }
                        }
                    }
                }
                if Illustrations.isApproximate(exerciseId) {
                    Text("Mouvement proche : ce n’est pas exactement la même machine.")
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Illustrations : free-exercise-db (photos d’origine Bodybuilding.com)")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Pas d’illustration pour cet exercice : prends ta machine en photo.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func frame(_ url: URL, label: String?) -> some View {
        Color.white.opacity(0.6)
            .aspectRatio(4 / 3, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                RemoteImage(url: url) {
                    AppIcon.machines.image
                        .font(Theme.icon(22, weight: .medium))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if let label {
                    Text(label)
                        .font(Theme.font(.caption, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.raisedFill))
                        .padding(8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label.map { "Position \($0 == "Départ" ? "de départ" : "d’arrivée")" } ?? "")
    }
}
