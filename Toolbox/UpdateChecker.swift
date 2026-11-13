import Combine
import Foundation
import SwiftUI

/// Eine neuere, auf GitHub veröffentlichte Version der App.
struct UpdateInfo: Identifiable {
    let version: String
    let notes: String
    let downloadURL: URL
    let pageURL: URL

    var id: String { version }
}

/// Fragt die GitHub-Releases ab und meldet, wenn eine neuere Version bereitsteht.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let automaticChecksKey = "automaticUpdateChecks"

    private static let releasesURL = URL(string: "https://api.github.com/repos/NHoart/Toolbox/releases/latest")!
    private static let lastCheckKey = "lastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    /// Schalter aus den Einstellungen (Standard: an).
    static var automaticChecksEnabled: Bool {
        UserDefaults.standard.object(forKey: automaticChecksKey) as? Bool ?? true
    }

    @Published var availableUpdate: UpdateInfo?
    @Published private(set) var isChecking = false
    @Published var showsNoUpdate = false
    @Published var errorMessage: String?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Prüft beim Start, aber höchstens einmal pro Tag und ohne Fehlermeldung.
    func checkIfNeeded() async {
        #if os(macOS)
        guard Self.automaticChecksEnabled else { return }
        if let lastCheck = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.checkInterval {
            return
        }
        await check(announceResult: false)
        #endif
    }

    /// Prüft auf Wunsch über „Nach Updates suchen…“ im App-Menü.
    func checkManually() async {
        #if os(macOS)
        await check(announceResult: true)
        #endif
    }

    private func check(announceResult: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

            if Self.isVersion(release.version, newerThan: Self.currentVersion) {
                availableUpdate = UpdateInfo(
                    version: Self.displayVersion(release.version),
                    notes: release.notes,
                    downloadURL: release.downloadURL,
                    pageURL: release.pageURL
                )
            } else if announceResult {
                showsNoUpdate = true
            }
        } catch {
            guard announceResult else { return }
            errorMessage = "Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.\n\n\(error.localizedDescription)"
        }
    }

    // MARK: - GitHub

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let url: URL

            enum CodingKeys: String, CodingKey {
                case name
                case url = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }
    }

    private struct Release {
        let version: String
        let notes: String
        let downloadURL: URL
        let pageURL: URL
    }

    private enum UpdateError: LocalizedError {
        case badResponse

        var errorDescription: String? {
            "GitHub hat keine gültige Antwort geliefert."
        }
    }

    private func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: Self.releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.badResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let dmg = release.assets.first { $0.name.lowercased() == "toolbox.dmg" }
            ?? release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }

        return Release(
            version: release.tagName,
            notes: release.body ?? "",
            // Ohne DMG im Release bleibt die Release-Seite als Ziel.
            downloadURL: dmg?.url ?? release.htmlURL,
            pageURL: release.htmlURL
        )
    }

    // MARK: - Versionen

    /// Vergleicht Versionsnummern wie `v1.2.0` und `1.1.0` komponentenweise.
    static func isVersion(_ version: String, newerThan current: String) -> Bool {
        let new = numericParts(of: version)
        let old = numericParts(of: current)

        for index in 0..<max(new.count, old.count) {
            let newPart = index < new.count ? new[index] : 0
            let oldPart = index < old.count ? old[index] : 0
            if newPart != oldPart {
                return newPart > oldPart
            }
        }
        return false
    }

    static func displayVersion(_ version: String) -> String {
        var trimmed = version.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("v") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    private static func numericParts(of version: String) -> [Int] {
        let trimmed = displayVersion(version)
        let core = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        return core.split(separator: ".").map { component in
            Int(component.prefix { $0.isNumber }) ?? 0
        }
    }
}

// MARK: - SwiftUI

/// Hängt den Update-Hinweis an die App und stößt die Prüfung beim Start an.
struct UpdateCheckModifier: ViewModifier {
    @ObservedObject private var checker = UpdateChecker.shared

    func body(content: Content) -> some View {
        content
            .task { await checker.checkIfNeeded() }
            .sheet(item: $checker.availableUpdate) { update in
                UpdateSheet(update: update)
            }
            .alert("Keine Updates", isPresented: $checker.showsNoUpdate) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Du benutzt bereits die neueste Version (\(UpdateChecker.currentVersion)).")
            }
            .alert(
                "Update-Prüfung fehlgeschlagen",
                isPresented: Binding(
                    get: { checker.errorMessage != nil },
                    set: { if !$0 { checker.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(checker.errorMessage ?? "")
            }
    }
}

private struct UpdateSheet: View {
    let update: UpdateInfo

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update verfügbar")
                .font(.title2.bold())

            Text("Version \(update.version) ist verfügbar – du benutzt \(UpdateChecker.currentVersion).")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !update.notes.isEmpty {
                ScrollView {
                    Text((try? AttributedString(markdown: update.notes)) ?? AttributedString(update.notes))
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }

            HStack {
                Button("Später") { dismiss() }
                Spacer()
                Button("Herunterladen") {
                    openURL(update.downloadURL)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
