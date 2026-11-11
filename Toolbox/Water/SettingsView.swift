import SwiftUI
import WidgetKit

struct SettingsView: View {
    @AppStorage(WaterStore.Key.glass, store: WaterStore.defaults) private var glass = 250
    @AppStorage(WaterStore.Key.bottle, store: WaterStore.defaults) private var bottle = 500
    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000

    var body: some View {
        NavigationStack {
            Form {
                Section("Größen") {
                    Stepper("Glas: \(glass) ml", value: $glass, in: 50...1000, step: 50)
                    Stepper("Flasche: \(bottle) ml", value: $bottle, in: 100...3000, step: 50)
                }
                Section("Tagesziel") {
                    Stepper("Ziel: \(goal) ml", value: $goal, in: 500...6000, step: 250)
                }
                Section {
                    Button("Heute zurücksetzen", role: .destructive) { WaterStore.reset() }
                }
            }
            .navigationTitle("Einstellungen")
            .onChange(of: glass) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
            .onChange(of: bottle) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
            .onChange(of: goal) { _, _ in WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}
