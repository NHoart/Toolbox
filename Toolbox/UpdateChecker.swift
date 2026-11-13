import Combine
import Foundation
import SwiftUI

#if os(macOS)
import AppKit
import CryptoKit
import Security
#endif

/// Eine neuere, auf GitHub veröffentlichte Version der App.
struct UpdateInfo: Identifiable {
    let version: String
    let notes: String
    let downloadURL: URL
    let pageURL: URL
    let digest: String?

    var id: String { version }
    var isDMG: Bool { downloadURL.pathExtension.lowercased() == "dmg" }
}

/// Ergebnis einer manuell ausgelösten Prüfung.
enum UpdateCheckOutcome {
    case update(UpdateInfo)
    case upToDate
    case failed(String)
}

/// Fragt die GitHub-Releases ab und meldet, wenn eine neuere Version bereitsteht.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let automaticChecksKey = "automaticUpdateChecks"

    private static let releasesURL = URL(string: "https://api.github.com/repos/NHoart/Toolbox/releases/latest")!
    private static let lastCheckKey = "lastUpdateCheckDate"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    @Published var availableUpdate: UpdateInfo?
    @Published private(set) var isChecking = false
    @Published var showsNoUpdate = false
    @Published var errorMessage: String?
    @Published private(set) var isInstalling = false
    @Published private(set) var downloadProgress: Double?
    @Published var installError: String?

    /// Schalter aus den Einstellungen (Standard: an).
    static var automaticChecksEnabled: Bool {
        UserDefaults.standard.object(forKey: automaticChecksKey) as? Bool ?? true
    }

    nonisolated static var currentVersion: String {
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

    /// Ob die laufende App sich selbst ersetzen kann.
    func canInstall(_ update: UpdateInfo) -> Bool {
        #if os(macOS)
        return update.isDMG
            && update.digest != nil
            && UpdateInstaller.canReplaceRunningApp(at: Bundle.main.bundleURL)
        #else
        return false
        #endif
    }

    /// Lädt die DMG, prüft sie und ersetzt die installierte App.
    func install(_ update: UpdateInfo) async {
        #if os(macOS)
        guard !isInstalling else { return }
        isInstalling = true
        installError = nil
        downloadProgress = 0

        do {
            try await UpdateInstaller.install(update) { [weak self] fraction in
                guard let self = self else { return }
                Task { @MainActor in
                    self.downloadProgress = fraction
                }
            }
            quitForInstall()
        } catch {
            installError = error.localizedDescription
            downloadProgress = nil
        }

        isInstalling = false
        #endif
    }

    #if os(macOS)
    /// Beendet die App, damit der Installer sie ersetzen kann.
    /// `NSApp.terminate` allein genügt nicht: Bei geöffnetem Update-Sheet
    /// ignoriert AppKit die Anfrage und die App läuft weiter – der Installer
    /// wartet dann endlos auf das Prozessende.
    private func quitForInstall() {
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            exit(EXIT_SUCCESS)
        }
    }
    #endif

    private func check(announceResult: Bool) async {
        switch await checkForUpdates() {
        case .update(let info):
            availableUpdate = info
        case .upToDate:
            if announceResult { showsNoUpdate = true }
        case .failed(let message):
            if announceResult {
                errorMessage = "Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.\n\n\(message)"
            }
        }
    }

    /// Prüft, ohne die globalen Hinweise des Hauptfensters zu setzen.
    /// Wird aus den Einstellungen verwendet, wo ein eigener Status erscheint.
    func checkForUpdates() async -> UpdateCheckOutcome {
        guard !isChecking else { return .upToDate }
        isChecking = true
        defer { isChecking = false }

        do {
            let release = try await fetchLatestRelease()
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)

            if Self.isVersion(release.version, newerThan: Self.currentVersion) {
                return .update(UpdateInfo(
                    version: Self.displayVersion(release.version),
                    notes: release.notes,
                    downloadURL: release.downloadURL,
                    pageURL: release.pageURL,
                    digest: release.digest
                ))
            }
            return .upToDate
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - GitHub

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let url: URL
            let digest: String?

            enum CodingKeys: String, CodingKey {
                case name
                case url = "browser_download_url"
                case digest
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
        let digest: String?
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
            pageURL: release.htmlURL,
            digest: dmg?.digest
        )
    }

    // MARK: - Versionen

    /// Vergleicht Versionsnummern wie `v1.2.0` und `1.1.0` komponentenweise.
    nonisolated static func isVersion(_ version: String, newerThan current: String) -> Bool {
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

    nonisolated static func displayVersion(_ version: String) -> String {
        var trimmed = version.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("v") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    nonisolated private static func numericParts(of version: String) -> [Int] {
        let trimmed = displayVersion(version)
        let core = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        return core.split(separator: ".").map { component in
            Int(component.prefix { $0.isNumber }) ?? 0
        }
    }
}

// MARK: - Installation

#if os(macOS)
/// Lädt die DMG, prüft Prüfsumme und Signatur und ersetzt die installierte App.
enum UpdateInstaller {
    private static let bundleID = "com.noahsapps.Toolbox"

    private struct InstallError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Räumt Reste abgebrochener Update-Läufe auf: heruntergeladene DMGs,
    /// entpackte Apps sowie Staging- und Backup-Bundles. Solange ein Installer
    /// läuft (Lock mit lebender PID), bleibt alles unangetastet.
    nonisolated static func cleanUpStaleData() {
        let fm = FileManager.default
        let lock = fm.temporaryDirectory.appendingPathComponent("ToolboxUpdate.lock", isDirectory: true)
        let lockPID = (try? String(contentsOf: lock.appendingPathComponent("pid"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let lockPID, let pid = pid_t(lockPID), pid > 0,
           kill(pid, 0) == 0 || errno == EPERM {
            return
        }

        if let entries = try? fm.contentsOfDirectory(at: fm.temporaryDirectory, includingPropertiesForKeys: nil) {
            for entry in entries where entry.lastPathComponent.hasPrefix("ToolboxUpdate-") {
                try? fm.removeItem(at: entry)
            }
        }

        // Nur Backups löschen, wenn die installierte App noch vorhanden ist.
        let appURL = Bundle.main.bundleURL
        let parent = appURL.deletingLastPathComponent()
        if let entries = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil) {
            for entry in entries {
                let name = entry.lastPathComponent
                if name.hasPrefix(".Toolbox-update-") {
                    try? fm.removeItem(at: entry)
                } else if name.hasPrefix(".Toolbox-backup-"), fm.fileExists(atPath: appURL.path) {
                    try? fm.removeItem(at: entry)
                }
            }
        }

        if fm.fileExists(atPath: lock.path) {
            try? fm.removeItem(at: lock)
        }
    }

    /// Nur Apps unter /Applications bzw. ~/Applications dürfen sich selbst ersetzen.
    static func canReplaceRunningApp(at appURL: URL) -> Bool {
        // In einer Sandbox kann kein Hilfsprozess zum Austauschen gestartet werden.
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil else {
            return false
        }

        let path = appURL.path
        guard path.hasSuffix(".app") else { return false }
        guard !path.contains("/AppTranslocation/") else { return false }
        guard path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/") else {
            return false
        }
        return FileManager.default.isWritableFile(atPath: appURL.deletingLastPathComponent().path)
    }

    static func install(_ update: UpdateInfo, progress: @escaping @Sendable (Double?) -> Void) async throws {
        guard let digest = update.digest else {
            throw InstallError(message: "Im Release fehlt die Prüfsumme der DMG.")
        }

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolboxUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

            let destination = workDir.appendingPathComponent("Toolbox.dmg")
            let download = try await download(from: update.downloadURL, to: destination, progress: progress)
            progress(nil)

            try verify(download, sha256: digest)

            let newApp = try extractApp(from: download, into: workDir)
            try validate(newApp, expectedVersion: update.version)
            try scheduleInstall(newApp: newApp, target: Bundle.main.bundleURL)
        } catch {
            progress(nil)
            try? FileManager.default.removeItem(at: workDir)
            throw error
        }
    }

    // MARK: Download

    private static func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let downloader = DMGDownloader(destination: destination, progress: progress) { result in
                continuation.resume(with: result)
            }
            downloader.start(url)
        }
    }

    private final class DMGDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        private let destination: URL
        private let progress: @Sendable (Double?) -> Void
        private let completion: (Result<URL, Error>) -> Void
        private var session: URLSession?
        private var finished = false

        init(
            destination: URL,
            progress: @escaping @Sendable (Double?) -> Void,
            completion: @escaping (Result<URL, Error>) -> Void
        ) {
            self.destination = destination
            self.progress = progress
            self.completion = completion
        }

        func start(_ url: URL) {
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            self.session = session
            session.downloadTask(with: url).resume()
        }

        private func finish(_ result: Result<URL, Error>) {
            guard !finished else { return }
            finished = true
            session?.finishTasksAndInvalidate()
            session = nil
            completion(result)
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard let http = downloadTask.response as? HTTPURLResponse, http.statusCode == 200 else {
                finish(.failure(InstallError(message: "Die DMG konnte nicht heruntergeladen werden.")))
                return
            }

            do {
                try FileManager.default.copyItem(at: location, to: destination)
                finish(.success(destination))
            } catch {
                finish(.failure(error))
            }
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error {
                finish(.failure(error))
            }
        }
    }

    // MARK: Prüfungen

    private static func verify(_ file: URL, sha256 digest: String) throws {
        let normalized = digest.lowercased()
        guard normalized.hasPrefix("sha256:") else {
            throw InstallError(message: "Unbekanntes Prüfsummenformat im Release.")
        }

        let expected = String(normalized.dropFirst("sha256:".count))
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        guard actual == expected else {
            throw InstallError(message: "Die heruntergeladene DMG ist beschädigt (Prüfsumme stimmt nicht).")
        }
    }

    private static func validate(_ app: URL, expectedVersion: String) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == bundleID,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            throw InstallError(message: "Die DMG enthält nicht die erwartete Toolbox-App.")
        }

        guard version == UpdateChecker.displayVersion(expectedVersion),
              UpdateChecker.isVersion(version, newerThan: UpdateChecker.currentVersion) else {
            throw InstallError(message: "Die Version in der DMG passt nicht zum Release.")
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode,
              SecStaticCodeCheckValidity(staticCode, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), nil) == errSecSuccess else {
            throw InstallError(message: "Die Signatur der neuen App ist ungültig.")
        }
    }

    // MARK: DMG

    private static func extractApp(from dmg: URL, into workDir: URL) throws -> URL {
        let mountPoint = workDir.appendingPathComponent("mnt", isDirectory: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        try run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mountPoint.path, dmg.path])
        defer { try? run("/usr/bin/hdiutil", ["detach", mountPoint.path]) }

        let apps = try FileManager.default
            .contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { $0.pathExtension.lowercased() == "app" }

        guard apps.count == 1, let source = apps.first else {
            throw InstallError(message: "Die DMG enthält nicht genau eine App.")
        }

        let destination = workDir.appendingPathComponent("Toolbox.app")
        try run("/usr/bin/ditto", [source.path, destination.path])
        return destination
    }

    // MARK: Austausch

    private static func scheduleInstall(newApp: URL, target: URL) throws {
        let workDir = newApp.deletingLastPathComponent()
        let script = workDir.appendingPathComponent("install.sh")
        let log = workDir.appendingPathComponent("install.log")
        let pid = ProcessInfo.processInfo.processIdentifier

        // Die neue App wird erst neben das Ziel kopiert und dann getauscht.
        // Früher wurde die alte App zuerst gelöscht – schlug das Kopieren fehl,
        // war sie weg. Bei einem Fehler wird die alte Version wieder geöffnet.
        let content = """
        #!/bin/sh
        set -u

        TARGET=\(shellQuoted(target.path))
        SOURCE=\(shellQuoted(newApp.path))
        WORK=\(shellQuoted(workDir.path))
        PID=\(pid)

        exec >>\(shellQuoted(log.path)) 2>&1
        echo "[$(date)] Update wird vorbereitet."

        # Nur ein Installer gleichzeitig – ein alter, hängender Lauf darf nicht
        # dazwischenfunken. Ein verwaister Lock wird übernommen.
        LOCK="${TMPDIR:-/tmp}/ToolboxUpdate.lock"
        if ! mkdir "$LOCK" 2>/dev/null; then
            OTHER="$(cat "$LOCK/pid" 2>/dev/null || true)"
            if [ -n "$OTHER" ] && kill -0 "$OTHER" 2>/dev/null; then
                echo "Ein anderes Update läuft bereits (PID $OTHER)."
                exit 0
            fi
            rm -rf "$LOCK"
            mkdir "$LOCK" 2>/dev/null || exit 0
        fi
        echo "$$" > "$LOCK/pid"
        trap 'rm -rf "$LOCK"' EXIT

        # Auf das Ende der laufenden App warten (höchstens 30 Sekunden).
        WAITED=0
        while kill -0 "$PID" 2>/dev/null; do
            if [ "$WAITED" -ge 150 ]; then
                echo "Die App wurde nicht beendet; Update abgebrochen."
                exit 1
            fi
            WAITED=$((WAITED + 1))
            sleep 0.2
        done

        PARENT="$(dirname "$TARGET")"
        STAGED="$PARENT/.Toolbox-update-$$.app"
        BACKUP="$PARENT/.Toolbox-backup-$$.app"

        reopen_target() {
            /usr/bin/open "$TARGET" 2>/dev/null || true
        }

        rm -rf "$STAGED" "$BACKUP" 2>/dev/null || true

        if ! /usr/bin/ditto "$SOURCE" "$STAGED" || [ ! -f "$STAGED/Contents/Info.plist" ]; then
            echo "Die neue App konnte nicht vorbereitet werden."
            rm -rf "$STAGED"
            reopen_target
            exit 1
        fi

        /usr/bin/xattr -dr com.apple.quarantine "$STAGED" 2>/dev/null || true

        if ! mv "$TARGET" "$BACKUP"; then
            echo "Die alte App konnte nicht gesichert werden."
            rm -rf "$STAGED"
            reopen_target
            exit 1
        fi

        if ! mv "$STAGED" "$TARGET"; then
            echo "Die neue App konnte nicht eingesetzt werden; die alte Version wird wiederhergestellt."
            mv "$BACKUP" "$TARGET" 2>/dev/null || true
            rm -rf "$STAGED"
            reopen_target
            exit 1
        fi

        rm -rf "$BACKUP" 2>/dev/null || true

        # Neu starten; LaunchServices braucht manchmal einen Moment.
        ATTEMPTS=0
        until /usr/bin/open "$TARGET" 2>/dev/null; do
            ATTEMPTS=$((ATTEMPTS + 1))
            if [ "$ATTEMPTS" -ge 10 ]; then
                echo "Die App konnte nicht automatisch geöffnet werden. Bitte manuell starten."
                exit 1
            fi
            sleep 1
        done

        echo "[$(date)] Update abgeschlossen."
        rm -rf "$WORK"
        """

        try content.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw InstallError(message: "Der Neustart konnte nicht vorbereitet werden: \(error.localizedDescription)")
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw InstallError(message: "\(tool) konnte nicht gestartet werden: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw InstallError(message: "\(tool) ist fehlgeschlagen. \(message)")
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
#endif

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

struct UpdateSheet: View {
    let update: UpdateInfo

    @ObservedObject private var checker = UpdateChecker.shared
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
                .frame(maxHeight: 180)
            }

            if let error = checker.installError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if checker.canInstall(update) {
                Text("Toolbox lädt die neue Version, ersetzt die installierte App und startet neu.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Später") { dismiss() }
                    .disabled(checker.isInstalling)

                Spacer()

                if checker.isInstalling {
                    if let progress = checker.downloadProgress {
                        ProgressView(value: progress)
                            .frame(width: 180)
                        Text("Wird geladen … \(Int(progress * 100)) %")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                        Text("Wird installiert…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else if checker.canInstall(update) {
                    Button("Installieren und neu starten") {
                        Task { await checker.install(update) }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Herunterladen") {
                        openURL(update.downloadURL)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
