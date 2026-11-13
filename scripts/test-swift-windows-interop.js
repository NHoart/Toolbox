'use strict'

const assert = require('node:assert/strict')
const { spawn } = require('node:child_process')
const fs = require('node:fs')
const net = require('node:net')
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

function createSwiftClient(name, suite, home) {
  let stderr = ''
  const child = spawn(HARNESS, [], {
    cwd: ROOT,
    env: { ...process.env, TOOLBOX_DEFAULTS_SUITE: suite, HOME: home },
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  child.stderr.on('data', chunk => {
    stderr += chunk.toString()
  })
  return { name, child, harness: createHarness(child), get stderr() { return stderr } }
}

function createCaptureProxy(targetPort) {
  const captured = []
  const sockets = new Set()
  const server = net.createServer(client => {
    sockets.add(client)
    const upstream = net.createConnection({ host: '127.0.0.1', port: targetPort })
    sockets.add(upstream)

    let buffer = ''
    upstream.on('data', chunk => {
      buffer += chunk.toString('utf8')
      let newline
      while ((newline = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, newline)
        buffer = buffer.slice(newline + 1)
        captured.push(line)
        if (!client.destroyed) client.write(`${line}\n`)
      }
    })

    client.on('data', chunk => {
      if (!upstream.destroyed) upstream.write(chunk)
    })

    const destroy = () => {
      if (!client.destroyed) client.destroy()
      if (!upstream.destroyed) upstream.destroy()
    }
    client.on('error', destroy)
    upstream.on('error', destroy)
    client.on('close', () => {
      sockets.delete(client)
      if (!upstream.destroyed) upstream.destroy()
    })
    upstream.on('close', () => {
      sockets.delete(upstream)
      if (!client.destroyed) client.destroy()
    })
  })

  return new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', () => {
      resolve({
        port: server.address().port,
        captured,
        close: () => new Promise(resolveClose => {
          for (const socket of sockets) socket.destroy()
          server.close(() => resolveClose())
        }),
      })
    })
  })
}

function replayWireLine(port, line) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port })
    let done = false
    const finish = error => {
      if (done) return
      done = true
      if (error) reject(error)
      else resolve()
    }

    socket.once('error', finish)
    socket.once('connect', () => {
      socket.write(`${line}\n`)
      setTimeout(() => {
        socket.end()
        finish()
      }, 300)
    })
    socket.once('close', () => finish())
  })
}

function findOldWaterLine(lines, total) {
  for (const line of lines) {
    try {
      const message = JSON.parse(line)
      if (message.water?.total !== total) continue
      const saved = message.counter?.savedCounters
      if (!Array.isArray(saved) || saved.length === 0) return line
    } catch {
      // Keine gültige Zeile; weitersuchen.
    }
  }
  return null
}

function assertSnapshot(label, swift, winWater, winCounter) {
  assert.ok(winWater && winCounter, `${label}: Windows-Snapshot fehlt`)

  assert.deepEqual(swift.water.history, winWater.history, `${label}: history`)
  assert.deepEqual(swift.water.recentAdds, winWater.recentAdds, `${label}: recentAdds`)
  assert.equal(swift.water.day, winWater.day, `${label}: day`)
  assert.equal(swift.water.total, winWater.total, `${label}: total`)
  assert.equal(swift.water.glass, winWater.glass, `${label}: glass`)
  assert.equal(swift.water.bottle, winWater.bottle, `${label}: bottle`)
  assert.equal(swift.water.goal, winWater.goal, `${label}: goal`)
  assert.ok(
    Math.abs(swift.water.updatedAt - winWater.updatedAt) < 0.001,
    `${label}: Wasser-Zeitstempel`
  )

  assert.equal(swift.counter.count, winCounter.count, `${label}: count`)
  assert.equal(swift.counter.rate, winCounter.rate, `${label}: rate`)
  assert.equal(
    swift.counter.savedCounters.length,
    winCounter.savedCounters.length,
    `${label}: savedCounters-Länge`
  )
  for (const [index, item] of swift.counter.savedCounters.entries()) {
    const other = winCounter.savedCounters[index]
    assert.equal(item.id, other.id, `${label}: saved id ${index}`)
    assert.equal(item.name, other.name, `${label}: saved name ${index}`)
    assert.equal(item.value, other.value, `${label}: saved value ${index}`)
    assert.ok(Math.abs(item.date - other.date) < 0.001, `${label}: saved date ${index}`)
  }
  assert.ok(
    Math.abs(swift.counter.updatedAt - winCounter.updatedAt) < 0.001,
    `${label}: Zähler-Zeitstempel`
  )
}

