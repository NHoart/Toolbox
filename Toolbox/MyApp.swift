import SwiftUI

@main struct MyApp: App {
    @State private var selectedTab: AppTab = .today

    init() {
        // Abgleich mit dem anderen Gerät im lokalen WLAN starten.
        LocalSync.shared.start()

        #if os(macOS)
        // Reste abgebrochener Update-Läufe im Hintergrund entfernen.
        Task.detached(priority: .utility) {
            UpdateInstaller.cleanUpStaleData()
        }
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            rootView
        }
        .defaultSize(width: 1120, height: 680)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Nach Updates suchen…") {
                    Task { await UpdateChecker.shared.checkManually() }
                }
            }

            // Im Menü „Ansicht“: Tabs ohne Maus über ⌘1–⌘6 wechseln.
            CommandGroup(before: .sidebar) {
                ForEach(AppTab.allCases) { tab in
                    Button(tab.title) {
                        selectedTab = tab
                    }
                    .keyboardShortcut(tab.shortcut, modifiers: .command)
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
        ContentView(selection: $selectedTab)
            .modifier(UpdateCheckModifier())
    }
}
