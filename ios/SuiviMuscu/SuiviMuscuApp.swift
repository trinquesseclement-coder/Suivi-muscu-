import SwiftUI
import SuiviCore
import UserNotifications

@main
struct SuiviMuscuApp: App {
    @State private var store: AppStore
    /// Garde le délégué en vie (le centre de notifications ne le retient pas).
    private static let notificationDelegate = NotificationDelegate()

    init() {
        // Vignettes des exercices gardées sur le téléphone, pour les revoir hors ligne.
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("suivi.json")
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        // `-demo` n'existe qu'en DEBUG et n'écrit que dans `suivi-demo.json` : jamais dans les vraies données.
        // `-demo-keep` rouvre ce fichier tel quel (vérifier qu'un changement survit à une relance).
        let demoURL = AppStore.demoFileURL(besides: url)
        let store = args.contains("-demo-keep") ? AppStore(fileURL: demoURL)
            : args.contains("-demo")
            ? AppStore.demo(fileURL: demoURL, today: Dates.isoDate(Date()), now: Date())
            : AppStore(fileURL: url)
        // Mise au point : voir l'appli comme Jules sans passer par les Réglages.
        if args.contains("-as-jules") { store.switchProfile(to: AppStore.julesId) }
        #else
        let store = AppStore(fileURL: url)
        #endif
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
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