async function main() {
  if (!fs.existsSync(HARNESS)) {
    throw new Error(`Swift-Harness fehlt: ${HARNESS}. Zuerst scripts/build-sync-harness.sh ausführen.`)
  }

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-interop-'))
  const homeMac = path.join(temp, 'home-mac')
  const homeIPhone = path.join(temp, 'home-iphone')
  fs.mkdirSync(homeMac, { recursive: true })
  fs.mkdirSync(homeIPhone, { recursive: true })

  const nonce = `${process.pid}-${Date.now()}`
  const mac = createSwiftClient('Mac', `toolbox-interop-mac-${nonce}`, homeMac)
  const iphone = createSwiftClient('iPhone', `toolbox-interop-iphone-${nonce}`, homeIPhone)
  const clients = [mac, iphone]

  const windows = new ToolboxStore({ filePath: path.join(temp, 'windows.json') })
  const sync = new SyncService({
    store: windows,
    deviceName: 'Windows-PC',
    discovery: false,
    logger: silentLogger,
  })
  let proxy = null

  const cleanup = async () => {
    sync.stop()
    windows.dispose()
    if (proxy) await proxy.close()
    for (const client of clients) {
      if (client.child.exitCode === null) {
        client.child.stdin.end()
        client.child.kill()
        await new Promise(resolve => client.child.once('exit', resolve))
      }
    }
    fs.rmSync(temp, { recursive: true, force: true })
  }

  try {
    const [macPort, iphonePort] = await Promise.all([mac.harness.ready, iphone.harness.ready])
    proxy = await createCaptureProxy(macPort)

    sync.start()
    await waitFor(() => sync.listening, 'Windows-Sync-Server startet')
    sync.connectTo('127.0.0.1', proxy.port)
    sync.connectTo('127.0.0.1', iphonePort)

    await waitFor(() => sync.peerCount === 2, 'Windows hat beide Swift-Clients als Peers')
    await waitForStatus(mac.harness, status => status.peers === 1, 'Mac erkennt Windows')
    await waitForStatus(iphone.harness, status => status.peers === 1, 'iPhone erkennt Windows')

    // A (Mac) legt v1 an. B (iPhone) schreibt nichts und muss den Stand über Windows erhalten.
    mac.child.stdin.write('setsizes 250 600 2400\n')
    mac.child.stdin.write('addwater 400\n')
    mac.child.stdin.write('increment\n')

    const macV1 = await waitForStatus(
      mac.harness,
      status => status.water === 400 && status.counter === 1,
      'Mac hat v1 lokal'
    )
    await waitFor(
      () => windows.todayML() === 400 && windows.count === 1,
      'Windows erhält v1 vom Mac'
    )
    const iphoneV1 = await waitForStatus(
      iphone.harness,
      status => status.water === 400 && status.counter === 1,
      'iPhone erhält v1 über Windows'
    )
    assert.ok(Math.abs(windows.waterUpdatedAt() - macV1.waterUpdatedAt) < 0.001)
    assert.ok(Math.abs(iphoneV1.waterUpdatedAt - macV1.waterUpdatedAt) < 0.001)

    // A ändert auf v2. Windows und B müssen den neueren Stand erhalten.
    await delay(200)
    mac.child.stdin.write('addwater 200\n')

    const macV2 = await waitForStatus(
      mac.harness,
      status => status.water === 600,
      'Mac hat v2 lokal'
    )
    await waitFor(
      () => windows.todayML() === 600 && windows.waterUpdatedAt() > macV1.waterUpdatedAt,
      'Windows erhält v2 vom Mac'
    )
    await waitForStatus(
      iphone.harness,
      status => status.water === 600
        && Math.abs(status.waterUpdatedAt - macV2.waterUpdatedAt) < 0.001,
      'iPhone erhält v2 über Windows'
    )

    // Die echte Wire-Zeile von A-v2 für den späteren verspäteten Replay aufzeichnen.
    const oldV2Line = findOldWaterLine(proxy.captured, 600)
    assert.ok(oldV2Line, 'Die echte A-v2-Wire-Zeile muss aufgezeichnet sein')

    // A speichert einen Zählerstand; Windows und B müssen das Feld übernehmen.
    mac.child.stdin.write('savecounter Interop-Stand\n')
    await waitFor(
      () => windows.savedCounters.length === 1
        && windows.savedCounters[0].name === 'Interop-Stand',
      'Windows erhält den gespeicherten Zählerstand'
    )
    const iphoneSaved = await waitForStatus(
      iphone.harness,
      status => status.counter === 1,
      'iPhone bleibt beim Zählerstand 1'
    )
    assert.equal(iphoneSaved.water, 600)

    // Windows erzeugt den neueren Stand; beide Swift-Clients müssen ihn erhalten.
    await delay(200)
    windows.addWater(250)
    windows.increment()
    await waitFor(() => windows.todayML() === 850 && windows.count === 2, 'Windows-Änderung lokal')

    const macAfterWindows = await waitForStatus(
      mac.harness,
      status => status.water === 850 && status.counter === 2,
      'Mac erhält Windows-Änderung'
    )
    const iphoneAfterWindows = await waitForStatus(
      iphone.harness,
      status => status.water === 850 && status.counter === 2,
      'iPhone erhält Windows-Änderung'
    )
    assert.ok(Math.abs(macAfterWindows.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)
    assert.ok(Math.abs(iphoneAfterWindows.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)

    // Die alte, echte A-v2-Zeile verspätet an Windows und B schicken.
    // Beide müssen sie wegen des neueren Wasser- und Zähler-Zeitstempels verwerfen.
    await replayWireLine(sync.port, oldV2Line)
    await replayWireLine(iphonePort, oldV2Line)
    await delay(800)

    assert.equal(windows.todayML(), 850, 'Alter A-v2-Stand darf Windows nicht überschreiben')
    assert.equal(windows.count, 2, 'Alter A-v2-Stand darf den Windows-Zähler nicht überschreiben')
    assert.equal(windows.savedCounters.length, 1, 'Gespeicherter Zählerstand darf nicht verloren gehen')

    const macAfterReplay = await waitForStatus(
      mac.harness,
      status => status.water === 850 && status.counter === 2,
      'Mac bleibt nach dem alten Replay bei 850'
    )
    const iphoneAfterReplay = await waitForStatus(
      iphone.harness,
      status => status.water === 850 && status.counter === 2,
      'iPhone bleibt nach dem alten Replay bei 850'
    )
    assert.ok(Math.abs(macAfterReplay.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)
    assert.ok(Math.abs(iphoneAfterReplay.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)

    // Alle drei Clients müssen denselben vollständigen Snapshot haben.
    const macSnapshot = await mac.harness.snapshot()
    const iphoneSnapshot = await iphone.harness.snapshot()
    const winWaterSnapshot = windows.waterSnapshot()
    const winCounterSnapshot = windows.counterSnapshot()

    // Explizite Sollwerte: Die Gleichheit allein würde ein gemeinsames
    // Weglassen eines Feldes nicht erkennen.
    assert.equal(winWaterSnapshot.total, 850, 'Gesamtmenge')
    assert.deepEqual(
      winWaterSnapshot.history,
      { [winWaterSnapshot.day]: 850 },
      'Verlauf'
    )
    assert.deepEqual(winWaterSnapshot.recentAdds, [400, 200, 250], 'recentAdds')
    assert.equal(winWaterSnapshot.glass, 250, 'Glasgröße')
    assert.equal(winWaterSnapshot.bottle, 600, 'Flaschengröße')
    assert.equal(winWaterSnapshot.goal, 2400, 'Tagesziel')
    assert.equal(winCounterSnapshot.count, 2, 'Zählerstand')
    assert.equal(winCounterSnapshot.rate, 5, 'Zählerrate')
    assert.equal(winCounterSnapshot.savedCounters.length, 1, 'Gespeicherter Zählerstand fehlt')
    assert.equal(winCounterSnapshot.savedCounters[0].name, 'Interop-Stand')
    assert.equal(winCounterSnapshot.savedCounters[0].value, 1)

    assertSnapshot('Mac', macSnapshot, winWaterSnapshot, winCounterSnapshot)
    assertSnapshot('iPhone', iphoneSnapshot, winWaterSnapshot, winCounterSnapshot)

    console.log(
      'Drei echte Peers erfolgreich: A=Mac, B=iPhone, Windows; '
      + 'v1 400 -> Windows/B; v2 600 -> Windows/B; '
      + 'Windows 850/Zähler 2 -> A/B; verspätetes A-v2 600 verworfen; Snapshots identisch.'
    )
  } catch (error) {
    const details = clients
      .map(client => `${client.name}-stdout:\n${client.harness.lines.join('\n')}\n`
        + `${client.name}-stderr:\n${client.stderr}`)
      .join('\n')
    error.message += `\n${details}`
    throw error
  } finally {
    await cleanup()
  }
}

main().catch(error => {
  console.error('Swift↔Windows-Interop fehlgeschlagen:', error)
  process.exitCode = 1
})
