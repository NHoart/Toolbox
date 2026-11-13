'use strict'

const assert = require('node:assert/strict')
const { spawn } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const readline = require('node:readline')

const { ToolboxStore } = require('../windows/src/store')
const { SyncService } = require('../windows/src/sync')

const ROOT = path.resolve(__dirname, '..')
const HARNESS = process.env.SWIFT_HARNESS || path.join(ROOT, 'build/sync-harness/toolbox-sync-harness')
const silentLogger = { log() {}, warn() {}, error() {} }

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function waitFor(predicate, message, timeout = 15_000) {
  const started = Date.now()
  while (Date.now() - started < timeout) {
    if (predicate()) return
    await delay(25)
  }
  throw new Error(`Zeitüberschreitung: ${message}`)
}

function createHarness(child) {
  const rl = readline.createInterface({ input: child.stdout, crlfDelay: Infinity })
  const lines = []
  let readyResolve
  let readyReject
  const ready = new Promise((resolve, reject) => {
    readyResolve = resolve
    readyReject = reject
  })
  const statusWaiters = []
  const snapshotWaiters = []

  rl.on('line', line => {
    lines.push(line)

    const readyMatch = /^READY (\d+)$/.exec(line)
    if (readyMatch) {
      readyResolve(Number(readyMatch[1]))
      return
    }

    const statusMatch = /^STATUS (.*)$/.exec(line)
    if (statusMatch) {
      const status = JSON.parse(statusMatch[1])
      const waiter = statusWaiters.shift()
      if (waiter) waiter.resolve(status)
      return
    }

    const snapshotMatch = /^SNAPSHOT (.*)$/.exec(line)
    if (snapshotMatch) {
      const snapshot = JSON.parse(snapshotMatch[1])
      const waiter = snapshotWaiters.shift()
      if (waiter) waiter.resolve(snapshot)
    }
  })

  child.on('exit', code => {
    const error = new Error(`Swift-Harness beendet (${code})`)
    readyReject(error)
    for (const waiter of statusWaiters.splice(0)) waiter.reject(error)
    for (const waiter of snapshotWaiters.splice(0)) waiter.reject(error)
  })

  function request(command, waiters) {
    return new Promise((resolve, reject) => {
      waiters.push({ resolve, reject })
      child.stdin.write(`${command}\n`)
    })
  }

  return {
    ready,
    lines,
    status: () => request('status', statusWaiters),
    snapshot: () => request('snapshot', snapshotWaiters),
  }
}

async function waitForStatus(harness, predicate, message, timeout = 15_000) {
  const started = Date.now()
  let last = null
  while (Date.now() - started < timeout) {
    last = await harness.status()
    if (predicate(last)) return last
    await delay(100)
  }
  throw new Error(`${message}; letzter Status: ${JSON.stringify(last)}`)
}

