import SwiftUI

@main struct MyApp: App {
    init() {
        // Abgleich mit dem anderen Gerät im lokalen WLAN starten.
        LocalSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
