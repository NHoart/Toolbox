import WidgetKit
import SwiftUI
import AppIntents

// Interactive buttons in the widget (iOS 17+)
struct AddGlassIntent: AppIntent {
    static var title: LocalizedStringResource = "Drink a glass"
    func perform() async throws -> some IntentResult {
        WaterStore.add(WaterStore.glassML)
        return .result()
    }
}

struct AddBottleIntent: AppIntent {
    static var title: LocalizedStringResource = "Drink a bottle"
    func perform() async throws -> some IntentResult {
        WaterStore.add(WaterStore.bottleML)
        return .result()
    }
}

struct WaterEntry: TimelineEntry {
    let date: Date
    let total: Int
    let goal: Int
    let glass: Int
    let bottle: Int
}

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: .now, total: 1000, goal: 2000, glass: 200, bottle: 500)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        let now = Date()
        // Next update at midnight so the daily counter resets
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86400))
        // Also reload regularly: amounts logged in the background (e.g. via Siri)
        // arrive this way even when WidgetKit throttled a reload request.
        let nextRefresh = min(now.addingTimeInterval(30 * 60), midnight)
        completion(Timeline(entries: [current()], policy: .after(nextRefresh)))
    }

    private func current() -> WaterEntry {
        WaterEntry(date: .now,
                   total: WaterStore.todayML,
                   goal: WaterStore.goalML,
                   glass: WaterStore.glassML,
                   bottle: WaterStore.bottleML)
    }
}

struct WaterWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WaterEntry

    private var progress: Double { min(Double(entry.total) / Double(max(entry.goal, 1)), 1) }

    var body: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                ring
                VStack(spacing: 8) {
                    Button(intent: AddGlassIntent()) { label("Glass", entry.glass) }
                    Button(intent: AddBottleIntent()) { label("Bottle", entry.bottle) }
                }
                .buttonStyle(.plain)
            }
        default:
            ring
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.blue.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(progress * 100))")
                    .font(.title2.bold())
                Text("\(entry.total) / \(entry.goal) ml")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(6)
    }

    private func label(_ title: LocalizedStringResource, _ ml: Int) -> some View {
        Text("+ \(String(localized: title)) (\(ml) ml)")
            .font(.footnote.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct WassertrackerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WassertrackerWidget", provider: WaterProvider()) { entry in
            WaterWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water tracker")
        .description("Shows your daily progress and lets you log water.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct WassertrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WassertrackerWidget()
    }
}
