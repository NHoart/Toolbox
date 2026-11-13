#if os(macOS)
import SwiftUI

/// Einstellungen der Mac-App im Glas-Look.
/// Die iPhone-Version behält ihre eigene `SettingsView`.
struct MacSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

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
        VStack(alignment: .leading, spacing: 16) {
            header

            ScrollView {
                VStack(spacing: 14) {
                    sizesCard
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
        .onChange(of: glass) { _, _ in WaterStore.markChanged() }
        .onChange(of: bottle) { _, _ in WaterStore.markChanged() }
        .onChange(of: goal) { _, _ in WaterStore.markChanged() }
        .onChange(of: lanEnabled) { _, enabled in LocalSync.shared.setEnabled(enabled) }
    }

    // MARK: - Kopf und Fuß

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Einstellungen")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Wasser, Netzwerk und Updates")
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
            .help("Schließen")
        }
    }

    private var footer: some View {
        HStack {
            Text("Version \(UpdateChecker.currentVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Fertig") { dismiss() }
                .buttonStyle(.glassProminent)
                .tint(MacTheme.accent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Karten

    private var sizesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            MacCardHeader(title: "MENGEN", systemImage: "drop.fill", tint: MacTheme.accent)

            stepperRow("Glas", value: $glass, range: 50...1000, step: 50)
            divider
            stepperRow("Flasche", value: $bottle, range: 100...3000, step: 50)
            divider
            stepperRow("Tagesziel", value: $goal, range: 500...6000, step: 250)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "LOKALES NETZWERK", systemImage: "wifi", tint: MacTheme.cyan)

            Toggle("Sync im WLAN", isOn: $lanEnabled)
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

                Button("Jetzt suchen") { LocalSync.shared.syncNow() }
                    .buttonStyle(.glass)
            }

            Text("Gleicht Wassertracker und Zähler direkt mit deinem anderen Gerät im selben WLAN ab – ohne Server. Öffne die App auf beiden Geräten, sie finden sich automatisch.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "UPDATES", systemImage: "arrow.triangle.2.circlepath", tint: MacTheme.violet)

            Toggle("Automatisch nach Updates suchen", isOn: $automaticUpdateChecks)
                .toggleStyle(.switch)
                .font(.system(size: 12.5, weight: .medium))

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

            Text("Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .macGlassCard(cornerRadius: 20, padding: 16)
    }

    private var resetCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heute zurücksetzen")
                    .font(.system(size: 12.5, weight: .medium))
                Text("Setzt die heutige Trinkmenge auf 0 ml.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Zurücksetzen", role: .destructive) { WaterStore.reset() }
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

    private var lanStatus: String {
        guard lanEnabled else { return "Aus" }
        if lan.peerCount == 1 { return "Verbunden mit 1 Gerät" }
        if lan.peerCount > 1 { return "Verbunden mit \(lan.peerCount) Geräten" }
        if let date = lan.lastSync {
            return "Zuletzt \(date.formatted(date: .omitted, time: .shortened))"
        }
        return lan.isSearching ? "Suche im WLAN…" : "Kein Gerät gefunden"
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
}

#Preview {
    MacSettingsSheet()
}
#endif
