//
//  LocalSync.swift
//  Toolbox
//
//  Gleicht Wassertracker und Zähler direkt im lokalen WLAN ab – ohne Server,
//  ohne Konto und ohne Apple-Developer-Account.
//
//  Jedes Gerät bietet einen Bonjour-Dienst (`_toolboxsync._tcp`) an und sucht
//  gleichzeitig nach anderen Geräten. Beim Verbindungsaufbau schicken beide
//  Seiten ihren Stand; pro Bereich gewinnt der zuletzt geänderte Stand.
//  Änderungen werden danach an alle offenen Verbindungen verteilt.
//

import Foundation
import Network
import Combine
import WidgetKit

final class LocalSync: ObservableObject {
    static let shared = LocalSync()

    /// Schalter aus den Einstellungen (Standard: an).
    static let enabledKey = "lan_sync_enabled"

    static let serviceType = "_toolboxsync._tcp"

    /// TXT-Schlüssel, über den Geräte ihren Gruppennamen ankündigen, bevor
    /// eine Verbindung aufgebaut wird.
    static let syncNameTXTKey = "syncname"

    @Published private(set) var isEnabled: Bool
    /// Gemeinsamer Name der Sync-Gruppe. Nur Geräte mit demselben Namen
    /// gleichen sich ab; ohne Namen läuft kein Abgleich.
    @Published private(set) var syncName: String
    @Published private(set) var peerCount = 0
    @Published private(set) var lastSync: Date?
    @Published private(set) var isSearching = false

    private struct Message: Codable {
        var deviceID: String
        var deviceName: String
        var syncName: String?
        var water: WaterStore.SyncSnapshot?
        var counter: CounterStore.SyncSnapshot?
    }

    private enum DefaultsKey {
        static let deviceID = "lan_sync_device_id"
        static let name = "lan_sync_name"
        static let lastSync = "lan_sync_lastSync"
    }

    /// Der headless Interop-Test isoliert auch Geräte-ID und Sync-Schalter
    /// pro Prozess über eine eigene Suite. Die App nutzt weiterhin standard.
    private static let defaults: UserDefaults = {
        if let testSuite = ProcessInfo.processInfo.environment["TOOLBOX_DEFAULTS_SUITE"],
           let suite = UserDefaults(suiteName: testSuite) {
            return suite
        }
        return .standard
    }()

    private let queue = DispatchQueue(label: "Toolbox.LocalSync")
    private let parameters: NWParameters = {
        let parameters = NWParameters.tcp
        // Erlaubt auch direkte Verbindungen ohne Router (AWDL/Peer-to-Peer).
        parameters.includePeerToPeer = true
        return parameters
    }()

    private var listener: NWListener?

    /// Port des lokalen Listeners – nur für den headless Interop-Test.
    var listeningPort: UInt16? { listener?.port?.rawValue }

    private var browser: NWBrowser?
    /// Zuletzt gefundene Peers, um fehlende Verbindungen erneut aufzubauen.
    private var lastResults: Set<NWBrowser.Result> = []
    private var connections: [UUID: NWConnection] = [:]
    private var connectionEndpoints: [UUID: String] = [:]
    /// Geräte-ID je Verbindung, damit dasselbe Gerät nicht doppelt zählt.
    private var connectionPeers: [UUID: String] = [:]
    private var usedEndpoints: [String: UUID] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var pendingBroadcast: DispatchWorkItem?
    /// Entprellt den Neustart, während der Name getippt wird.
    private var nameRestart: DispatchWorkItem?

    private let deviceID: String
    private let deviceName: String

    private init() {
        isEnabled = Self.defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        lastSync = Self.defaults.object(forKey: DefaultsKey.lastSync) as? Date
        syncName = String((Self.defaults.string(forKey: DefaultsKey.name) ?? "").prefix(60))
        deviceName = ProcessInfo.processInfo.hostName

        if let stored = Self.defaults.string(forKey: DefaultsKey.deviceID) {
            deviceID = stored
        } else {
            let newID = UUID().uuidString
            Self.defaults.set(newID, forKey: DefaultsKey.deviceID)
            deviceID = newID
        }
    }

    // MARK: - Steuerung

    /// Ohne Namen ist der Abgleich aus.
    var hasSyncName: Bool { !Self.trimmedName(syncName).isEmpty }

    func start() {
        guard isEnabled, hasSyncName else { return }
        if listener == nil { startListener() }
        if browser == nil { startBrowser() }
        observeChanges()
    }

    /// Startet nur den TCP-Listener ohne Bonjour/Browser – für den headless
    /// Interop-Test. Im normalen App-Betrieb bleibt `start()` unverändert.
    func startInteropListener() {
        guard isEnabled, hasSyncName else { return }
        if listener == nil { startListener(advertise: false) }
        observeChanges()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        Self.defaults.set(enabled, forKey: Self.enabledKey)
        isEnabled = enabled

        if enabled {
            start()
            if hasSyncName { scheduleBroadcast() }
        } else {
            stop()
        }
    }

