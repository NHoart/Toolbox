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
    @State private var manualStatus: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            Form {
                Section("Sizes") {
                    Stepper("Glass: \(glass) ml", value: $glass, in: 50...1000, step: 50)
                    Stepper("Bottle: \(bottle) ml", value: $bottle, in: 100...3000, step: 50)
                }
                Section("Daily goal") {
                    Stepper("Goal: \(goal) ml", value: $goal, in: 500...6000, step: 250)
                }
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("e.g. Family", text: syncNameBinding)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                    if lanEnabled && !lan.hasSyncName {
                        Text("Sync is off without a name.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Sync over Wi-Fi", isOn: $lanEnabled)
                    if lanEnabled {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text(lanStatus)
                                .foregroundStyle(.secondary)
                        }
                        Button("Search now") { LocalSync.shared.syncNow() }
                            .disabled(!lan.hasSyncName)
                    }
                } header: {
                    Text("Local network")
                } footer: {
                    Text("Syncs the water tracker and counter directly with your other devices on the same Wi-Fi network – no server. Enter the same name on all devices; only devices with that name sync.")
                }
                #if os(macOS)
                Section {
                    Toggle("Check for updates automatically", isOn: $automaticUpdateChecks)
                    Button {
                        Task { await checkNow() }
                    } label: {
                        HStack(spacing: 6) {
                            if updates.isChecking {
                                ProgressView().controlSize(.small)
                                Text("Checking for updates…")
                            } else {
                                Text("Check for updates now")
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
                    Text("Checks GitHub at most once a day at launch for a newer version.")
                }
                #endif
                Section {
                    Button("Reset today", role: .destructive) { WaterStore.reset() }
                }
            }
            .navigationTitle("Settings")
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
            manualStatus = "You are already using the latest version (\(UpdateChecker.currentVersion))."
        case .failed(let message):
            manualStatus = "The update check failed: \(message)"
        }
    }

    private var syncNameBinding: Binding<String> {
        Binding(get: { lan.syncName }, set: { LocalSync.shared.setSyncName($0) })
    }

    private var lanStatus: LocalizedStringKey {
        guard lanEnabled else { return "Off" }
        guard lan.hasSyncName else { return "Name missing" }
        if lan.peerCount == 1 { return "Connected to 1 device" }
        if lan.peerCount > 1 { return "Connected to \(lan.peerCount) devices" }
        if let date = lan.lastSync {
            return "Last \(date.formatted(date: .omitted, time: .shortened))"
        }
        return lan.isSearching ? "Searching the Wi-Fi network…" : "No device found"
    }
}
