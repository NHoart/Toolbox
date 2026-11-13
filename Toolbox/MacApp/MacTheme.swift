#if os(macOS)
import SwiftUI

// MARK: - Farben

/// Farbwelt der Mac-App: kräftige Wassertöne, die durch die Glasflächen scheinen.
enum MacTheme {
    static let accent = Color(red: 0.16, green: 0.55, blue: 1.00)
    static let cyan = Color(red: 0.20, green: 0.83, blue: 0.93)
    static let violet = Color(red: 0.55, green: 0.40, blue: 1.00)
    static let pink = Color(red: 1.00, green: 0.45, blue: 0.65)
    static let mint = Color(red: 0.30, green: 0.86, blue: 0.60)
    static let amber = Color(red: 1.00, green: 0.72, blue: 0.32)

    static let waterGradient = LinearGradient(
        colors: [accent, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let counterGradient = LinearGradient(
        colors: [accent, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hintergrund

/// Weicher, farbiger Hintergrund, der den Glasflächen Tiefe gibt.
struct MacBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
             ? Color(red: 0.045, green: 0.050, blue: 0.075)
             : Color(red: 0.945, green: 0.955, blue: 0.980))

            glow(MacTheme.accent, size: 860, x: -430, y: -330, dark: 0.60, light: 0.30)
            glow(MacTheme.violet, size: 780, x: 450, y: -300, dark: 0.50, light: 0.24)
            glow(MacTheme.cyan, size: 700, x: -300, y: 470, dark: 0.34, light: 0.20)
            glow(MacTheme.pink, size: 620, x: 500, y: 470, dark: 0.26, light: 0.14)
            glow(MacTheme.violet, size: 900, x: 80, y: 60, dark: 0.14, light: 0.10)
        }
    }

    private func glow(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat,
                      dark: Double, light: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(scheme == .dark ? dark : light),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .blendMode(scheme == .dark ? .plusLighter : .normal)
    }
}

// MARK: - Oberflächen

enum MacSurface {
    /// Dezente Fläche für Felder und Zeilen.
    static func fill(_ scheme: ColorScheme, _ strong: Bool = false) -> Color {
        scheme == .dark
        ? Color.white.opacity(strong ? 0.12 : 0.07)
        : Color.black.opacity(strong ? 0.08 : 0.045)
    }

    /// Helle Kante, die die Glasflächen wie Licht reflektieren lässt.
    static func stroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.60)
    }

    static func rowFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)
    }
}

// MARK: - Glaskarte

private struct MacGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let padding: CGFloat

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .glassEffect(.regular.tint(tint), in: shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.24 : 0.85),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 22, y: 12)
    }
}

extension View {
    /// Bringt die View auf eine Liquid-Glass-Karte.
    func macGlassCard(cornerRadius: CGFloat = 26,
                      tint: Color? = nil,
                      padding: CGFloat = 22) -> some View {
        modifier(MacGlassCardModifier(cornerRadius: cornerRadius, tint: tint, padding: padding))
    }
}

// MARK: - Bausteine

/// Kleine, gesperrte Überschrift innerhalb einer Karte.
struct MacCardHeader: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var tint: Color = MacTheme.accent

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
    }
}

/// Kennzahl-Kachel (z. B. Durchschnitt, Ziel, bester Tag).
struct MacMetricTile: View {
    let title: LocalizedStringKey
    let value: String
    var detail: String?
    let systemImage: String
    let tint: Color

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 23, height: 23)
                    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .macGlassCard(cornerRadius: 20, tint: tint.opacity(0.10), padding: 16)
    }
}

/// Eingabefeld im Glas-Look.
struct MacField: View {
    let title: LocalizedStringKey
    let placeholder: String
    var unit: String?
    @Binding var text: String
    var onSubmit: (() -> Void)?

    @Environment(\.colorScheme) private var scheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }

                if let unit {
                    Text(unit)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(MacSurface.fill(scheme))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isFocused ? MacTheme.accent.opacity(0.6) : MacSurface.stroke(scheme),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .onTapGesture { isFocused = true }
            .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

/// Großer runder Aktionsknopf (Plus/Minus im Zähler).
struct MacCircleButton: View {
    let systemImage: String
    let tint: Color
    let size: CGFloat
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.72)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.40), radius: 14, y: 7)
        }
        .buttonStyle(MacPressButtonStyle())
        .opacity(isEnabled ? 1 : 0.38)
        .disabled(!isEnabled)
    }
}

/// Kurzer Skalierungseffekt beim Drücken.
struct MacPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Seitenrahmen

/// Kopfzeile jeder Mac-Seite mit großem Titel und Einstellungen-Zahnrad.
struct MacPageHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var showSettings: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Einstellungen")
        }
    }
}

/// Scrollbarer Seitenrahmen mit einheitlichem Rand und Kopfzeile.
struct MacPage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var showSettings: Bool
    private let content: Content

    init(title: LocalizedStringKey,
         subtitle: LocalizedStringKey,
         showSettings: Binding<Bool>,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self._showSettings = showSettings
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MacPageHeader(title: title, subtitle: subtitle, showSettings: $showSettings)
                content
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .padding(.bottom, 30)
            .frame(maxWidth: 1060, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .defaultScrollAnchor(.top)
    }
}
#endif
