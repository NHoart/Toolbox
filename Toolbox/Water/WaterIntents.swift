import AppIntents
import Foundation

/// Einheit, die per Siri eingetragen werden kann.
enum WaterUnit: String, AppEnum {
    case glass
    case bottle

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Einheit")
    }

    static var caseDisplayRepresentations: [WaterUnit: DisplayRepresentation] {
        [
            .glass: DisplayRepresentation(title: "Glas", image: .init(systemName: "drop.fill")),
            .bottle: DisplayRepresentation(title: "Flasche", image: .init(systemName: "waterbottle.fill")),
        ]
    }

    /// Menge in ml – folgt den in den Einstellungen gewählten Größen.
    var milliliters: Int {
        switch self {
        case .glass: WaterStore.glassML
        case .bottle: WaterStore.bottleML
        }
    }
}

/// Trägt ein Glas oder eine Flasche Wasser ein.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser eintragen"
    static var description = IntentDescription("Trägt ein Glas oder eine Flasche Wasser in den Wassertracker ein.")

    @Parameter(title: "Einheit", requestValueDialog: "Was hast du getrunken?")
    var amount: WaterUnit

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) eintragen")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = amount.milliliters
        WaterStore.add(ml)
        let total = WaterStore.todayML
        let goal = WaterStore.goalML
        return .result(dialog: "\(ml) Milliliter eingetragen. Heute: \(total) von \(goal) Millilitern.")
    }
}

/// Macht den Kurzbefehl für Siri verfügbar ("Hey Siri, ich habe ein Glas getrunken mit Toolbox").
struct WaterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Ich habe \(\.$amount) getrunken in \(.applicationName)",
                "\(.applicationName) ich habe \(\.$amount) getrunken",
                "Trage \(\.$amount) Wasser in \(.applicationName) ein",
            ],
            shortTitle: "Wasser eintragen",
            systemImageName: "drop.fill"
        )
    }
}
