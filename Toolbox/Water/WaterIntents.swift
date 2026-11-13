import AppIntents
import Foundation

/// Menge, die per Siri eingetragen werden kann.
/// Einheit und Anzahl stecken in einem Wert, weil eine Siri-Phrase nur einen Parameter enthalten darf.
enum WaterPortion: String, AppEnum {
    case glass
    case twoGlasses
    case threeGlasses
    case bottle
    case twoBottles
    case threeBottles

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Menge")
    }

    static var caseDisplayRepresentations: [WaterPortion: DisplayRepresentation] {
        [
            .glass: DisplayRepresentation(title: "ein Glas", synonyms: ["Glas", "Glas Wasser"]),
            .twoGlasses: DisplayRepresentation(title: "zwei Gläser", synonyms: ["2 Gläser", "zwei Gläser Wasser"]),
            .threeGlasses: DisplayRepresentation(title: "drei Gläser", synonyms: ["3 Gläser", "drei Gläser Wasser"]),
            .bottle: DisplayRepresentation(title: "eine Flasche", synonyms: ["Flasche", "Flasche Wasser"]),
            .twoBottles: DisplayRepresentation(title: "zwei Flaschen", synonyms: ["2 Flaschen", "zwei Flaschen Wasser"]),
            .threeBottles: DisplayRepresentation(title: "drei Flaschen", synonyms: ["3 Flaschen", "drei Flaschen Wasser"]),
        ]
    }

    /// Anzahl der Einheiten.
    var count: Int {
        switch self {
        case .glass, .bottle: 1
        case .twoGlasses, .twoBottles: 2
        case .threeGlasses, .threeBottles: 3
        }
    }

    /// Größe einer einzelnen Einheit in ml (aus den Einstellungen).
    private var unitML: Int {
        switch self {
        case .glass, .twoGlasses, .threeGlasses: WaterStore.glassML
        case .bottle, .twoBottles, .threeBottles: WaterStore.bottleML
        }
    }

    /// Gesamtmenge in ml.
    var milliliters: Int { unitML * count }

    /// Text für die Siri-Antwort, z. B. "zwei Gläser".
    var label: String {
        switch self {
        case .glass: "ein Glas"
        case .twoGlasses: "zwei Gläser"
        case .threeGlasses: "drei Gläser"
        case .bottle: "eine Flasche"
        case .twoBottles: "zwei Flaschen"
        case .threeBottles: "drei Flaschen"
        }
    }
}

/// Trägt Gläser oder Flaschen Wasser ein.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser eintragen"
    static var description = IntentDescription("Trägt Gläser oder Flaschen Wasser in den Wassertracker ein.")

    @Parameter(title: "Menge", requestValueDialog: "Was hast du getrunken?")
    var portion: WaterPortion

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$portion) eintragen")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = portion.milliliters
        await WaterStore.add(ml)

        let total = await WaterStore.todayML
        let goal = await WaterStore.goalML
        return .result(dialog: "\(portion.label) eingetragen (\(ml) Milliliter). Heute: \(total) von \(goal) Millilitern.")
    }
}

/// Macht den Kurzbefehl für Siri verfügbar, z. B. "Hey Siri, ich habe zwei Gläser getrunken in Toolbox".
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Ich habe \(\.$portion) getrunken in \(.applicationName)",
                "\(.applicationName) ich habe \(\.$portion) getrunken",
                "Trage \(\.$portion) Wasser in \(.applicationName) ein",
            ],
            shortTitle: "Wasser eintragen",
            systemImageName: "drop.fill"
        )
    }
}
