import SwiftUI
import WidgetKit
import Combine

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
                    addButton(title: "Glass", icon: "drop.fill", ml: WaterStore.glassML)
                    addButton(title: "Bottle", icon: "waterbottle.fill", ml: WaterStore.bottleML)
                }
                .padding(.horizontal)

                Button { showCustomAmount = true } label: {
                    Label("Custom amount", systemImage: "plus.circle.fill")
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
            .navigationTitle("Water tracker")
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
            .onReceive(NotificationCenter.default.publisher(for: .syncDidApplyRemote)) { _ in
                refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .waterStoreDidChange)) { _ in
                refresh()
            }
        }
    }

    private func addButton(title: LocalizedStringKey, icon: String, ml: Int) -> some View {
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

    private var undoTitle: LocalizedStringKey {
        guard let undoAmount else { return "Undo" }
        return "Undo (\(undoAmount) ml)"
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
    /// A number keyboard only exists on iOS.
    @ViewBuilder
    func numberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    /// The compact navigation title is an iOS presentation.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// Sheet for entering a freely selectable amount in milliliters.
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
                    Text("Custom amount")
                } footer: {
                    if !text.isEmpty && amount == nil {
                        Text("Enter a number between 1 and 10000.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Type a number or use a quick pick.")
                    }
                }

                Section("Quick select") {
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
            .navigationTitle("Enter amount")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { submit() }
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
