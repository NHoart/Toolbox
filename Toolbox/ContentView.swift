import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Heute", systemImage: "drop.fill") {
                WaterTodayView()
            }

            Tab("Verlauf", systemImage: "chart.bar.fill") {
                HistoryView()
            }

            Tab("Einstellungen", systemImage: "gearshape") {
                SettingsView()
            }

            Tab("Einheiten", systemImage: "arrow.left.arrow.right") {
                UnitConverterView()
            }

            Tab("Downloadzeit", systemImage: "arrow.down.circle") {
                DownloadTimeView()
            }

            Tab("Stromverbrauch", systemImage: "bolt.fill") {
                EnergyCostView()
            }

            Tab("Zähler", systemImage: "plus.circle") {
                CounterView()
            }
        }
    }
}

#Preview {
    ContentView()
}
