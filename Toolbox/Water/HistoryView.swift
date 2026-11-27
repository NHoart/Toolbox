import SwiftUI
import Charts
import Combine

struct HistoryView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000
    @State private var days: [WaterStore.DayEntry] = []

    private var average: Int {
        days.isEmpty ? 0 : days.map(\.ml).reduce(0, +) / days.count
    }
    private var daysReached: Int { days.filter { $0.ml >= goal }.count }
    private var best: Int { days.map(\.ml).max() ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Chart {
                        ForEach(days) { d in
                            BarMark(x: .value("Day", d.date, unit: .day),
                                    y: .value("ml", d.ml))
                                .foregroundStyle(d.ml >= goal ? Color.green : Color.blue)
                        }
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                        }
                    }
                    .frame(height: 220)
                    .padding(.vertical, 8)
                } header: {
                    Text("Last 30 days")
                } footer: {
                    Text("Green = daily goal reached. Dashed line = goal (\(goal) ml).")
                }

                Section("Statistics") {
                    statRow("Average", "\(average) ml")
                    statRow("Goal reached", "\(daysReached) of \(days.count) days")
                    statRow("Best day", "\(best) ml")
                }

                Section("Days") {
                    ForEach(days.reversed()) { d in
                        HStack {
                            Text(d.date, format: .dateTime.weekday(.abbreviated).day().month())
                            Spacer()
                            Text("\(d.ml) ml").monospacedDigit()
                            Image(systemName: d.ml >= goal ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(d.ml >= goal ? .green : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .macSettingsToolbar()
            .onAppear(perform: refresh)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .syncDidApplyRemote)) { _ in
                refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .waterStoreDidChange)) { _ in
                refresh()
            }
        }
    }

    private func statRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func refresh() { days = WaterStore.lastDays(30) }
}
