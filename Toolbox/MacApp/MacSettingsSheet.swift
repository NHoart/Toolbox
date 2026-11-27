#if os(macOS)
import SwiftUI

/// Settings of the Mac app in the glass look.
/// The iPhone version keeps its own `SettingsView`.
struct MacSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    sizesCard
                    languageCard
                    networkCard
                    updatesCard
                    resetCard
                }
                .padding(.bottom, 4)
            }

            footer
        }
        .padding(22)
        .frame(width: 540, height: 680)
        .background {
            MacBackdrop()
                .ignoresSafeArea()
        }
        .sheet(item: $manualUpdate) { update in
            UpdateSheet(update: update)
        }
        .onChange(of: glass) { _, _ in WaterStore.markSizesChanged() }
        .onChange(of: bottle) { _, _ in WaterStore.markSizesChanged() }
        .onChange(of: goal) { _, _ in WaterStore.markSizesChanged() }
        .onChange(of: lanEnabled) { _, enabled in LocalSync.shared.setEnabled(enabled) }
    }

    // MARK: - Header and footer

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Water, network and updates")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
    }

    private var footer: some View {
        HStack {
            Text("Version \(UpdateChecker.currentVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.glassProminent)
                .tint(MacTheme.accent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Karten

    private var sizesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            MacCardHeader(title: "AMOUNTS", systemImage: "drop.fill", tint: MacTheme.accent)

            stepperRow("Glass", value: $glass, range: 50...1000, step: 50)
            divider
            stepperRow("Bottle", value: $bottle, range: 100...3000, step: 50)
            divider
            stepperRow("Daily goal", value: $goal, range: 500...6000, step: 250)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "LANGUAGE", systemImage: "globe", tint: MacTheme.cyan)

            HStack(spacing: 10) {
                Text("Language")
                    .font(.system(size: 12.5, weight: .medium))

                Spacer()

                Text(appLanguageName)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Button("Open System Settings") { openLanguageSettings() }
                    .buttonStyle(.glass)
            }

            Text("Set the language for Toolbox under Applications.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "LOCAL NETWORK", systemImage: "wifi", tint: MacTheme.cyan)

            HStack(spacing: 10) {
                Text("Name")
                    .font(.system(size: 12.5, weight: .medium))

                Spacer()

                TextField("e.g. Family", text: syncNameBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(width: 210)
                    .autocorrectionDisabled()
            }

            Toggle("Sync over Wi-Fi", isOn: $lanEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12.5, weight: .medium))

            if lanEnabled {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(lanStatus)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 11.5))

                Button("Search now") { LocalSync.shared.syncNow() }
                    .buttonStyle(.glass)
                    .disabled(!lan.hasSyncName)
            }

            if lanEnabled && !lan.hasSyncName {
                Text("Sync is off without a name. Enter the same name on all devices.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Syncs the water tracker and counter directly with your other devices on the same Wi-Fi network – no server. Only devices with the same name sync with each other.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "UPDATES", systemImage: "arrow.triangle.2.circlepath", tint: MacTheme.violet)

            Toggle("Check for updates automatically", isOn: $automaticUpdateChecks)
                .toggleStyle(.switch)
                .font(.system(size: 12.5, weight: .medium))

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
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.glass)
            .disabled(updates.isChecking)

            if let manualStatus {
                Text(manualStatus)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Checks GitHub at most once a day at launch for a newer version.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var resetCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reset today")
                    .font(.system(size: 12.5, weight: .medium))
                Text("Sets today's water intake to 0 ml.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset", role: .destructive) { WaterStore.reset() }
                .buttonStyle(.glass)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Bausteine

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 1)
    }

    private func stepperRow(_ title: LocalizedStringKey,
                            value: Binding<Int>,
                            range: ClosedRange<Int>,
                            step: Int) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))

            Spacer()

            Text("\(value.wrappedValue) ml")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private var appLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        let base = code.split(separator: "-").first.map(String.init) ?? code
        return Locale(identifier: base).localizedString(forLanguageCode: base)?.capitalized ?? base.uppercased()
    }

    private func openLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else {
            return
        }
        openURL(url)
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
}

#Preview {
    MacSettingsSheet()
}
#endif
