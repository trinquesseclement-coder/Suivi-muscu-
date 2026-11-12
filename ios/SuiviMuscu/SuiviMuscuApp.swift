import SwiftUI
import SuiviCore

@main
struct SuiviMuscuApp: App {
    @State private var store: AppStore

    init() {
        // Vignettes des exercices gardées sur le téléphone, pour les revoir hors ligne.
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("suivi.json")
        let args = ProcessInfo.processInfo.arguments
        let store = args.contains("-demo")
            ? AppStore.demo(fileURL: url, today: Dates.isoDate(Date()), now: Date())
            : AppStore(fileURL: url)
        #if DEBUG
        // Voir l'appli comme Jules tant que les Réglages n'existent pas (tâche 10).
        if args.contains("-as-jules") { store.switchProfile(to: AppStore.julesId) }
        #endif
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
