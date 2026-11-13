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
