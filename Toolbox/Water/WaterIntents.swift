import AppIntents
import Foundation

/// Amount that can be logged via Siri.
/// Unit and count are packed into one value because a Siri phrase may only contain one parameter.
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

    /// Number of units.
    var count: Int {
        switch self {
        case .glass, .bottle: 1
        case .twoGlasses, .twoBottles: 2
        case .threeGlasses, .threeBottles: 3
        }
    }

    /// Size of a single unit in ml (from Settings).
    private var unitML: Int {
        switch self {
        case .glass, .twoGlasses, .threeGlasses: WaterStore.glassML
        case .bottle, .twoBottles, .threeBottles: WaterStore.bottleML
        }
    }

    /// Total amount in ml.
    var milliliters: Int { unitML * count }

    /// Text for the Siri answer, e.g. "two glasses".
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

/// Logs glasses or bottles of water.
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

/// Makes the shortcut available to Siri, e.g. "Hey Siri, log two glasses of water in Toolbox".
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
