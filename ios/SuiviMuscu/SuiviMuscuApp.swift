import SwiftUI
import SuiviCore

@main
struct SuiviMuscuApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0x64 / 255, green: 0x74 / 255, blue: 0x6F / 255),
                             Color(red: 0x46 / 255, green: 0x53 / 255, blue: 0x4F / 255)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                Text("Suivi Muscu")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
