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

    @Published private(set) var isEnabled: Bool
    @Published private(set) var peerCount = 0
    @Published private(set) var lastSync: Date?
    @Published private(set) var isSearching = false

    private struct Message: Codable {
        var deviceID: String
        var deviceName: String
        var water: WaterStore.SyncSnapshot?
        var counter: CounterStore.SyncSnapshot?
    }

    private enum DefaultsKey {
        static let deviceID = "lan_sync_device_id"
        static let lastSync = "lan_sync_lastSync"
    }

    private let queue = DispatchQueue(label: "Toolbox.LocalSync")
    private let parameters: NWParameters = {
        let parameters = NWParameters.tcp
        // Erlaubt auch direkte Verbindungen ohne Router (AWDL/Peer-to-Peer).
        parameters.includePeerToPeer = true
        return parameters
    }()

    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [UUID: NWConnection] = [:]
    private var connectionEndpoints: [UUID: String] = [:]
    /// Geräte-ID je Verbindung, damit dasselbe Gerät nicht doppelt zählt.
    private var connectionPeers: [UUID: String] = [:]
    private var usedEndpoints: [String: UUID] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var pendingBroadcast: DispatchWorkItem?

    private let deviceID: String
    private let deviceName: String

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        lastSync = UserDefaults.standard.object(forKey: DefaultsKey.lastSync) as? Date
        deviceName = ProcessInfo.processInfo.hostName

        if let stored = UserDefaults.standard.string(forKey: DefaultsKey.deviceID) {
            deviceID = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: DefaultsKey.deviceID)
            deviceID = newID
        }
    }

    // MARK: - Steuerung

    func start() {
        guard isEnabled else { return }
        if listener == nil { startListener() }
        if browser == nil { startBrowser() }
        observeChanges()
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        isEnabled = enabled

        if enabled {
            start()
            scheduleBroadcast()
        } else {
            stop()
        }
    }

    /// Sucht erneut nach Geräten und schickt den aktuellen Stand an offene Verbindungen.
    func syncNow() {
        guard isEnabled else { return }
        start()

        // Nach dem Wechsel in den Vordergrund kann die alte Suche veraltet sein.
        if peerCount == 0 {
            browser?.cancel()
            browser = nil
            startBrowser()
        }

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
        peerCount = 0
        isSearching = false
    }

    // MARK: - Bonjour

    private func startListener() {
        do {
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(name: deviceName, type: Self.serviceType)

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

        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor in
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

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { @MainActor in self.connect(to: results) }
        }

        browser.start(queue: queue)
        self.browser = browser
    }

    private func connect(to results: Set<NWBrowser.Result>) {
        guard isEnabled else { return }

        for result in results {
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
        let message = Message(
            deviceID: deviceID,
            deviceName: deviceName,
            water: WaterStore.syncSnapshot(),
            counter: CounterStore.syncSnapshot()
        )

        guard var payload = try? JSONEncoder().encode(message) else { return }
        payload.append(0x0A)
        connection.send(content: payload, completion: .contentProcessed { _ in })
    }

    private func handle(_ data: Data, from id: UUID) {
        guard let message = try? JSONDecoder().decode(Message.self, from: data) else { return }

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
            let local = WaterStore.updatedAt ?? .distantPast
            if remote.updatedAt > local {
                WaterStore.applySync(remote)
                WidgetCenter.shared.reloadAllTimelines()
                applied = true
            } else if local > remote.updatedAt {
                peerIsBehind = true
            }
        }

        if let remote = message.counter {
            let local = CounterStore.updatedAt ?? .distantPast
            if remote.updatedAt > local {
                CounterStore.applySync(remote)
                applied = true
            } else if local > remote.updatedAt {
                peerIsBehind = true
            }
        }

        if applied {
            NotificationCenter.default.post(name: .syncDidApplyRemote, object: nil)
            markSynced()
        }

        // Das andere Gerät hat einen älteren Stand: unseren nachschicken.
        if peerIsBehind, let connection = connections[id] {
            sendState(on: connection)
        }
    }

    private func broadcast() {
        guard isEnabled else { return }
        for connection in connections.values {
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
        UserDefaults.standard.set(now, forKey: DefaultsKey.lastSync)
    }
}

extension Notification.Name {
    /// Ein neuer Stand von einem anderen Gerät wurde übernommen.
    static let syncDidApplyRemote = Notification.Name("Toolbox.syncDidApplyRemote")
}
