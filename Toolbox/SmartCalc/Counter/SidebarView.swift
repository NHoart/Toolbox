//
//  SidebarView.swift
//  counter
//

import SwiftUI

/// Seitenleiste mit allen gespeicherten Zählerständen
struct SidebarView: View {
    @ObservedObject var store: CounterStore
    let onSelect: (SavedCounter) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Gespeicherte Stände")
                    .font(.title3.bold())
                Spacer()
                closeButton
            }
            .padding()

            if store.savedCounters.isEmpty {
                Spacer()
                Text("Noch nichts gespeichert.\nTippe oben rechts auf das Speichern-Symbol.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(store.savedCounters) { saved in
                        Button {
                            onSelect(saved)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(saved.name)
                                        .font(.headline)
                                    Text(saved.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(saved.value)")
                                    .font(.title3.monospacedDigit().bold())
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: store.deleteSaved)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(width: 290)
        .frame(maxHeight: .infinity)
        .sidebarBackground()
    }

    // MARK: - Schließen-Button (Liquid Glass ab iOS 26)

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
                    .padding(6)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        } else {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline)
            }
        }
    }
}

// MARK: - Hintergrund der Seitenleiste

private extension View {
    @ViewBuilder
    func sidebarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.background {
                Color.clear
                    .glassEffect(
                        .regular,
                        in: UnevenRoundedRectangle(
                            bottomTrailingRadius: 24, topTrailingRadius: 24
                        )
                    )
                    .ignoresSafeArea(edges: .vertical)
            }
        } else {
            self.background(.regularMaterial, ignoresSafeAreaEdges: .vertical)
        }
    }
}
