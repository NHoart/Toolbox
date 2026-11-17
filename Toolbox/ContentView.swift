import SwiftUI
import WidgetKit

/// All tools of the app as tabs – including the digit for the Mac keyboard shortcut.
enum AppTab: CaseIterable, Identifiable {
    case today
    case history
    case units
    case counter
    case download
    case energy

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .today: "Today"
        case .history: "History"
        case .units: "Units"
        case .counter: "Counter"
        case .download: "Download time"
        case .energy: "Power usage"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "drop.fill"
        case .history: "chart.bar.fill"
        case .units: "arrow.left.arrow.right"
        case .counter: "plus.circle"
        case .download: "arrow.down.circle"
        case .energy: "bolt.fill"
        }
    }

    #if os(macOS)
    /// Key for the ⌘1–⌘6 shortcut in the Mac app.
    var shortcut: KeyEquivalent {
        switch self {
        case .today: "1"
        case .history: "2"
        case .units: "3"
        case .counter: "4"
        case .download: "5"
        case .energy: "6"
        }
    }
    #endif
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var selection: AppTab

    var body: some View {
        #if os(macOS)
        // The Mac app gets its own interface with a sidebar in the Liquid Glass look.
        // iPhone, iPad and Vision Pro keep the tab bar unchanged.
        MacRootView(selection: $selection)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    LocalSync.shared.syncNow()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        #else
        TabView {
            Tab("Today", systemImage: "drop.fill") {
                WaterTodayView()
            }

            Tab("History", systemImage: "chart.bar.fill") {
                HistoryView()
            }

            Tab("Units", systemImage: "arrow.left.arrow.right") {
                UnitConverterView()
            }

            Tab("Counter", systemImage: "plus.circle") {
                CounterView()
            }

            Tab("Download time", systemImage: "arrow.down.circle") {
                DownloadTimeView()
            }

            Tab("Power usage", systemImage: "bolt.fill") {
                EnergyCostView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Sync with the other device when the app opens and refresh the widget –
            // needed for entries made in the background (for example via Siri or the widget).
            if phase == .active {
                LocalSync.shared.syncNow()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
    }
}

#Preview {
    ContentView(selection: .constant(.today))
}

#if os(macOS)
/// Gear in the toolbar that opens the settings as a sheet – Mac app only.
private struct MacSettingsToolbar: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}
#endif

extension View {
    /// Puts the tabs on the Mac on the left as a sidebar. iPhone, iPad and
    /// Vision Pro keep their tab bar – the style stays unchanged there.
    @ViewBuilder
    func macSidebarTabs() -> some View {
        #if os(macOS)
        tabViewStyle(.sidebarAdaptable)
        #else
        self
        #endif
    }

    /// Shows the settings gear next to the tab bar. Only the Mac app gets it,
    /// iPhone, iPad and Vision Pro stay unchanged.
    @ViewBuilder
    func macSettingsToolbar() -> some View {
        #if os(macOS)
        modifier(MacSettingsToolbar())
        #else
        self
        #endif
    }
}
