import SwiftUI
import WidgetKit

struct WaterTodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var today = WaterStore.todayML
    @State private var undoAmount: Int? = WaterStore.lastAddedML
    @State private var showSettings = false
    @State private var showCustomAmount = false

    private var goal: Int { WaterStore.goalML }
    private var progress: Double { min(Double(today) / Double(max(goal, 1)), 1) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                ZStack {
                    Circle().stroke(Color.blue.opacity(0.15), lineWidth: 22)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress)
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                        Text("\(today) / \(goal) ml")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)
                .padding(.top, 24)

                HStack(spacing: 16) {
                    addButton(title: "Glas", icon: "drop.fill", ml: WaterStore.glassML)
                    addButton(title: "Flasche", icon: "waterbottle.fill", ml: WaterStore.bottleML)
                }
                .padding(.horizontal)

                Button { showCustomAmount = true } label: {
                    Label("Eigene Menge", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                Button(undoTitle) { undo() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .disabled(undoAmount == nil)

                Spacer()
            }
            .navigationTitle("Wassertracker")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: refresh) {
                SettingsView()
            }
            .sheet(isPresented: $showCustomAmount) {
                CustomAmountSheet { ml in add(ml) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
        }
    }

    private func addButton(title: String, icon: String, ml: Int) -> some View {
        Button { add(ml) } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title)
                Text(title).font(.headline)
                Text("+\(ml) ml").font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var undoTitle: String {
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

private extension View {
    /// Zahlentastatur gibt es nur auf iOS.
    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// Kompakter Navigationstitel ist eine iOS-Darstellung.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// Sheet zum Eintragen einer frei wählbaren Menge in Millilitern.
struct CustomAmountSheet: View {
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
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $text)
                            .numberKeyboard()
                            .focused($inputFocused)
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("ml")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Eigene Menge")
                } footer: {
                    if !text.isEmpty && amount == nil {
                        Text("Bitte eine Zahl zwischen 1 und 10000 eingeben.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Zahl eintippen oder eine Schnellauswahl verwenden.")
                    }
                }

                Section("Schnellauswahl") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                        ForEach(Self.presets, id: \.self) { preset in
                            Button("\(preset) ml") { text = String(preset) }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Menge eintragen")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { submit() }
                        .disabled(amount == nil)
                }
            }
            .onAppear { inputFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        guard let amount else { return }
        onAdd(amount)
        dismiss()
    }
}
