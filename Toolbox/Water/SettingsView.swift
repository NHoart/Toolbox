import SwiftUI
import WidgetKit

struct SettingsView: View {
    @AppStorage(WaterStore.Key.glass, store: WaterStore.defaults) private var glass = 250
    @AppStorage(WaterStore.Key.bottle, store: WaterStore.defaults) private var bottle = 500
    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000

    @ObservedObject private var lan = LocalSync.shared
    @State private var lanEnabled = LocalSync.shared.isEnabled

    @AppStorage(UpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true

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
                    Toggle("Sync im WLAN", isOn: $lanEnabled)
                    if lanEnabled {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(lanStatus)
                                .foregroundStyle(.secondary)
                        }
                        Button("Jetzt suchen") { LocalSync.shared.syncNow() }
                    }
                } header: {
                    Text("Lokales Netzwerk")
                } footer: {
                    Text("Gleicht Wassertracker und Zähler direkt mit deinem anderen Gerät im selben WLAN ab – ohne Server. Öffne die App auf beiden Geräten, sie finden sich automatisch.")
                }
                #if os(macOS)
                Section {
                    Toggle("Automatisch nach Updates suchen", isOn: $automaticUpdateChecks)
                } header: {
                    Text("Updates")
                } footer: {
                    Text("Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht. Manuell über „Toolbox → Nach Updates suchen…“.")
                }
                #endif
                Section {
                    Button("Heute zurücksetzen", role: .destructive) { WaterStore.reset() }
                }
            }
            .navigationTitle("Einstellungen")
            .onChange(of: glass) { _, _ in WaterStore.markChanged() }
            .onChange(of: bottle) { _, _ in WaterStore.markChanged() }
            .onChange(of: goal) { _, _ in WaterStore.markChanged() }
            .onChange(of: lanEnabled) { _, enabled in LocalSync.shared.setEnabled(enabled) }
        }
    }

    private var lanStatus: String {
        guard lanEnabled else { return "Aus" }
        if lan.peerCount == 1 { return "Verbunden mit 1 Gerät" }
        if lan.peerCount > 1 { return "Verbunden mit \(lan.peerCount) Geräten" }
        if let date = lan.lastSync {
            return "Zuletzt \(date.formatted(date: .omitted, time: .shortened))"
        }
        return lan.isSearching ? "Suche im WLAN…" : "Kein Gerät gefunden"
    }
}
