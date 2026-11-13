import SwiftUI
import WidgetKit

/// Alle Werkzeuge der App als Tabs – inklusive der Ziffer für das Mac-Tastenkürzel.
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
        case .today: "Heute"
        case .history: "Verlauf"
        case .units: "Einheiten"
        case .counter: "Zähler"
        case .download: "Downloadzeit"
        case .energy: "Stromverbrauch"
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
    /// Taste für das Kürzel ⌘1–⌘6 in der Mac-App.
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
        TabView(selection: $selection) {
            Tab("Heute", systemImage: "drop.fill", value: .today) {
                WaterTodayView()
            }

            Tab("Verlauf", systemImage: "chart.bar.fill", value: .history) {
                HistoryView()
            }

            Tab("Einheiten", systemImage: "arrow.left.arrow.right", value: .units) {
                UnitConverterView()
            }

            Tab("Zähler", systemImage: "plus.circle", value: .counter) {
                CounterView()
            }

            Tab("Downloadzeit", systemImage: "arrow.down.circle", value: .download) {
                DownloadTimeView()
            }

            Tab("Stromverbrauch", systemImage: "bolt.fill", value: .energy) {
                EnergyCostView()
            }
        }
        .macSidebarTabs()
        .onChange(of: scenePhase) { _, phase in
            // Beim Öffnen der App mit dem anderen Gerät abgleichen und das Widget nachziehen –
            // nötig für Einträge, die im Hintergrund (z. B. per Siri oder Widget) gemacht wurden.
            if phase == .active {
                LocalSync.shared.syncNow()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

#Preview {
    ContentView(selection: .constant(.today))
}

#if os(macOS)
/// Zahnrad in der Toolbar, das die Einstellungen als Sheet öffnet – nur in der Mac-App.
private struct MacSettingsToolbar: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Einstellungen")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
    }
}
#endif

extension View {
    /// Stellt die Tabs auf dem Mac als Seitenleiste an die linke Seite. iPhone, iPad und
    /// Vision Pro behalten ihre Tab-Leiste – dort bleibt der Stil unverändert.
    @ViewBuilder
    func macSidebarTabs() -> some View {
        #if os(macOS)
        tabViewStyle(.sidebarAdaptable)
        #else
        self
        #endif
    }

    /// Zeigt das Einstellungen-Zahnrad neben der Tableiste. Nur die Mac-App bekommt es,
    /// iPhone, iPad und Vision Pro bleiben unverändert.
    @ViewBuilder
    func macSettingsToolbar() -> some View {
        #if os(macOS)
        modifier(MacSettingsToolbar())
        #else
        self
        #endif
    }
}
