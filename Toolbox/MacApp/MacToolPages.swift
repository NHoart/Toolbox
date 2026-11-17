#if os(macOS)
import SwiftUI

// MARK: - Einheiten

struct MacUnitsPage: View {
    @Binding var showSettings: Bool

    @State private var conversion = MacUnitConversion.mbToGB
    @State private var input = ""

    private var result: Double? {
        guard let value = input.macDecimalValue else { return nil }
        switch conversion {
        case .mbToGB: return value / 1_000
        case .gbToMB: return value * 1_000
        case .mbitToMB: return value / 8
        case .mbToMbit: return value * 8
        }
    }

    var body: some View {
        MacPage(title: "Units",
                subtitle: "Convert MB/GB and Mbit/MB",
                showSettings: $showSettings) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    MacCardHeader(title: "CONVERSION", systemImage: "arrow.left.arrow.right", tint: MacTheme.cyan)

                    Picker("Conversion", selection: $conversion) {
                        ForEach(MacUnitConversion.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    MacField(title: "Value",
                             placeholder: "0",
                             unit: conversion.inputLabel,
                             text: $input)

                    HStack {
                        Spacer()
                        Button("Reset") { input = "" }
                            .buttonStyle(.glass)
                            .disabled(input.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .macGlassCard()

                resultCard
                    .frame(width: 268)
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "RESULT", systemImage: "equal.circle.fill", tint: MacTheme.violet)

            if let result {
                Text(result.formatted(.number.precision(.fractionLength(0...3))))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MacTheme.waterGradient)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            } else {
                Text("—")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Text(result == nil ? "Enter value" : "Result in \(conversion.resultLabel)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macGlassCard(tint: MacTheme.violet.opacity(0.12))
    }
}

// MARK: - Downloadzeit

struct MacDownloadPage: View {
    private enum SpeedUnit: String, CaseIterable, Identifiable {
        case mbit = "Mbit/s"
        case mb = "MB/s"

        var id: Self { self }

        var megabytesPerSecond: Double {
            switch self {
            case .mbit: 1.0 / 8
            case .mb: 1
            }
        }
    }

    @Binding var showSettings: Bool

    @State private var fileSize = ""
    @State private var speed = ""
    @State private var speedUnit = SpeedUnit.mbit

    private var downloadTime: String? {
        guard
            let size = fileSize.macDecimalValue,
            let downloadSpeed = speed.macDecimalValue,
            downloadSpeed > 0
        else { return nil }

        let sizeInMB = size * 1_000
        let speedInMBPerSecond = downloadSpeed * speedUnit.megabytesPerSecond
        return macFormattedDuration(sizeInMB / speedInMBPerSecond)
    }

    var body: some View {
        MacPage(title: "Download time",
                subtitle: "File size and speed",
                showSettings: $showSettings) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    MacCardHeader(title: "FILE AND CONNECTION", systemImage: "arrow.down.circle.fill", tint: MacTheme.pink)

                    MacField(title: "File size", placeholder: "0", unit: "GB", text: $fileSize)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("UNIT")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(.secondary)

                        Picker("Unit", selection: $speedUnit) {
                            ForEach(SpeedUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    MacField(title: "Download speed",
                             placeholder: "0",
                             unit: speedUnit.rawValue,
                             text: $speed)

                    HStack {
                        Spacer()
                        Button("Reset") {
                            fileSize = ""
                            speed = ""
                            speedUnit = .mbit
                        }
                        .buttonStyle(.glass)
                        .disabled(fileSize.isEmpty && speed.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .macGlassCard()

                resultCard
                    .frame(width: 268)
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "DOWNLOAD TIME", systemImage: "clock.fill", tint: MacTheme.pink)

            if let downloadTime {
                Text(downloadTime)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MacTheme.waterGradient)
                    .minimumScaleFactor(0.45)
                    .lineLimit(2)
                    .contentTransition(.numericText())
            } else {
                Text("—")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Text(downloadTime == nil
                 ? "Enter file size and speed"
                 : "Calculated without extra delays")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macGlassCard(tint: MacTheme.pink.opacity(0.10))
    }
}

// MARK: - Stromverbrauch

struct MacEnergyPage: View {
    @Binding var showSettings: Bool

    @State private var power = ""
    @State private var duration = ""
    @State private var price = ""

    private var energyConsumption: Double? {
        guard
            let watts = power.macDecimalValue,
            let hours = duration.macDecimalValue
        else { return nil }
        return watts / 1_000 * hours
    }

    private var energyText: String? {
        guard let energy = energyConsumption else { return nil }
        return "\(energy.formatted(.number.precision(.fractionLength(0...3)))) kWh"
    }

    private var costText: String {
        guard
            let energy = energyConsumption,
            let electricityPrice = price.macDecimalValue
        else { return "No electricity price provided" }

        return (energy * electricityPrice).formatted(.currency(code: "EUR"))
    }

    var body: some View {
        MacPage(title: "Power usage",
                subtitle: "Power, duration and cost",
                showSettings: $showSettings) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    MacCardHeader(title: "ENTER USAGE", systemImage: "bolt.fill", tint: MacTheme.amber)

                    MacField(title: "Power", placeholder: "0", unit: String(localized: "Watts"), text: $power)
                    MacField(title: "Duration", placeholder: "0", unit: String(localized: "Hours"), text: $duration)
                    MacField(title: "Electricity price per kWh (optional)", placeholder: "0", unit: "€", text: $price)

                    HStack {
                        Spacer()
                        Button("Reset") {
                            power = ""
                            duration = ""
                            price = ""
                        }
                        .buttonStyle(.glass)
                        .disabled(power.isEmpty && duration.isEmpty && price.isEmpty)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .macGlassCard()

                resultCard
                    .frame(width: 268)
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MacCardHeader(title: "RESULT", systemImage: "bolt.circle.fill", tint: MacTheme.amber)

            if let energyText {
                Text(energyText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(MacTheme.waterGradient)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            } else {
                Text("—")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Text("Cost: \(costText)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macGlassCard(tint: MacTheme.amber.opacity(0.12))
    }
}

// MARK: - Counter

struct MacCounterPage: View {
    @Binding var showSettings: Bool

    @StateObject private var store = CounterStore()
    @State private var showSaveAlert = false
    @State private var newName = ""

    var body: some View {
        MacPage(title: "Counter",
                subtitle: "Count manually or automatically",
                showSettings: $showSettings) {
            HStack(alignment: .top, spacing: 18) {
                counterCard
                    .frame(maxWidth: .infinity)

                savedCard
                    .frame(width: 268)
            }
        }
        .alert("Save count", isPresented: $showSaveAlert) {
            TextField("Name", text: $newName)
            Button("Save") {
                store.saveCurrent(name: newName)
                newName = ""
            }
            Button("Cancel", role: .cancel) {
                newName = ""
            }
        } message: {
            Text("Current count: \(store.count)")
        }
        .onDisappear {
            store.stopAutoCounting()
        }
    }

    // MARK: Counter card

    private var counterCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                MacCardHeader(title: "COUNTER VALUE", systemImage: "plus.circle.fill", tint: MacTheme.violet)

                Spacer()

                if store.isAutoRunning {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(MacTheme.mint)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(MacTheme.mint.opacity(0.16), in: Capsule())
                }
            }

            Text("\(store.count)")
                .font(.system(size: 92, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(MacTheme.counterGradient)
                .contentTransition(.numericText())
                .animation(store.isAutoRunning
                           ? nil
                           : .spring(response: 0.3, dampingFraction: 0.75),
                           value: store.count)
                .minimumScaleFactor(0.35)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            HStack(spacing: 30) {
                MacCircleButton(systemImage: "minus",
                                tint: .red,
                                size: 64,
                                isEnabled: store.count > 0) {
                    store.decrement()
                }

                MacCircleButton(systemImage: "plus",
                                tint: MacTheme.violet,
                                size: 92) {
                    store.increment()
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 9) {
                Button {
                    store.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)

                Button {
                    store.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)
                .disabled(store.count == 0)

                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            autoRow
        }
        .macGlassCard(cornerRadius: 26, tint: MacTheme.violet.opacity(0.10), padding: 24)
    }

    private var autoRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Automatic")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(store.incrementsPerSecond)× per second")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    store.incrementsPerSecond -= 1
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(store.incrementsPerSecond <= CounterStore.minRate)
                .help("Slower")

                Button {
                    store.incrementsPerSecond += 1
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(store.incrementsPerSecond >= CounterStore.maxRate)
                .help("Faster")
            }

            Button {
                if store.isAutoRunning {
                    store.stopAutoCounting()
                } else {
                    store.startAutoCounting()
                }
            } label: {
                Label(store.isAutoRunning ? "Stop" : "Start",
                      systemImage: store.isAutoRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(store.isAutoRunning ? .red : MacTheme.mint)
        }
    }

    // MARK: Saved counters

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MacCardHeader(title: "SAVED", systemImage: "bookmark.fill", tint: MacTheme.cyan)

                Spacer()

                Button {
                    showSaveAlert = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Save current count")
            }

            if store.savedCounters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Nothing saved yet")
                        .font(.system(size: 11.5, weight: .medium))
                    Text("Save the current count with the icon above.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(store.savedCounters.enumerated()), id: \.element.id) { index, saved in
                            savedRow(saved, index: index)
                        }
                    }
                }
                .frame(maxHeight: 420)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .macGlassCard(cornerRadius: 24, padding: 18)
    }

    private func savedRow(_ saved: SavedCounter, index: Int) -> some View {
        Button {
            store.load(saved)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(saved.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Text(saved.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Text("\(saved.value)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Load") { store.load(saved) }
            Button("Delete", role: .destructive) {
                store.deleteSaved(at: IndexSet(integer: index))
            }
        }
    }
}

// MARK: - Einheiten-Helfer

/// Separate copy for the Mac interface so the iOS views stay unchanged.
private enum MacUnitConversion: String, CaseIterable, Identifiable {
    case mbToGB
    case gbToMB
    case mbitToMB
    case mbToMbit

    var id: Self { self }

    var title: String {
        switch self {
        case .mbToGB: String(localized: "MB to GB")
        case .gbToMB: String(localized: "GB to MB")
        case .mbitToMB: String(localized: "Mbit to MB")
        case .mbToMbit: String(localized: "MB to Mbit")
        }
    }

    var inputLabel: String {
        switch self {
        case .gbToMB:
            String(localized: "Value in GB")
        case .mbToGB, .mbToMbit:
            String(localized: "Value in MB")
        case .mbitToMB:
            String(localized: "Value in Mbit")
        }
    }

    var resultLabel: String {
        switch self {
        case .mbToGB:
            "GB"
        case .gbToMB, .mbitToMB:
            "MB"
        case .mbToMbit:
            "Mbit"
        }
    }
}

private func macFormattedDuration(_ seconds: Double) -> String {
    let roundedSeconds = max(0, Int(seconds.rounded()))
    let hours = roundedSeconds / 3_600
    let minutes = (roundedSeconds % 3_600) / 60
    let remainingSeconds = roundedSeconds % 60

    if hours > 0 {
        return "\(hours) h \(minutes) min \(remainingSeconds) s"
    }

    if minutes > 0 {
        return "\(minutes) min \(remainingSeconds) s"
    }

    return "\(remainingSeconds) s"
}

// MARK: - Zahl-Helfer

private extension String {
    var macDecimalValue: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
    }
}
#endif
