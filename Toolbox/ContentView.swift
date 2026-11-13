import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Heute", systemImage: "drop.fill") {
                WaterTodayView()
            }

            Tab("Verlauf", systemImage: "chart.bar.fill") {
                HistoryView()
            }

            Tab("Einheiten", systemImage: "arrow.left.arrow.right") {
                UnitConverterView()
            }

            Tab("Zähler", systemImage: "plus.circle") {
                CounterView()
            }

            Tab("Downloadzeit", systemImage: "arrow.down.circle") {
                DownloadTimeView()
            }

            Tab("Stromverbrauch", systemImage: "bolt.fill") {
                EnergyCostView()
            }
        }
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
    ContentView()
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
