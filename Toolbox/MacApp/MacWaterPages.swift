#if os(macOS)
import SwiftUI
import Charts

// MARK: - Heute

struct MacWaterTodayPage: View {
    @Binding var showSettings: Bool

    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000
    @AppStorage(WaterStore.Key.glass, store: WaterStore.defaults) private var glass = 200
    @AppStorage(WaterStore.Key.bottle, store: WaterStore.defaults) private var bottle = 500

    @State private var today = WaterStore.todayML
    @State private var undoAmount: Int? = WaterStore.lastAddedML
    @State private var showCustomAmount = false

    private var progress: Double { min(Double(today) / Double(max(goal, 1)), 1) }
    private var remaining: Int { max(goal - today, 0) }

    var body: some View {
        MacPage(title: "Wassertracker",
                subtitle: "Dein Fortschritt für heute",
                showSettings: $showSettings) {
            heroCard
            tileRow
        }
        .sheet(isPresented: $showCustomAmount) {
            MacCustomAmountSheet { ml in add(ml) }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .syncDidApplyRemote)) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterStoreDidChange)) { _ in
            refresh()
        }
    }

    // MARK: Karte

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 34) {
            ring

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    MacCardHeader(title: "HEUTE", systemImage: "sun.max.fill", tint: MacTheme.amber)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(today)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("ml")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Text(remaining == 0
                         ? "Tagesziel erreicht – \(goal) ml geschafft."
                         : "von \(goal) ml Ziel · noch \(remaining) ml offen")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    progressBar
                        .padding(.top, 4)
                }

                HStack(spacing: 12) {
                    quickAddButton(title: "Glas", icon: "drop.fill", ml: glass, tint: MacTheme.accent)
                    quickAddButton(title: "Flasche", icon: "waterbottle.fill", ml: bottle, tint: MacTheme.cyan)
                }

                HStack(spacing: 10) {
                    Button {
                        showCustomAmount = true
                    } label: {
                        Label("Eigene Menge", systemImage: "plus")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(MacTheme.accent)

                    Button {
                        undo()
                    } label: {
                        Label(undoTitle, systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .buttonStyle(.glass)
                    .disabled(undoAmount == nil)

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macGlassCard(tint: MacTheme.accent.opacity(0.20), padding: 32)
    }

    /// Dünner Fortschrittsbalken unter der Tagesmenge.
    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))

                Capsule()
                    .fill(MacTheme.waterGradient)
                    .frame(width: max(0, proxy.size.width * progress))
                    .shadow(color: MacTheme.accent.opacity(0.45), radius: 5)
            }
        }
        .frame(height: 7)
        .animation(.easeOut(duration: 0.45), value: progress)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [MacTheme.accent, MacTheme.cyan, MacTheme.violet, MacTheme.accent],
                        center: .center,
                        angle: .degrees(-90)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: MacTheme.accent.opacity(0.45), radius: 10)
                .animation(.easeOut(duration: 0.45), value: progress)

            VStack(spacing: 1) {
                Text("\(Int((progress * 100).rounded()))")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(today) / \(goal)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
                    .frame(width: 220, height: 220)
    }

    private var tileRow: some View {
        HStack(spacing: 16) {
            MacMetricTile(title: "Glas",
                          value: "\(glass) ml",
                          detail: "Schnellwahl",
                          systemImage: "drop.fill",
                          tint: MacTheme.accent)

            MacMetricTile(title: "Flasche",
                          value: "\(bottle) ml",
                          detail: "Schnellwahl",
                          systemImage: "waterbottle.fill",
                          tint: MacTheme.cyan)

            MacMetricTile(title: "Tagesziel",
                          value: "\(goal) ml",
                          detail: "Ziel für heute",
                          systemImage: "target",
                          tint: MacTheme.violet)
        }
    }

    // MARK: Aktionen

    private func quickAddButton(title: LocalizedStringKey,
                                icon: String,
                                ml: Int,
                                tint: Color) -> some View {
        Button {
            add(ml)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("+\(ml) ml")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(tint.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(MacPressButtonStyle())
    }

    private var undoTitle: LocalizedStringKey {
        guard let undoAmount else { return "Rückgängig" }
        return "Rückgängig (\(undoAmount) ml)"
    }

    private func add(_ ml: Int) {
        WaterStore.add(ml)
        refresh()
    }

    private func undo() {
        WaterStore.undoLast()
        refresh()
    }

    private func refresh() {
        today = WaterStore.todayML
        undoAmount = WaterStore.lastAddedML
    }
}

// MARK: - Eigene Menge

/// Mac-Variante des Mengen-Sheets – gleiche Logik wie auf dem iPhone, nur im Glas-Look.
struct MacCustomAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Int) -> Void

    @State private var text = ""
    @FocusState private var inputFocused: Bool

    private static let presets = [100, 150, 200, 250, 330, 500, 750, 1000]

    private var amount: Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0, value <= 10000 else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Menge eintragen")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Zahl eintippen oder eine Schnellauswahl verwenden.")
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
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .focused($inputFocused)
                    .onSubmit(submit)

                Text("ml")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        !text.isEmpty && amount == nil
                        ? Color.red.opacity(0.55)
                        : Color.white.opacity(0.35),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture { inputFocused = true }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Self.presets, id: \.self) { preset in
                    Button("\(preset) ml") { text = String(preset) }
                        .font(.system(size: 11.5, weight: .medium))
                        .buttonStyle(.glass)
                }
            }

            HStack(spacing: 8) {
                if !text.isEmpty && amount == nil {
                    Text("Bitte eine Zahl zwischen 1 und 10000 eingeben.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Abbrechen") { dismiss() }
                    .buttonStyle(.glass)

                Button("Hinzufügen") { submit() }
                    .buttonStyle(.glassProminent)
                    .tint(MacTheme.accent)
                    .disabled(amount == nil)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(MacBackdrop())
        .onAppear { inputFocused = true }
    }

    private func submit() {
        guard let amount else { return }
        onAdd(amount)
        dismiss()
    }
}

