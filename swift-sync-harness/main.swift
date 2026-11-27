import Foundation
import Darwin

struct HarnessStatus: Codable {
    var water: Int
    var counter: Int
    var waterUpdatedAt: Double
    var waterSizesUpdatedAt: Double
    var counterUpdatedAt: Double
    var peers: Int
    var port: UInt16
}

struct HarnessSnapshot: Codable {
    var water: WaterStore.SyncSnapshot
    var counter: CounterStore.SyncSnapshot
}

func emit<T: Encodable>(_ prefix: String, _ value: T) {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(value),
          let text = String(data: data, encoding: .utf8) else {
        return
    }
    print("\(prefix) \(text)")
    fflush(stdout)
}

guard let suiteName = ProcessInfo.processInfo.environment["TOOLBOX_DEFAULTS_SUITE"],
      !suiteName.isEmpty else {
    FileHandle.standardError.write(Data("TOOLBOX_DEFAULTS_SUITE missing\n".utf8))
    exit(2)
}

// Every run gets a fresh, isolated defaults suite.
UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)

let counter = CounterStore()
// The group name is part of the test setup; without it no listener starts.
LocalSync.shared.setSyncName(
    ProcessInfo.processInfo.environment["TOOLBOX_SYNC_NAME"] ?? "Interop",
    restart: false
)
LocalSync.shared.startInteropListener()

var waited = 0.0
while (LocalSync.shared.listeningPort ?? 0) == 0 && waited < 8 {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    waited += 0.05
}

guard let port = LocalSync.shared.listeningPort, port > 0 else {
    FileHandle.standardError.write(Data("Listener port unavailable\n".utf8))
    exit(1)
}

print("READY \(port)")
fflush(stdout)

func handle(_ line: String) {
    let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
    guard let command = parts.first else { return }

    switch command {
    case "addwater":
        guard parts.count > 1, let amount = Int(parts[1]) else { return }
        WaterStore.add(amount)

    case "increment":
        counter.increment()

    case "savecounter":
        let name = parts.count > 1 ? parts[1] : "Interop-Stand"
        counter.saveCurrent(name: name)

    case "setsizes":
        guard parts.count > 1 else { return }
        let values = parts[1].split(separator: " ").compactMap { Int($0) }
        guard values.count == 3 else { return }
        WaterStore.setSizes(glass: values[0], bottle: values[1], goal: values[2])

    case "undowater":
        WaterStore.undoLast()

    case "resetwater":
        WaterStore.reset()

    case "stopsync":
        LocalSync.shared.setEnabled(false)

    case "startsync":
        LocalSync.shared.setEnabled(true)

    case "status":
        emit("STATUS", HarnessStatus(
            water: WaterStore.todayML,
            counter: counter.count,
            waterUpdatedAt: WaterStore.updatedAt?.timeIntervalSinceReferenceDate ?? -1,
            waterSizesUpdatedAt: WaterStore.sizesUpdatedAt?.timeIntervalSinceReferenceDate ?? -1,
            counterUpdatedAt: CounterStore.updatedAt?.timeIntervalSinceReferenceDate ?? -1,
            peers: LocalSync.shared.peerCount,
            port: LocalSync.shared.listeningPort ?? 0
        ))

    case "snapshot":
        emit("SNAPSHOT", HarnessSnapshot(
            water: WaterStore.syncSnapshot(),
            counter: CounterStore.syncSnapshot()
        ))

    case "quit":
        exit(0)

    default:
        break
    }
}

DispatchQueue.global(qos: .userInitiated).async {
    while let line = readLine() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        DispatchQueue.main.async {
            handle(trimmed)
        }
    }
    DispatchQueue.main.async {
        exit(0)
    }
}

RunLoop.main.run()