    /// Setzt den gemeinsamen Namen der Sync-Gruppe. Änderungen werden kurz
    /// entprellt, damit nicht jeder Tastendruck die Suche neu startet.
    /// `restart: false` nur für den headless Interop-Test, der den Listener
    /// selbst und ohne Bonjour startet.
    func setSyncName(_ name: String, restart: Bool = true) {
        let value = String(name.prefix(60))
        guard value != syncName else { return }
        syncName = value
        Self.defaults.set(value, forKey: DefaultsKey.name)

        nameRestart?.cancel()
        nameRestart = nil

        guard restart, isEnabled else { return }

        if !hasSyncName {
            // Ohne Namen darf keine Verbindung bestehen bleiben.
            stop()
            return
        }

        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.restartAfterNameChange() }
        }
        nameRestart = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func restartAfterNameChange() {
        nameRestart = nil
        guard isEnabled, hasSyncName else { return }
        // Beim ersten Eintragen des Namens läuft noch nichts – dann direkt starten.
        if listener != nil || browser != nil { stop() }
        start()
        broadcast()
    }

    /// Sucht erneut nach Geräten und schickt den aktuellen Stand an offene Verbindungen.
    func syncNow() {
        guard isEnabled, hasSyncName else { return }
        start()

        // Immer frisch suchen: Bei mehreren Geräten kann die alte Suche einen
        // Peer verlieren, während die übrigen verbunden bleiben.
        browser?.cancel()
        browser = nil
        startBrowser()

        // Fehlende Peers auch dann erneut verbinden, wenn noch andere Geräte
        // verbunden sind – sonst bleibt eine einzelne verlorene Verbindung
        // unentdeckt, solange peerCount > 0 ist.
        connect(to: lastResults)
        broadcast()
    }

    private func stop() {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        observerTokens = []

        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil

        for id in Array(connections.keys) { drop(id) }

        pendingBroadcast?.cancel()
        pendingBroadcast = nil
        nameRestart?.cancel()
        nameRestart = nil
        lastResults = []
        peerCount = 0
        isSearching = false
    }

    // MARK: - Bonjour

    private func startListener(advertise: Bool = true) {
        do {
            let listener = try NWListener(using: parameters)
            if advertise {
                var txt = NWTXTRecord()
                txt[Self.syncNameTXTKey] = Self.trimmedName(syncName)
                listener.service = NWListener.Service(
                    name: deviceName,
                    type: Self.serviceType,
                    txtRecord: txt
                )
            }

            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor in
                    switch state {
                    case .failed, .cancelled:
                        self.listener?.cancel()
                        self.listener = nil
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { @MainActor in self.accept(connection) }
            }

            listener.start(queue: queue)
            self.listener = listener
        } catch {
            // Port nicht verfügbar o. Ä. – beim nächsten Aktivieren erneut versuchen.
            listener = nil
        }
    }

    private func startBrowser() {
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser else { return }
            Task { @MainActor in
                // Ein bereits ersetzter Browser darf den neuen nicht zurücksetzen.
                guard self.browser === browser else { return }
                switch state {
                case .ready:
                    self.isSearching = true
                case .failed, .cancelled:
                    self.isSearching = false
                    self.browser = nil
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, let browser else { return }
            Task { @MainActor in
                // Ergebnisse einer alten, bereits ersetzten Suche ignorieren.
                guard self.browser === browser else { return }
                // Nur Geräte mit demselben Gruppennamen werden verbunden.
                let matching = results.filter { Self.result($0, matches: self.syncName) }
                self.lastResults = matching
                self.connect(to: matching)
            }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    private func connect(to results: Set<NWBrowser.Result>) {
        guard isEnabled else { return }

        for result in results where Self.result(result, matches: syncName) {
            let key = "\(result.endpoint)"
            guard usedEndpoints[key] == nil else { continue }

            let connection = NWConnection(to: result.endpoint, using: parameters)
            accept(connection, endpoint: key)
        }
    }

    // MARK: - Verbindungen

    private func accept(_ connection: NWConnection, endpoint: String? = nil) {
        let id = UUID()
        connections[id] = connection
        if let endpoint {
            connectionEndpoints[id] = endpoint
            usedEndpoints[endpoint] = id
        }

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
                switch state {
                case .ready:
                    self.sendState(on: connection)
                    self.receive(on: connection, id: id, buffer: Data())
                case .failed, .cancelled:
                    self.drop(id)
                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    private func drop(_ id: UUID) {
        connections[id]?.cancel()
        connections[id] = nil

        if let endpoint = connectionEndpoints[id] {
            connectionEndpoints[id] = nil
            usedEndpoints[endpoint] = nil
        }
        connectionPeers[id] = nil
        peerCount = Set(connectionPeers.values).count
    }

    private func receive(on connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task { @MainActor in
                var buffer = buffer
                if let data { buffer.append(data) }

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = Data(buffer[buffer.startIndex..<newline])
                    buffer = Data(buffer[buffer.index(after: newline)...])
                    self.handle(line, from: id)
                }

                if isComplete || error != nil {
                    self.drop(id)
                } else {
                    self.receive(on: connection, id: id, buffer: buffer)
                }
            }
        }
    }

    // MARK: - Abgleich

    private func sendState(on connection: NWConnection) {
        // Ein Gerät ohne eigene Daten und ohne Änderungszeit schickt keinen
        // leeren Stand mit – sonst könnte es den Stand anderer Geräte als
        // „neuer“ überschreiben.
        let water = (WaterStore.hasData || WaterStore.updatedAt != nil)
            ? WaterStore.syncSnapshot() : nil
        let counter = (CounterStore.hasData || CounterStore.updatedAt != nil)
            ? CounterStore.syncSnapshot() : nil

        let message = Message(
            deviceID: deviceID,
            deviceName: deviceName,
            syncName: Self.trimmedName(syncName),
            water: water,
            counter: counter
        )

        guard var payload = try? JSONEncoder().encode(message) else { return }
        payload.append(0x0A)
        connection.send(content: payload, completion: .contentProcessed { _ in })
    }

    private func handle(_ data: Data, from id: UUID) {
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }

        // Nur Geräte mit demselben Gruppennamen dürfen Daten austauschen.
        // Geräte ohne Namen (ältere Stände) werden ebenfalls abgewiesen.
        guard let remoteName = message.syncName, Self.sameName(remoteName, syncName) else {
            drop(id)
            return
        }

        // Eigene Ankündigung über den eigenen Listener ignorieren.
        guard message.deviceID != deviceID else {
            drop(id)
            return
        }

        connectionPeers[id] = message.deviceID
        peerCount = Set(connectionPeers.values).count

        var peerIsBehind = false
        var applied = false

        if let remote = message.water {
            let local = WaterStore.updatedAt
            // Ohne eigenen Stand (frisches Gerät) immer übernehmen, sonst
            // gewinnt der zuletzt geänderte Stand.
            if local == nil || remote.updatedAt > (local ?? .distantPast) {
                WaterStore.applySync(remote)
                WidgetCenter.shared.reloadAllTimelines()
                applied = true
            } else if let local, local > remote.updatedAt {
                peerIsBehind = true
            }
        }

        if let remote = message.counter {
            let local = CounterStore.updatedAt
            if local == nil || remote.updatedAt > (local ?? .distantPast) {
                CounterStore.applySync(remote)
                applied = true
            } else if let local, local > remote.updatedAt {
                peerIsBehind = true
            }
        }

        if applied {
            NotificationCenter.default.post(name: .syncDidApplyRemote, object: nil)
            markSynced()
            // Übernommenen Stand an die anderen offenen Verbindungen
            // weiterreichen, damit auch Geräte ihn bekommen, die mit dem
            // Ursprung nicht direkt verbunden sind.
            broadcast(excluding: id)
        }

        // Das andere Gerät hat einen älteren Stand: unseren nachschicken.
        if peerIsBehind, let connection = connections[id] {
            sendState(on: connection)
        }
    }

    private func broadcast(excluding excludedID: UUID? = nil) {
        guard isEnabled else { return }
        for (id, connection) in connections where id != excludedID {
            sendState(on: connection)
        }
    }

    private func scheduleBroadcast() {
        guard isEnabled else { return }
        pendingBroadcast?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        pendingBroadcast = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func observeChanges() {
        guard observerTokens.isEmpty else { return }
        let center = NotificationCenter.default

        observerTokens.append(
            center.addObserver(forName: .waterStoreDidChange, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.scheduleBroadcast() }
            }
        )

        observerTokens.append(
            center.addObserver(forName: .counterStoreDidChange, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in self.scheduleBroadcast() }
            }
        )
    }

    private func markSynced() {
        let now = Date()
        lastSync = now
        Self.defaults.set(now, forKey: DefaultsKey.lastSync)
    }

    // MARK: - Namensvergleich

    /// Vergleichsform des Gruppennamens: Leerraum und Groß-/Kleinschreibung
    /// spielen keine Rolle, damit „Familie“ auf allen Geräten gleich zählt.
    private static func normalizedName(_ name: String) -> String {
        name.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .lowercased()
    }

    private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedName(lhs)
        return !left.isEmpty && left == normalizedName(rhs)
    }

    private static func trimmedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Prüft die Bonjour-Ankündigung, bevor eine Verbindung aufgebaut wird.
    private static func result(_ result: NWBrowser.Result, matches name: String) -> Bool {
        guard case let .bonjour(txt) = result.metadata,
              let advertised = txt[syncNameTXTKey] else {
            return false
        }
        return sameName(advertised, name)
    }
}

extension Notification.Name {
    /// Ein neuer Stand von einem anderen Gerät wurde übernommen.
    static let syncDidApplyRemote = Notification.Name("Toolbox.syncDidApplyRemote")
}