async function main() {
  if (!fs.existsSync(HARNESS)) {
    throw new Error(`Swift-Harness fehlt: ${HARNESS}. Zuerst scripts/build-sync-harness.sh ausführen.`)
  }

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-interop-'))
  const home = path.join(temp, 'home')
  fs.mkdirSync(home, { recursive: true })
  const suite = `toolbox-interop-${process.pid}-${Date.now()}`
  let stderr = ''

  const child = spawn(HARNESS, [], {
    cwd: ROOT,
    env: { ...process.env, TOOLBOX_DEFAULTS_SUITE: suite, HOME: home },
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  child.stderr.on('data', chunk => {
    stderr += chunk.toString()
  })
  const harness = createHarness(child)

  const windows = new ToolboxStore({ filePath: path.join(temp, 'windows.json') })
  const sync = new SyncService({
    store: windows,
    deviceName: 'Windows-PC',
    discovery: false,
    logger: silentLogger,
  })

  const cleanup = async () => {
    sync.stop()
    windows.dispose()
    if (child.exitCode === null) {
      child.stdin.end()
      child.kill()
      await new Promise(resolve => child.once('exit', resolve))
    }
    fs.rmSync(temp, { recursive: true, force: true })
  }

  try {
    const port = await harness.ready
    sync.start()
    await waitFor(() => sync.listening, 'Windows-Sync-Server startet')
    sync.connectTo('127.0.0.1', port)
    await waitFor(() => sync.peerCount === 1, 'Windows verbindet sich mit dem Swift-Client')
    await waitForStatus(harness, status => status.peers === 1, 'Swift-Client erkennt Windows')

    // Swift legt v1 an; Windows ist bereits verbunden und muss es übernehmen.
    child.stdin.write('addwater 400\n')
    child.stdin.write('increment\n')
    await waitFor(
      () => windows.todayML() === 400 && windows.count === 1,
      'Windows erhält Swift v1'
    )
    const v1Water = windows.waterUpdatedAt()
    const v1Counter = windows.counterUpdatedAt()
    assert.ok(v1Water > 0, 'Windows muss den Swift-Wasser-Zeitstempel erhalten')
    assert.ok(v1Counter > 0, 'Windows muss den Swift-Zähler-Zeitstempel erhalten')

    // Swift legt v2 an; der neuere Stand muss Windows erreichen.
    await delay(200)
    child.stdin.write('addwater 200\n')
    await waitFor(
      () => windows.todayML() === 600 && windows.waterUpdatedAt() > v1Water,
      'Windows erhält Swift v2'
    )
    const v2Water = windows.waterUpdatedAt()
    assert.ok(v2Water > v1Water)

    // Rückrichtung: Eine Windows-Änderung muss im echten Swift-Client ankommen.
    await delay(200)
    windows.addWater(250)
    windows.increment()
    await waitFor(() => windows.todayML() === 850 && windows.count === 2, 'Windows-Änderung lokal')
    const winWater = windows.waterUpdatedAt()
    const winCounter = windows.counterUpdatedAt()
    const swift = await waitForStatus(
      harness,
      status => status.water === 850 && status.counter === 2,
      'Swift erhält die Windows-Änderung'
    )
    assert.ok(
      Math.abs(swift.waterUpdatedAt - winWater) < 0.001,
      'Wasser-Zeitstempel müssen übereinstimmen'
    )
    assert.ok(
      Math.abs(swift.counterUpdatedAt - winCounter) < 0.001,
      'Zähler-Zeitstempel müssen übereinstimmen'
    )

    // Auch ein benannter, gespeicherter Zählerstand muss als echtes Feld ankommen.
    child.stdin.write('savecounter Interop-Stand\n')
    await waitFor(
      () => windows.savedCounters.length === 1
        && windows.savedCounters[0].name === 'Interop-Stand',
      'Windows erhält den gespeicherten Swift-Zählerstand'
    )

    // Ein verspäteter älterer Swift-Stand darf den neueren Windows-Stand nicht überschreiben.
    await delay(800)
    assert.equal(windows.todayML(), 850, 'Ein älterer Swift-Stand darf Windows nicht überschreiben')
    assert.equal(windows.count, 2)

    const swiftSnapshot = await harness.snapshot()
    const winWaterSnapshot = windows.waterSnapshot()
    const winCounterSnapshot = windows.counterSnapshot()
    assert.ok(winWaterSnapshot && winCounterSnapshot)

    assert.deepEqual(swiftSnapshot.water.history, winWaterSnapshot.history)
    assert.deepEqual(swiftSnapshot.water.recentAdds, winWaterSnapshot.recentAdds)
    assert.equal(swiftSnapshot.water.day, winWaterSnapshot.day)
    assert.equal(swiftSnapshot.water.total, winWaterSnapshot.total)
    assert.equal(swiftSnapshot.water.glass, winWaterSnapshot.glass)
    assert.equal(swiftSnapshot.water.bottle, winWaterSnapshot.bottle)
    assert.equal(swiftSnapshot.water.goal, winWaterSnapshot.goal)
    assert.ok(Math.abs(swiftSnapshot.water.updatedAt - winWaterSnapshot.updatedAt) < 0.001)

    assert.equal(swiftSnapshot.counter.count, winCounterSnapshot.count)
    assert.equal(swiftSnapshot.counter.rate, winCounterSnapshot.rate)
    assert.equal(
      swiftSnapshot.counter.savedCounters.length,
      winCounterSnapshot.savedCounters.length
    )
    for (const [index, item] of swiftSnapshot.counter.savedCounters.entries()) {
      const other = winCounterSnapshot.savedCounters[index]
      assert.equal(item.id, other.id)
      assert.equal(item.name, other.name)
      assert.equal(item.value, other.value)
      assert.ok(Math.abs(item.date - other.date) < 0.001)
    }
    assert.ok(Math.abs(swiftSnapshot.counter.updatedAt - winCounterSnapshot.updatedAt) < 0.001)

    console.log('Swift↔Windows-Interop erfolgreich: v1 400, v2 600, Windows 850/Zähler 2, Snapshots identisch.')
  } catch (error) {
    error.message += `\nSwift-stdout:\n${harness.lines.join('\n')}\nSwift-stderr:\n${stderr}`
    throw error
  } finally {
    await cleanup()
  }
}

main().catch(error => {
  console.error('Swift↔Windows-Interop fehlgeschlagen:', error)
  process.exitCode = 1
})
