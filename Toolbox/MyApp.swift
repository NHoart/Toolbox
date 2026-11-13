import SwiftUI

@main struct MyApp: App {
    init() {
        // Abgleich mit dem anderen Gerät im lokalen WLAN starten.
        LocalSync.shared.start()
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            rootView
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen…") {
                    Task { await UpdateChecker.shared.checkManually() }
                }
            }
        }
        #else
        WindowGroup {
            rootView
        }
        #endif
    }

    private var rootView: some View {
        ContentView()
            .modifier(UpdateCheckModifier())
    }
}
