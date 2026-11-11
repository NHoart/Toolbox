import SwiftUI

struct UnitConverterView: View {
    @State private var conversion = UnitConversion.mbToGB
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Umrechnung", selection: $conversion) {
                        ForEach(UnitConversion.allCases) { conversion in
                            Text(conversion.title).tag(conversion)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Art der Umrechnung")
                }

                Section {
                    TextField(conversion.inputLabel, text: $input)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                } header: {
                    Text("Wert eingeben")
                }

                ResultCard(
                    title: "Ergebnis",
                    value: resultText,
                    detail: conversion.resultLabel
                )
            }
            .navigationTitle("Einheiten")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        input = ""
                        isInputFocused = false
                    }
                }
            }
        }
    }

    private var resultText: String {
        guard let value = input.decimalValue else {
            return "Bitte eine Zahl eingeben"
        }

        let result: Double
        switch conversion {
        case .mbToGB:
            result = value / 1_000
        case .gbToMB:
            result = value * 1_000
        case .mbitToMB:
            result = value / 8
        case .mbToMbit:
            result = value * 8
        }

        return result.formatted(.number.precision(.fractionLength(0...3)))
    }
}

struct DownloadTimeView: View {
    private enum SpeedUnit: String, CaseIterable, Identifiable {
        case mbit = "Mbit/s"
        case mb = "MB/s"

        var id: Self { self }

        // Faktor, um die Geschwindigkeit in MB/s umzurechnen
        var megabytesPerSecond: Double {
            switch self {
            case .mbit: 1.0 / 8
            case .mb: 1
            }
        }
    }

    @State private var fileSize = ""
    @State private var speed = ""
    @State private var speedUnit = SpeedUnit.mbit
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Datei und Verbindung") {
                    TextField("Dateigröße in GB", text: $fileSize)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)

                    Picker("Einheit", selection: $speedUnit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Downloadgeschwindigkeit in \(speedUnit.rawValue)", text: $speed)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }

                ResultCard(
                    title: "Geschätzte Downloadzeit",
                    value: downloadTime,
                    detail: "Berechnet ohne zusätzliche Verzögerungen"
                )

            }
            .navigationTitle("Downloadzeit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        fileSize = ""
                        speed = ""
                        speedUnit = .mbit
                        isInputFocused = false
                    }
                }
            }
        }
    }

    private var downloadTime: String {
        guard
            let size = fileSize.decimalValue,
            let downloadSpeed = speed.decimalValue,
            downloadSpeed > 0
        else {
            return "Dateigröße und Geschwindigkeit eingeben"
        }

        let sizeInMB = size * 1_000
        let speedInMBPerSecond = downloadSpeed * speedUnit.megabytesPerSecond
        let totalSeconds = sizeInMB / speedInMBPerSecond
        return formattedDuration(totalSeconds)
    }
}

struct EnergyCostView: View {
    @State private var power = ""
    @State private var duration = ""
    @State private var price = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Verbrauch eingeben") {
                    TextField("Leistung in Watt", text: $power)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)

                    TextField("Nutzungsdauer in Stunden", text: $duration)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)

                    TextField("Strompreis pro kWh in € (optional)", text: $price)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                }

                ResultCard(
                    title: "Stromverbrauch",
                    value: energyText,
                    detail: "Kosten: \(costText)"
                )

            }
            .navigationTitle("Stromverbrauch")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        power = ""
                        duration = ""
                        price = ""
                        isInputFocused = false
                    }
                }
            }
        }
    }

    private var energyText: String {
        guard let energy = energyConsumption else {
            return "Leistung und Nutzungsdauer eingeben"
        }

        return "\(energy.formatted(.number.precision(.fractionLength(0...3)))) kWh"
    }

    private var costText: String {
        guard
            let energy = energyConsumption,
            let electricityPrice = price.decimalValue
        else {
            return "Kein Strompreis angegeben"
        }

        return (energy * electricityPrice).formatted(.currency(code: "EUR"))
    }

    private var energyConsumption: Double? {
        guard
            let watts = power.decimalValue,
            let hours = duration.decimalValue
        else {
            return nil
        }

        return watts / 1_000 * hours
    }
}

private struct ResultCard: View {
    let title: LocalizedStringKey
    let value: String
    let detail: LocalizedStringKey

    init(title: LocalizedStringKey, value: String, detail: LocalizedStringKey) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    init(title: LocalizedStringKey, value: String, detail: String) {
        self.title = title
        self.value = value
        self.detail = LocalizedStringKey(detail)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text(title)
        }
    }
}

private enum UnitConversion: String, CaseIterable, Identifiable {
    case mbToGB
    case gbToMB
    case mbitToMB
    case mbToMbit

    var id: Self { self }

    var title: String {
        switch self {
        case .mbToGB:
            "MB in GB"
        case .gbToMB:
            "GB in MB"
        case .mbitToMB:
            "Mbit in MB"
        case .mbToMbit:
            "MB in Mbit"
        }
    }

    var inputLabel: String {
        switch self {
        case .gbToMB:
            "Wert in GB"
        case .mbToGB, .mbToMbit:
            "Wert in MB"
        case .mbitToMB:
            "Wert in Mbit"
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

private extension String {
    var decimalValue: Double? {
        let normalized = replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}

private func formattedDuration(_ seconds: Double) -> String {
    let roundedSeconds = max(0, Int(seconds.rounded()))
    let hours = roundedSeconds / 3_600
    let minutes = (roundedSeconds % 3_600) / 60
    let remainingSeconds = roundedSeconds % 60

    if hours > 0 {
        return "\(hours) Std. \(minutes) Min. \(remainingSeconds) Sek."
    }

    if minutes > 0 {
        return "\(minutes) Min. \(remainingSeconds) Sek."
    }

    return "\(remainingSeconds) Sek."
}
