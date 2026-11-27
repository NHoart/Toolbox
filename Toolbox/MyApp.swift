import SwiftUI

@main struct MyApp: App {
    @State private var selectedTab: AppTab = .today

    init() {
        // Widget and Siri write from their own process: forward those changes
        // so the running app syncs them right away.
        WaterStore.startObservingExternalChanges()

        // Start the sync with the other device on the local network.
        LocalSync.shared.start()

        #if os(macOS)
        // Clean up leftovers of interrupted update runs in the background.
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
                Button("Check for updates…") {
                    Task { await UpdateChecker.shared.checkManually() }
                }
            }

            // In the View menu: switch tabs with ⌘1–⌘6 without the mouse.
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
