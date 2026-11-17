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
        TypeDisplayRepresentation(name: "Amount")
    }

    static var caseDisplayRepresentations: [WaterPortion: DisplayRepresentation] {
        [
            .glass: DisplayRepresentation(title: "a glass", synonyms: ["Glass", "glass of water"]),
            .twoGlasses: DisplayRepresentation(title: "two glasses", synonyms: ["2 glasses", "two glasses of water"]),
            .threeGlasses: DisplayRepresentation(title: "three glasses", synonyms: ["3 glasses", "three glasses of water"]),
            .bottle: DisplayRepresentation(title: "a bottle", synonyms: ["Bottle", "bottle of water"]),
            .twoBottles: DisplayRepresentation(title: "two bottles", synonyms: ["2 bottles", "two bottles of water"]),
            .threeBottles: DisplayRepresentation(title: "three bottles", synonyms: ["3 bottles", "three bottles of water"]),
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

    /// Text für die Siri-Antwort, z. B. "two glasses".
    var label: String {
        switch self {
        case .glass: "a glass"
        case .twoGlasses: "two glasses"
        case .threeGlasses: "three glasses"
        case .bottle: "a bottle"
        case .twoBottles: "two bottles"
        case .threeBottles: "three bottles"
        }
    }
}

/// Trägt Gläser oder Flaschen Wasser ein.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log water"
    static var description = IntentDescription("Logs glasses or bottles of water in the water tracker.")

    @Parameter(title: "Amount", requestValueDialog: "What did you drink?")
    var portion: WaterPortion

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$portion)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = portion.milliliters
        await WaterStore.add(ml)

        let total = await WaterStore.todayML
        let goal = await WaterStore.goalML
        return .result(dialog: "Logged \(portion.label) (\(ml) millilitres). Today: \(total) of \(goal) millilitres.")
    }
}

/// Macht den Kurzbefehl für Siri verfügbar, z. B. "Hey Siri, ich habe zwei Gläser getrunken in Toolbox".
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "I drank \(\.$portion) in \(.applicationName)",
                "\(.applicationName) ich habe \(\.$portion) getrunken",
                "Log \(\.$portion) of water in \(.applicationName)",
            ],
            shortTitle: "Log water",
            systemImageName: "drop.fill"
        )
    }
}
