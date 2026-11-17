import SwiftUI

struct UnitConverterView: View {
    @State private var conversion = UnitConversion.mbToGB
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Conversion", selection: $conversion) {
                        ForEach(UnitConversion.allCases) { conversion in
                            Text(conversion.title).tag(conversion)
                        }
                    }
                    .navigationLinkPicker()
                } header: {
                    Text("Conversion type")
                }

                Section {
                    TextField(conversion.inputLabel, text: $input)
                        .decimalKeyboard()
                        .focused($isInputFocused)
                } header: {
                    Text("Enter value")
                }

                ResultCard(
                    title: "Result",
                    value: resultText,
                    detail: conversion.resultLabel
                )
            }
            .navigationTitle("Units")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        input = ""
                        isInputFocused = false
                    }
                }
            }
            .macSettingsToolbar()
        }
    }

    private var resultText: String {
        guard let value = input.decimalValue else {
            return "Enter a number"
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

        // Factor to convert the speed into MB/s
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
                Section("File and connection") {
                    TextField("File size in GB", text: $fileSize)
                        .decimalKeyboard()
                        .focused($isInputFocused)

                    Picker("Unit", selection: $speedUnit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Download speed in \(speedUnit.rawValue)", text: $speed)
                        .decimalKeyboard()
                        .focused($isInputFocused)
                }

                ResultCard(
                    title: "Estimated download time",
                    value: downloadTime,
                    detail: "Calculated without extra delays"
                )

            }
            .navigationTitle("Download time")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        fileSize = ""
                        speed = ""
                        speedUnit = .mbit
                        isInputFocused = false
                    }
                }
            }
            .macSettingsToolbar()
        }
    }

    private var downloadTime: String {
        guard
            let size = fileSize.decimalValue,
            let downloadSpeed = speed.decimalValue,
            downloadSpeed > 0
        else {
            return "Enter file size and speed"
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
                Section("Enter usage") {
                    TextField("Power in watts", text: $power)
                        .decimalKeyboard()
                        .focused($isInputFocused)

                    TextField("Duration in hours", text: $duration)
                        .decimalKeyboard()
                        .focused($isInputFocused)

                    TextField("Electricity price per kWh in € (optional)", text: $price)
                        .decimalKeyboard()
                        .focused($isInputFocused)
                }

                ResultCard(
                    title: "Power usage",
                    value: energyText,
                    detail: "Cost: \(costText)"
                )

            }
            .navigationTitle("Power usage")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        isInputFocused = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        power = ""
                        duration = ""
                        price = ""
                        isInputFocused = false
                    }
                }
            }
            .macSettingsToolbar()
        }
    }

    private var energyText: String {
        guard let energy = energyConsumption else {
            return "Enter power and duration"
        }

        return "\(energy.formatted(.number.precision(.fractionLength(0...3)))) kWh"
    }

    private var costText: String {
        guard
            let energy = energyConsumption,
            let electricityPrice = price.decimalValue
        else {
            return "No electricity price provided"
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
            String(localized: "MB to GB")
        case .gbToMB:
            String(localized: "GB to MB")
        case .mbitToMB:
            String(localized: "Mbit to MB")
        case .mbToMbit:
            String(localized: "MB to Mbit")
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

private extension View {
    /// A decimal keyboard only exists on iOS; on the Mac you type with the normal keyboard.
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    /// The NavigationLink presentation of a picker is reserved for iOS.
    @ViewBuilder
    func navigationLinkPicker() -> some View {
        #if os(iOS)
        pickerStyle(.navigationLink)
        #else
        pickerStyle(.menu)
        #endif
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
        return "\(hours) h \(minutes) min \(remainingSeconds) s"
    }

    if minutes > 0 {
        return "\(minutes) min \(remainingSeconds) s"
    }

    return "\(remainingSeconds) s"
}
