import SwiftUI
import WidgetKit

struct SettingsView: View {
    @AppStorage(WaterStore.Key.glass, store: WaterStore.defaults) private var glass = 200
    @AppStorage(WaterStore.Key.bottle, store: WaterStore.defaults) private var bottle = 500
    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000

    @ObservedObject private var lan = LocalSync.shared
    @State private var lanEnabled = LocalSync.shared.isEnabled

    @AppStorage(UpdateChecker.automaticChecksKey) private var automaticUpdateChecks = true
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var manualUpdate: UpdateInfo?
    @State private var manualStatus: String?

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
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("z. B. Familie", text: syncNameBinding)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    if lanEnabled && !lan.hasSyncName {
                        Text("Ohne Namen ist der Abgleich aus.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Sync im WLAN", isOn: $lanEnabled)
                    if lanEnabled {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(lanStatus)
                                .foregroundStyle(.secondary)
                        }
                        Button("Jetzt suchen") { LocalSync.shared.syncNow() }
                            .disabled(!lan.hasSyncName)
                    }
                } header: {
                    Text("Lokales Netzwerk")
                } footer: {
                    Text("Gleicht Wassertracker und Zähler direkt mit deinen anderen Geräten im selben WLAN ab – ohne Server. Trage auf allen Geräten denselben Namen ein; nur Geräte mit diesem Namen gleichen sich ab.")
                }
                #if os(macOS)
                Section {
                    Toggle("Automatisch nach Updates suchen", isOn: $automaticUpdateChecks)
                    Button {
                        Task { await checkNow() }
                    } label: {
                        HStack(spacing: 6) {
                            if updates.isChecking {
                                ProgressView().controlSize(.small)
                                Text("Suche nach Updates…")
                            } else {
                                Text("Jetzt nach Updates suchen")
                            }
                        }
                    }
                    .disabled(updates.isChecking)
                    if let manualStatus {
                        Text(manualStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Updates")
                } footer: {
                    Text("Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht.")
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
        .sheet(item: $manualUpdate) { update in
            UpdateSheet(update: update)
        }
    }

    private func checkNow() async {
        manualStatus = nil
        switch await UpdateChecker.shared.checkForUpdates() {
        case .update(let update):
            manualUpdate = update
        case .upToDate:
            manualStatus = "Du benutzt bereits die neueste Version (\(UpdateChecker.currentVersion))."
        case .failed(let message):
            manualStatus = "Die Update-Prüfung ist fehlgeschlagen: \(message)"
        }
    }

    private var syncNameBinding: Binding<String> {
        Binding(get: { lan.syncName }, set: { LocalSync.shared.setSyncName($0) })
    }

    private var lanStatus: String {
        guard lanEnabled else { return "Aus" }
        guard lan.hasSyncName else { return "Name fehlt" }
        if lan.peerCount == 1 { return "Verbunden mit 1 Gerät" }
        if lan.peerCount > 1 { return "Verbunden mit \(lan.peerCount) Geräten" }
        if let date = lan.lastSync {
            return "Zuletzt \(date.formatted(date: .omitted, time: .shortened))"
        }
        return lan.isSearching ? "Suche im WLAN…" : "Kein Gerät gefunden"
    }
}
