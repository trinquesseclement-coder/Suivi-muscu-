import SwiftUI
import SuiviCore

@main
struct SuiviMuscuApp: App {
    @State private var store: AppStore

    init() {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("suivi.json")
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            _store = State(initialValue: AppStore.demo(fileURL: url, today: Dates.isoDate(Date()), now: Date()))
        } else {
            _store = State(initialValue: AppStore(fileURL: url))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
        }
    }
}
