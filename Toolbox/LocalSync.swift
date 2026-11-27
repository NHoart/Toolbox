//
//  LocalSync.swift
//  Toolbox
//
//  Syncs water tracker and counter directly over the local Wi-Fi – without a
//  server, without an account and without an Apple Developer account.
//
//  Every device advertises a Bonjour service (`_toolboxsync._tcp`) and searches
//  for other devices at the same time. When a connection is established both
//  sides send their state; per area the most recently changed state wins.
//  Afterwards changes are distributed to all open connections.
//

import Foundation
import Network
import Combine
import WidgetKit

final class LocalSync: ObservableObject {
    static let shared = LocalSync()

    /// Switch from Settings (default: on).
    static let enabledKey = "lan_sync_enabled"

    static let serviceType = "_toolboxsync._tcp"

    /// TXT key through which devices announce their group name before
    /// a connection is established.
    static let syncNameTXTKey = "syncname"

    @Published private(set) var isEnabled: Bool
    /// Shared name of the sync group. Only devices with the same name
    /// sync with each other; without a name no sync runs.
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

    /// The headless interop test also isolates device ID and sync switch
    /// per process through its own suite. The app still uses the standard one.
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
        // Also allows direct connections without a router (AWDL/peer-to-peer).
        parameters.includePeerToPeer = true
        return parameters
    }()

    private var listener: NWListener?

    /// Port of the local listener – only for the headless interop test.
    var listeningPort: UInt16? { listener?.port?.rawValue }

    private var browser: NWBrowser?
    /// Zuletzt gefundene Peers, um fehlende Verbindungen erneut aufzubauen.
    private var lastResults: Set<NWBrowser.Result> = []
    private var connections: [UUID: NWConnection] = [:]
    private var connectionEndpoints: [UUID: String] = [:]
    /// Device ID per connection so the same device is not counted twice.
    private var connectionPeers: [UUID: String] = [:]
    private var usedEndpoints: [String: UUID] = [:]
    private var observerTokens: [NSObjectProtocol] = []
    private var pendingBroadcast: DispatchWorkItem?
    /// Debounces the restart while the name is being typed.
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

    /// Without a name the sync is off.
    var hasSyncName: Bool { !Self.trimmedName(syncName).isEmpty }

    func start() {
        guard isEnabled, hasSyncName else { return }
        if listener == nil { startListener() }
        if browser == nil { startBrowser() }
        observeChanges()
    }

    /// Starts only the TCP listener without Bonjour/browsing – for the headless
    /// interop test. In normal app operation `start()` stays unchanged.
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

    /// Sets the shared name of the sync group. Changes are
    /// debounced briefly so not every keystroke restarts the search.
    /// `restart: false` only for the headless interop test, which starts the listener
    /// itself and without Bonjour.
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
        // Nothing runs yet on the first entry of the name – start right away then.
        if listener != nil || browser != nil { stop() }
        start()
        broadcast()
    }

    /// Searches for devices again and sends the current state to open connections.
    func syncNow() {
        guard isEnabled, hasSyncName else { return }
        start()

        // Always search afresh: with several devices the old search can
        // lose a peer while the others stay connected.
        browser?.cancel()
        browser = nil
        startBrowser()

        // Reconnect missing peers even when other devices are
        // still connected – otherwise a single lost connection stays
        // undetected as long as peerCount > 0.
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
            // Port unavailable or similar – try again on the next activation.
            listener = nil
        }
    }

    private func startBrowser() {
        // Only with `bonjourWithTXTRecord` does Network.framework deliver the
        // TXT data. With `.bonjour`, `result.metadata` would always be `.none`,
        // so the name filter would discard every device.
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: Self.serviceType, domain: nil),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, let browser else { return }
            Task { @MainActor in
                // An already replaced browser must not reset the new one.
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
                // Ignore results from an old, already replaced search.
                guard self.browser === browser else { return }
                // Only devices with the same group name are connected.
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
        // A device without its own data and without a change time sends no
        // empty state – otherwise it could overwrite the state of other devices as
        // "newer".
        let water = (WaterStore.hasData || WaterStore.updatedAt != nil || WaterStore.sizesUpdatedAt != nil)
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

        // Only devices with the same group name may exchange data.
        // Devices without a name (older states) are rejected as well.
        guard let remoteName = message.syncName, Self.sameName(remoteName, syncName) else {
            drop(id)
            return
        }

        // Ignore our own announcement through our own listener.
        guard message.deviceID != deviceID else {
            drop(id)
            return
        }

        connectionPeers[id] = message.deviceID
        peerCount = Set(connectionPeers.values).count

        var peerIsBehind = false
        var applied = false

        if let remote = message.water {
            // Amounts and sizes are merged independently: a device that only
            // changed a size keeps its old amount timestamp and must not
            // overwrite newer amounts of this device.
            let result = WaterStore.mergeSync(remote)
            if result.applied {
                WidgetCenter.shared.reloadAllTimelines()
                applied = true
            }
            if result.peerIsBehind { peerIsBehind = true }
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
            // Pass the adopted state on to the other open
            // connections so devices that are not directly connected
            // to the origin receive it too.
            broadcast(excluding: id)
        }

        // The other device has an older state: send ours afterwards.
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

    /// Comparison form of the group name: whitespace and upper/lower case
    /// do not matter, so "Family" counts the same on all devices.
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

    /// Checks the Bonjour announcement before a connection is established.
    private static func result(_ result: NWBrowser.Result, matches name: String) -> Bool {
        guard case let .bonjour(txt) = result.metadata,
              let advertised = txt[syncNameTXTKey] else {
            return false
        }
        return sameName(advertised, name)
    }
}

extension Notification.Name {
    /// A new state from another device was adopted.
    static let syncDidApplyRemote = Notification.Name("Toolbox.syncDidApplyRemote")
}
