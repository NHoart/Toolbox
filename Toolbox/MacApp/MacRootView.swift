#if os(macOS)
import SwiftUI

// MARK: - Werkzeuge

/// Farbliche Zuordnung der Werkzeuge in der Seitenleiste.
private extension AppTab {
    var tint: Color {
        switch self {
        case .today: MacTheme.accent
        case .history: MacTheme.mint
        case .units: MacTheme.cyan
        case .counter: MacTheme.violet
        case .download: MacTheme.pink
        case .energy: MacTheme.amber
        }
    }
}

// MARK: - Hauptansicht

/// Mac-Oberfläche: Seitenleiste links, verglaste Werkzeuge rechts.
/// Wird nur in der Mac-App verwendet; iPhone, iPad und Vision Pro behalten die Tableiste.
struct MacRootView: View {
    @Binding var selection: AppTab
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            MacSidebar(selection: $selection)
                .frame(width: 246)

            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 600)
        .background {
            MacBackdrop()
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showSettings) {
            MacSettingsSheet()
        }
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .today:
            MacWaterTodayPage(showSettings: $showSettings)
        case .history:
            MacHistoryPage(showSettings: $showSettings)
        case .units:
            MacUnitsPage(showSettings: $showSettings)
        case .counter:
            MacCounterPage(showSettings: $showSettings)
        case .download:
            MacDownloadPage(showSettings: $showSettings)
        case .energy:
            MacEnergyPage(showSettings: $showSettings)
        }
    }
}

// MARK: - Seitenleiste

private struct MacSidebar: View {
    @Binding var selection: AppTab
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MacTheme.counterGradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: MacTheme.accent.opacity(0.45), radius: 9, y: 4)

                    Image(systemName: "drop.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Toolbox")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Alltagswerkzeuge")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 22)

            Text("WERKZEUGE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)

            VStack(spacing: 3) {
                ForEach(AppTab.allCases) { tool in
                    MacSidebarRow(
                        tool: tool,
                        isSelected: selection == tool
                    ) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selection = tool
                        }
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(scheme == .dark ? 0.05 : 0.25), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(width: 1)
        }
    }
}

private struct MacSidebarRow: View {
    let tool: AppTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var scheme

    private var backgroundOpacity: Double {
        if isSelected { return scheme == .dark ? 0.16 : 0.10 }
        return isHovering ? (scheme == .dark ? 0.07 : 0.05) : 0
    }

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tool.tint, tool.tint.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: tool.tint.opacity(isSelected ? 0.45 : 0.18), radius: 5, y: 2)

                Text(tool.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowShape.fill(.primary.opacity(backgroundOpacity)))
            .overlay {
                rowShape.strokeBorder(
                    Color.white.opacity(isSelected ? (scheme == .dark ? 0.22 : 0.75) : 0),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .contentShape(rowShape)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    MacRootView(selection: .constant(.today))
}
#endif