// MARK: - Verlauf

struct MacHistoryPage: View {
    @Binding var showSettings: Bool

    @AppStorage(WaterStore.Key.goal, store: WaterStore.defaults) private var goal = 2000
    @State private var days: [WaterStore.DayEntry] = []

    private var average: Int {
        days.isEmpty ? 0 : days.map(\.ml).reduce(0, +) / days.count
    }
    private var daysReached: Int { days.filter { $0.ml >= goal }.count }
    private var best: Int { days.map(\.ml).max() ?? 0 }

    var body: some View {
        MacPage(title: "Verlauf",
                subtitle: "Die letzten 30 Tage im Überblick",
                showSettings: $showSettings) {
            HStack(spacing: 16) {
                MacMetricTile(title: "Durchschnitt",
                              value: "\(average) ml",
                              detail: "pro Tag",
                              systemImage: "chart.line.uptrend.xyaxis",
                              tint: MacTheme.accent)

                MacMetricTile(title: "Ziel erreicht",
                              value: "\(daysReached) von \(days.count)",
                              detail: "Tagen",
                              systemImage: "checkmark.seal.fill",
                              tint: MacTheme.mint)

                MacMetricTile(title: "Bester Tag",
                              value: "\(best) ml",
                              detail: "Höchstwert",
                              systemImage: "trophy.fill",
                              tint: MacTheme.amber)
            }

            chartCard
            daysCard
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .syncDidApplyRemote)) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .waterStoreDidChange)) { _ in
            refresh()
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                MacCardHeader(title: "LETZTE 30 TAGE", systemImage: "chart.bar.fill", tint: MacTheme.accent)
                Spacer()
                legend(color: MacTheme.mint, label: "Ziel erreicht")
                legend(color: MacTheme.accent, label: "Unter Ziel")
            }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Tag", day.date, unit: .day),
                        y: .value("ml", day.ml)
                    )
                    .foregroundStyle(barStyle(for: day.ml))
                    .cornerRadius(3)
                }

                RuleMark(y: .value("Ziel", goal))
                    .foregroundStyle(MacTheme.violet.opacity(0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ziel: \(goal) ml")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                        .font(.system(size: 9.5))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.18))
                    AxisValueLabel()
                        .font(.system(size: 9.5))
                }
            }
            .frame(height: 236)
        }
        .macGlassCard(tint: MacTheme.accent.opacity(0.10))
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MacCardHeader(title: "TAGE", systemImage: "calendar", tint: MacTheme.violet)

            VStack(spacing: 0) {
                ForEach(Array(days.reversed().enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: 12) {
                        Text(day.date, format: .dateTime.weekday(.abbreviated).day().month())
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 108, alignment: .leading)

                        Text("\(day.ml) ml")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: day.ml >= goal ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(day.ml >= goal ? MacTheme.mint : Color.secondary.opacity(0.45))
                    }
                    .padding(.vertical, 8)

                    if index < days.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 1)
                    }
                }
            }
        }
        .macGlassCard(cornerRadius: 24)
    }

    private func legend(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func barStyle(for ml: Int) -> AnyShapeStyle {
        if ml >= goal {
            return AnyShapeStyle(
                LinearGradient(colors: [MacTheme.mint, MacTheme.cyan],
                               startPoint: .bottom, endPoint: .top)
            )
        }
        return AnyShapeStyle(
            LinearGradient(colors: [MacTheme.accent.opacity(0.55), MacTheme.accent],
                           startPoint: .bottom, endPoint: .top)
        )
    }

    private func refresh() { days = WaterStore.lastDays(30) }
}
#endif
