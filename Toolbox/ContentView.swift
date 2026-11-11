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
    }
}

#Preview {
    ContentView()
}
