'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { SyncService } = require('../src/sync')

const silentLogger = { log() {}, warn() {}, error() {} }

function createNode(t, name, clock) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-sync-'))
  const store = new ToolboxStore({
    filePath: path.join(directory, 'data.json'),
    now: () => clock.value,
  })
  const sync = new SyncService({
    store,
    deviceName: name,
    discovery: false,
    logger: silentLogger,
    now: () => clock.value,
  })

  t.after(() => {
    sync.stop()
    store.dispose()
    fs.rmSync(directory, { recursive: true, force: true })
  })

  return { store, sync }
}

async function startNode(node) {
  node.sync.start()
  await waitFor(() => node.sync.listening, 'TCP-Server sollte lauschen')
}

async function waitFor(predicate, message, timeout = 6000) {
  const started = Date.now()
  while (Date.now() - started < timeout) {
    if (predicate()) return
    await new Promise(resolve => setTimeout(resolve, 20))
  }
  throw new Error(`Zeitüberschreitung: ${message}`)
}

test('Mac und Windows gleichen Wasser und Zähler in beide Richtungen ab', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockA = { value: base }
  const clockB = { value: base + 60_000 }

  const mac = createNode(t, 'Noahs-MacBook-Air', clockA)
  const windows = createNode(t, 'Noahs-PC', clockB)

  mac.store.addWater(750)
  clockA.value += 1000
  mac.store.setSizes({ goal: 2500 })
  mac.store.increment()
  mac.store.increment()
  mac.store.saveCounter('Runde 1')

  await startNode(mac)
  await startNode(windows)
  windows.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(
    () => windows.store.todayML() === 750
      && windows.store.sizes.goal === 2500
      && windows.store.count === 2
      && windows.store.savedCounters.length === 1,
    'Windows sollte den Mac-Stand übernehmen'
  )

  assert.equal(mac.store.todayML(), 750)
  assert.equal(windows.store.waterUpdatedAt(), mac.store.waterUpdatedAt())
  assert.equal(windows.store.counterUpdatedAt(), mac.store.counterUpdatedAt())

  await waitFor(
    () => mac.sync.peerCount === 1 && windows.sync.peerCount === 1,
    'beide Geräte sollten sich als verbunden zählen'
  )
})

test('Mac -> iPhone -> Windows: der Windows-PC bekommt den aktuellen Stand', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockMac = { value: base }
  const clockPhone = { value: base + 60_000 }
  const clockWindows = { value: base + 120_000 }

  const mac = createNode(t, 'Noahs-MacBook-Air', clockMac)
  const phone = createNode(t, 'iPhone von Noah', clockPhone)
  const windows = createNode(t, 'Noahs-PC', clockWindows)

  mac.store.addWater(900)
  mac.store.setSizes({ goal: 2200, glass: 250 })
  mac.store.increment()
  mac.store.saveCounter('Mac-Stand')

  await startNode(mac)
  await startNode(phone)
  phone.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(
    () => phone.store.todayML() === 900
      && phone.store.sizes.goal === 2200
      && phone.store.count === 1
      && phone.store.savedCounters.length === 1,
    'iPhone sollte den Mac-Stand übernehmen'
  )

  const syncedTimestamp = phone.store.waterUpdatedAt()
  assert.equal(syncedTimestamp, mac.store.waterUpdatedAt())

  // Der Mac ist danach nicht mehr im Netz – nur das iPhone bleibt.
  mac.sync.stop()
  await waitFor(() => phone.sync.peerCount === 0, 'iPhone sollte den Mac verlieren')

  // Später verbindet sich der Windows-PC mit dem iPhone.
  await startNode(windows)
  windows.sync.connectTo('127.0.0.1', phone.sync.port)

  await waitFor(
    () => windows.store.todayML() === 900
      && windows.store.sizes.goal === 2200
      && windows.store.sizes.glass === 250
      && windows.store.count === 1
      && windows.store.savedCounters.length === 1,
    'Windows sollte den über das iPhone weitergereichten Mac-Stand bekommen'
  )

  // Der Zeitstempel bleibt erhalten, damit weitere Geräte den Stand richtig einordnen.
  assert.equal(windows.store.waterUpdatedAt(), syncedTimestamp)
  assert.equal(windows.store.counterUpdatedAt(), phone.store.counterUpdatedAt())
})

test('Drei Geräte gleichzeitig: Änderungen laufen über die Kette weiter', async t => {
  const base = Date.now()
  const clockA = { value: base }
  const clockB = { value: base + 1_000 }
  const clockC = { value: base + 2_000 }

  const a = createNode(t, 'Mac', clockA)
  const b = createNode(t, 'iPhone', clockB)
  const c = createNode(t, 'Windows-PC', clockC)

  await startNode(a)
  await startNode(b)
  await startNode(c)

  // Kette Mac <-> iPhone <-> Windows (Mac und Windows sind nicht direkt verbunden).
  b.sync.connectTo('127.0.0.1', a.sync.port)
  c.sync.connectTo('127.0.0.1', b.sync.port)

  await waitFor(
    () => a.sync.peerCount === 1 && b.sync.peerCount === 2 && c.sync.peerCount === 1,
    'drei Geräte sollten gleichzeitig verbunden sein'
  )

  clockA.value = base + 5_000
  a.store.addWater(300)
  a.store.increment()

  await waitFor(
    () => c.store.todayML() === 300 && c.store.count === 1,
    'Windows sollte die Änderung über das iPhone erreichen'
  )
  assert.equal(b.store.todayML(), 300)
  assert.equal(b.store.count, 1)

  clockC.value = base + 10_000
  c.store.addWater(600)
  c.store.increment()

  await waitFor(
    () => a.store.todayML() === 900 && a.store.count === 2,
    'der Mac sollte die Windows-Änderung über das iPhone erreichen'
  )
  assert.equal(b.store.todayML(), 900)
  assert.equal(b.store.count, 2)
  assert.equal(a.store.waterUpdatedAt(), c.store.waterUpdatedAt())
})

test('Ein frisches Gerät überschreibt keinen neueren Stand', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockOld = { value: base }
  const clockNew = { value: base + 90_000 }

  const old = createNode(t, 'Mac', clockOld)
  const fresh = createNode(t, 'Windows-PC', clockNew)

  old.store.addWater(650)
  old.store.setSizes({ goal: 2400 })
  old.store.increment()

  await startNode(old)
  await startNode(fresh)
  fresh.sync.connectTo('127.0.0.1', old.sync.port)

  await waitFor(
    () => fresh.store.todayML() === 650 && fresh.store.count === 1,
    'das frische Gerät sollte den Stand übernehmen'
  )

  // Das frische Gerät hat keine eigenen Daten und darf den Mac nicht zurücksetzen.
  assert.equal(old.store.todayML(), 650)
  assert.equal(old.store.sizes.goal, 2400)
  assert.equal(old.store.count, 1)
})
