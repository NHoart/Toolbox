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
  throw new Error(`Timeout: ${message}`)
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

function createSwiftClient(name, suite, home, syncName = 'Interop') {
  let stderr = ''
  const child = spawn(HARNESS, [], {
    cwd: ROOT,
    env: {
      ...process.env,
      TOOLBOX_DEFAULTS_SUITE: suite,
      TOOLBOX_SYNC_NAME: syncName,
      HOME: home,
    },
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
      // Not a valid line; keep looking.
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
  assert.ok(
    Math.abs(swift.water.sizesUpdatedAt - winWater.sizesUpdatedAt) < 0.001,
    `${label}: Größen-Zeitstempel`
  )

  assert.equal(swift.counter.count, winCounter.count, `${label}: count`)
  assert.equal(swift.counter.rate, winCounter.rate, `${label}: rate`)
  assert.equal(
    swift.counter.savedCounters.length,
    winCounter.savedCounters.length,
    `${label}: savedCounters length`
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
    `${label}: counter timestamp`
  )
  assert.ok(
    Math.abs(swift.counter.rateUpdatedAt - winCounter.rateUpdatedAt) < 0.001,
    `${label}: speed timestamp`
  )
}

async function main() {
  if (!fs.existsSync(HARNESS)) {
    throw new Error(`Swift harness missing: ${HARNESS}. Run scripts/build-sync-harness.sh first.`)
  }

  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-interop-'))
  const homeMac = path.join(temp, 'home-mac')
  const homeIPhone = path.join(temp, 'home-iphone')
  const homeOther = path.join(temp, 'home-other')
  fs.mkdirSync(homeMac, { recursive: true })
  fs.mkdirSync(homeIPhone, { recursive: true })
  fs.mkdirSync(homeOther, { recursive: true })

  const nonce = `${process.pid}-${Date.now()}`
  const mac = createSwiftClient('Mac', `toolbox-interop-mac-${nonce}`, homeMac)
  const iphone = createSwiftClient('iPhone', `toolbox-interop-iphone-${nonce}`, homeIPhone)
  const outsider = createSwiftClient(
    'Andere Gruppe',
    `toolbox-interop-other-${nonce}`,
    homeOther,
    'Andere Gruppe'
  )
  const clients = [mac, iphone, outsider]

  const windows = new ToolboxStore({ filePath: path.join(temp, 'windows.json') })
  windows.setSyncName('Interop')
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
    const [macPort, iphonePort, outsiderPort] = await Promise.all([
      mac.harness.ready,
      iphone.harness.ready,
      outsider.harness.ready,
    ])
    proxy = await createCaptureProxy(macPort)

    sync.start()
    await waitFor(() => sync.listening, 'Windows-Sync-Server startet')
    sync.connectTo('127.0.0.1', proxy.port)
    sync.connectTo('127.0.0.1', iphonePort)

    await waitFor(() => sync.peerCount === 2, 'Windows hat beide Swift-Clients als Peers')
    await waitForStatus(mac.harness, status => status.peers === 1, 'Mac erkennt Windows')
    await waitForStatus(iphone.harness, status => status.peers === 1, 'iPhone erkennt Windows')

    // A (Mac) creates v1. B (iPhone) writes nothing and must receive the state through Windows.
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
      'Windows receives v1 from the Mac'
    )
    const iphoneV1 = await waitForStatus(
      iphone.harness,
      status => status.water === 400 && status.counter === 1,
      'iPhone receives v1 through Windows'
    )
    assert.ok(Math.abs(windows.waterUpdatedAt() - macV1.waterUpdatedAt) < 0.001)
    assert.ok(Math.abs(iphoneV1.waterUpdatedAt - macV1.waterUpdatedAt) < 0.001)

    // A changes to v2. Windows and B must receive the newer state.
    await delay(200)
    mac.child.stdin.write('addwater 200\n')

    const macV2 = await waitForStatus(
      mac.harness,
      status => status.water === 600,
      'Mac hat v2 lokal'
    )
    await waitFor(
      () => windows.todayML() === 600 && windows.waterUpdatedAt() > macV1.waterUpdatedAt,
      'Windows receives v2 from the Mac'
    )
    await waitForStatus(
      iphone.harness,
      status => status.water === 600
        && Math.abs(status.waterUpdatedAt - macV2.waterUpdatedAt) < 0.001,
      'iPhone receives v2 through Windows'
    )

    // Record the real wire line of A-v2 for the late replay later.
    const oldV2Line = findOldWaterLine(proxy.captured, 600)
    assert.ok(oldV2Line, 'Die echte A-v2-Wire-Zeile muss aufgezeichnet sein')

    // A saves a counter value; Windows and B must adopt the field.
    mac.child.stdin.write('savecounter Interop-Stand\n')
    await waitFor(
      () => windows.savedCounters.length === 1
        && windows.savedCounters[0].name === 'Interop-Stand',
      'Windows receives the saved counter value'
    )
    const iphoneSaved = await waitForStatus(
      iphone.harness,
      status => status.counter === 1,
      'iPhone stays at counter value 1'
    )
    assert.equal(iphoneSaved.water, 600)

    // Windows produces the newer state; both Swift clients must receive it.
    await delay(200)
    windows.addWater(250)
    windows.increment()
    await waitFor(() => windows.todayML() === 850 && windows.count === 2, 'Windows change locally')

    const macAfterWindows = await waitForStatus(
      mac.harness,
      status => status.water === 850 && status.counter === 2,
      'Mac receives the Windows change'
    )
    const iphoneAfterWindows = await waitForStatus(
      iphone.harness,
      status => status.water === 850 && status.counter === 2,
      'iPhone receives the Windows change'
    )
    assert.ok(Math.abs(macAfterWindows.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)
    assert.ok(Math.abs(iphoneAfterWindows.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)

    // Send the old real A-v2 line to Windows and B with a delay.
    // Both must discard it because of the newer water and counter timestamps.
    await replayWireLine(sync.port, oldV2Line)
    await replayWireLine(iphonePort, oldV2Line)
    await delay(800)

    assert.equal(windows.todayML(), 850, 'The old A-v2 state must not overwrite Windows')
    assert.equal(windows.count, 2, 'The old A-v2 state must not overwrite the Windows counter')
    assert.equal(windows.savedCounters.length, 1, 'The saved counter value must not be lost')

    const macAfterReplay = await waitForStatus(
      mac.harness,
      status => status.water === 850 && status.counter === 2,
      'The Mac stays at 850 after the old replay'
    )
    const iphoneAfterReplay = await waitForStatus(
      iphone.harness,
      status => status.water === 850 && status.counter === 2,
      'The iPhone stays at 850 after the old replay'
    )
    assert.ok(Math.abs(macAfterReplay.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)
    assert.ok(Math.abs(iphoneAfterReplay.waterUpdatedAt - windows.waterUpdatedAt()) < 0.001)

    // All three clients must have the same complete snapshot.
    const macSnapshot = await mac.harness.snapshot()
    const iphoneSnapshot = await iphone.harness.snapshot()
    const winWaterSnapshot = windows.waterSnapshot()
    const winCounterSnapshot = windows.counterSnapshot()

    // Explicit expected values: equality alone would not catch a field
    // that all of them omit.
    assert.equal(winWaterSnapshot.total, 850, 'Gesamtmenge')
    assert.deepEqual(
      winWaterSnapshot.history,
      { [winWaterSnapshot.day]: 850 },
      'Verlauf'
    )
    assert.deepEqual(winWaterSnapshot.recentAdds, [400, 200, 250], 'recentAdds')
    assert.equal(winWaterSnapshot.glass, 250, 'Glass size')
    assert.equal(winWaterSnapshot.bottle, 600, 'Bottle size')
    assert.equal(winWaterSnapshot.goal, 2400, 'Tagesziel')
    assert.equal(winCounterSnapshot.count, 2, 'Counter value')
    assert.equal(winCounterSnapshot.rate, 5, 'Counter rate')
    assert.equal(winCounterSnapshot.savedCounters.length, 1, 'Saved counter value missing')
    assert.equal(winCounterSnapshot.savedCounters[0].name, 'Interop-Stand')
    assert.equal(winCounterSnapshot.savedCounters[0].value, 1)

    assertSnapshot('Mac', macSnapshot, winWaterSnapshot, winCounterSnapshot)
    assertSnapshot('iPhone', iphoneSnapshot, winWaterSnapshot, winCounterSnapshot)

    // Regression for the "ghost water" bug: a device that only changes its
    // sizes must not push its older water level over a newer one.
    iphone.child.stdin.write('stopsync\n')
    await waitForStatus(iphone.harness, status => status.port === 0, 'the iPhone goes offline')
    await waitFor(() => sync.peerCount === 1, 'Windows only sees the Mac while the iPhone is offline')

    await delay(300)
    mac.child.stdin.write('addwater 100\n')
    const mac950 = await waitForStatus(
      mac.harness,
      status => status.water === 950,
      'the Mac logs 100 ml while the iPhone is offline'
    )
    await waitFor(() => windows.todayML() === 950, 'Windows receives the newer amount')

    const iphoneBefore = await iphone.harness.status()
    assert.equal(iphoneBefore.water, 850, 'the offline iPhone keeps its older amount')

    await delay(300)
    iphone.child.stdin.write('setsizes 300 700 2700\n')
    const iphoneSizes = await waitForStatus(
      iphone.harness,
      status => status.waterSizesUpdatedAt > iphoneBefore.waterSizesUpdatedAt,
      'the iPhone changes only its sizes'
    )
    assert.equal(iphoneSizes.water, 850, 'a size change does not touch the amount')
    assert.equal(
      iphoneSizes.waterUpdatedAt,
      iphoneBefore.waterUpdatedAt,
      'a size change keeps the amount timestamp'
    )

    iphone.child.stdin.write('startsync\n')
    const iphoneSyncPort = (await waitForStatus(
      iphone.harness,
      status => status.port > 0,
      'the iPhone is back online'
    )).port
    sync.connectTo('127.0.0.1', iphoneSyncPort)

    const iphoneAfter = await waitForStatus(
      iphone.harness,
      status => status.water === 950,
      'the iPhone adopts the newer amount'
    )
    assert.ok(Math.abs(iphoneAfter.waterUpdatedAt - mac950.waterUpdatedAt) < 0.001)

    await waitFor(
      () => windows.sizes.glass === 300
        && windows.sizes.bottle === 700
        && windows.sizes.goal === 2700,
      'Windows adopts the newer sizes'
    )
    await waitForStatus(
      mac.harness,
      status => status.water === 950,
      'the Mac keeps its newer amount'
    )

    assert.equal(windows.todayML(), 950, 'a size-only change must not reset the amount')
    assert.equal(windows.waterUpdatedAt(), mac950.waterUpdatedAt, 'the amount timestamp stays')
    assert.equal(
      windows.waterSizesUpdatedAt(),
      iphoneSizes.waterSizesUpdatedAt,
      'the sizes timestamp is adopted'
    )
    assert.deepEqual(windows.sizes, { glass: 300, bottle: 700, goal: 2700 })

    // Same regression for the counter: a speed-only change must not push an
    // older count over a newer one.
    iphone.child.stdin.write('stopsync\n')
    await waitForStatus(iphone.harness, status => status.port === 0, 'the iPhone goes offline again')
    await waitFor(() => sync.peerCount === 1, 'Windows only sees the Mac again')

    await delay(300)
    mac.child.stdin.write('increment\n')
    const macCount3 = await waitForStatus(
      mac.harness,
      status => status.counter === 3,
      'the Mac counts while the iPhone is offline'
    )
    await waitFor(() => windows.count === 3, 'Windows receives the newer count')

    const iphoneCounterBefore = await iphone.harness.status()
    assert.equal(iphoneCounterBefore.counter, 2, 'the offline iPhone keeps its older count')

    await delay(300)
    iphone.child.stdin.write('setrate 9\n')
    const iphoneRate = await waitForStatus(
      iphone.harness,
      status => status.rate === 9
        && status.counterRateUpdatedAt > iphoneCounterBefore.counterRateUpdatedAt,
      'the iPhone changes only its speed'
    )
    assert.equal(iphoneRate.counter, 2, 'a speed change does not touch the count')
    assert.equal(
      iphoneRate.counterUpdatedAt,
      iphoneCounterBefore.counterUpdatedAt,
      'a speed change keeps the count timestamp'
    )

    iphone.child.stdin.write('startsync\n')
    const iphoneCounterPort = (await waitForStatus(
      iphone.harness,
      status => status.port > 0,
      'the iPhone is back online for the counter test'
    )).port
    sync.connectTo('127.0.0.1', iphoneCounterPort)

    await waitForStatus(
      iphone.harness,
      status => status.counter === 3 && status.rate === 9,
      'the iPhone adopts the newer count and keeps its speed'
    )
    await waitFor(() => windows.rate === 9, 'Windows adopts the newer speed')
    await waitForStatus(
      mac.harness,
      status => status.counter === 3 && status.rate === 9,
      'the Mac keeps its count and adopts the speed'
    )

    assert.equal(windows.count, 3, 'a speed-only change must not reset the count')
    assert.equal(windows.counterUpdatedAt(), macCount3.counterUpdatedAt, 'the count timestamp stays')
    assert.equal(
      windows.counterRateUpdatedAt(),
      iphoneRate.counterRateUpdatedAt,
      'the speed timestamp is adopted'
    )

    // A device with a different group name stays out, even if it
    // is directly reachable and we already have data.
    sync.connectTo('127.0.0.1', outsiderPort)
    await delay(800)
    const outsiderStatus = await outsider.harness.status()
    assert.equal(outsiderStatus.peers, 0, 'fremder Name darf kein Peer werden')
    assert.equal(outsiderStatus.water, 0, 'fremder Name darf keine Daten bekommen')
    const outsiderSnapshot = await outsider.harness.snapshot()
    assert.equal(outsiderSnapshot.water.total, 0, 'fremder Name darf keinen Verlauf bekommen')
    assert.equal(windows.todayML(), 950, 'a foreign name must not change Windows')

    console.log(
      'Drei echte Peers erfolgreich: A=Mac, B=iPhone, Windows; '
      + 'v1 400 -> Windows/B; v2 600 -> Windows/B; '
      + 'Windows 850/counter 2 -> A/B; late A-v2 600 discarded; snapshots identical; '
      + 'B sizes-only 300/700/2700 kept A at 950; '
      + 'A count 3 + B speed 9 merged without a reset.'
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
