//
//  ContentView.swift
//  counter
//

import SwiftUI

struct CounterView: View {
    @StateObject private var store = CounterStore()

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showSidebar = false
    @State private var showSaveAlert = false
    @State private var newName = ""

    /// Im Querformat (iPhone) steht nur wenig Höhe zur Verfügung.
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ZStack(alignment: .leading) {
            mainContent

            if showSidebar {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { showSidebar = false }
                    .transition(.opacity)

                SidebarView(
                    store: store,
                    onSelect: { saved in
                        store.load(saved)
                        showSidebar = false
                    },
                    onClose: { showSidebar = false }
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSidebar)
        .alert("Stand speichern", isPresented: $showSaveAlert) {
            TextField("Name", text: $newName)
            Button("Speichern") {
                store.saveCurrent(name: newName)
                newName = ""
            }
            Button("Abbrechen", role: .cancel) {
                newName = ""
            }
        } message: {
            Text("Aktueller Stand: \(store.count)")
        }
        .onDisappear {
            store.stopAutoCounting()
        }
        .macSettingsToolbar()
    }

    // MARK: - Hauptansicht

    private var mainContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.8, blue: 1.0),
                    Color(red: 0.5, green: 0.2, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.5)
            .overlay(Color.black.opacity(0.3))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                if isCompactHeight {
                    compactLayout
                } else {
                    regularLayout
                }
            }
        }
    }

    // MARK: - Layouts

    /// Hochformat: Zähler mittig, Buttons darunter.
    private var regularLayout: some View {
        VStack(spacing: 0) {
            Spacer()

            countLabel(size: 120)

            Spacer()

            autoPanel
                .padding(.bottom, 28)

            VStack(spacing: 28) {
                plusButton(size: 150)
                minusButton(size: 100)
            }

            HStack {
                undoButton(size: 60)
                Spacer()
                resetButton(size: 60)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 20)
        }
    }

    /// Querformat: riesiger Plus-Button mittig, kleiner Zähler seitlich.
    private var compactLayout: some View {
        HStack(spacing: 12) {
            VStack(spacing: 12) {
                countLabel(size: 58)
                compactRateRow
                minusButton(size: 56)
            }
            .frame(maxWidth: .infinity)

            plusButton(size: 190)

            VStack(spacing: 12) {
                startStopButton(compact: true)
                undoButton(size: 44)
                resetButton(size: 44)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func countLabel(size: CGFloat) -> some View {
        Text("\(store.count)")
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .shadow(radius: 8)
            .minimumScaleFactor(0.25)
            .lineLimit(1)
            .padding(.horizontal)
            .contentTransition(.numericText())
            .animation(store.isAutoRunning ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                       value: store.count)
    }

    // MARK: - Auto-Zähler

    /// Schritte pro Sekunde einstellen und den Auto-Zähler starten/stoppen.
    private var autoPanel: some View {
        HStack(spacing: 14) {
            rateStepButton(symbol: "minus",
                           size: 38,
                           enabled: store.incrementsPerSecond > CounterStore.minRate) {
                store.incrementsPerSecond -= 1
            }

            VStack(spacing: 0) {
                Text("\(store.incrementsPerSecond)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("pro Sekunde")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundColor(.white)
            .frame(minWidth: 76)
            .animation(.snappy(duration: 0.15), value: store.incrementsPerSecond)

            rateStepButton(symbol: "plus",
                           size: 38,
                           enabled: store.incrementsPerSecond < CounterStore.maxRate) {
                store.incrementsPerSecond += 1
            }

            startStopButton(compact: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.14))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        )
    }

    /// Kompakte Rate-Einstellung für das Querformat.
    private var compactRateRow: some View {
        HStack(spacing: 8) {
            rateStepButton(symbol: "minus",
                           size: 30,
                           enabled: store.incrementsPerSecond > CounterStore.minRate) {
                store.incrementsPerSecond -= 1
            }

            Text("\(store.incrementsPerSecond)×/s")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .frame(minWidth: 46)

            rateStepButton(symbol: "plus",
                           size: 30,
                           enabled: store.incrementsPerSecond < CounterStore.maxRate) {
                store.incrementsPerSecond += 1
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.14)))
    }

    private func rateStepButton(symbol: String,
                                size: CGFloat,
                                enabled: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.white.opacity(enabled ? 1 : 0.35))
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(enabled ? 0.2 : 0.07)))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!enabled)
    }

    private func startStopButton(compact: Bool) -> some View {
        Button {
            if store.isAutoRunning {
                store.stopAutoCounting()
            } else {
                store.startAutoCounting()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.isAutoRunning ? "stop.fill" : "play.fill")
                if !compact {
                    Text(store.isAutoRunning ? "Stopp" : "Start")
                }
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(width: compact ? 44 : nil, height: 44)
            .padding(.horizontal, compact ? 0 : 14)
            .background(Capsule().fill(store.isAutoRunning ? Color.red : Color.green.opacity(0.9)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Buttons

    private func plusButton(size: CGFloat) -> some View {
        circleButton(symbol: "plus", fill: .purple, size: size) {
            store.increment()
        }
    }

    private func minusButton(size: CGFloat) -> some View {
        circleButton(symbol: "minus",
                     fill: store.count > 0 ? .red : .gray,
                     size: size) {
            store.decrement()
        }
    }

    private func undoButton(size: CGFloat) -> some View {
        circleButton(symbol: "arrow.uturn.backward", fill: .orange, size: size) {
            store.undo()
        }
    }

    private func resetButton(size: CGFloat) -> some View {
        circleButton(symbol: "arrow.counterclockwise",
                     fill: store.count > 0 ? .purple : .gray,
                     size: size) {
            store.reset()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showSidebar = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                showSaveAlert = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
    }

    private func circleButton(symbol: String,
                              fill: Color,
                              size: CGFloat,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(fill))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 2))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

/// Kleiner Skalierungseffekt beim Drücken
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    CounterView()
}
