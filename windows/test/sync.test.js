'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { SyncService } = require('../src/sync')

const silentLogger = { log() {}, warn() {}, error() {} }

function createNode(t, name, clock, syncName = 'Familie') {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-sync-'))
  const store = new ToolboxStore({
    filePath: path.join(directory, 'data.json'),
    now: () => clock.value,
  })
  store.setSyncName(syncName)
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
  throw new Error(`Timeout: ${message}`)
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

test('Mac and Windows sync water and counter in both directions', async t => {
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
    'Windows should adopt the Mac state'
  )

  assert.equal(mac.store.todayML(), 750)
  assert.equal(windows.store.waterUpdatedAt(), mac.store.waterUpdatedAt())
  assert.equal(windows.store.counterUpdatedAt(), mac.store.counterUpdatedAt())

  await waitFor(
    () => mac.sync.peerCount === 1 && windows.sync.peerCount === 1,
    'both devices should count each other as connected'
  )
})

test('Mac -> iPhone -> Windows: the Windows PC receives the current state', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockMac = { value: base }
  const clockPhone = { value: base + 60_000 }
  const clockWindows = { value: base + 120_000 }

  const mac = createNode(t, 'Noahs-MacBook-Air', clockMac)
  const phone = createNode(t, 'Noah iPhone', clockPhone)
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
    'iPhone should adopt the Mac state'
  )

  const syncedTimestamp = phone.store.waterUpdatedAt()
  assert.equal(syncedTimestamp, mac.store.waterUpdatedAt())

  // The Mac is no longer on the network – only the iPhone remains.
  mac.sync.stop()
  await waitFor(() => phone.sync.peerCount === 0, 'iPhone should lose the Mac')

  // Later the Windows PC connects to the iPhone.
  await startNode(windows)
  windows.sync.connectTo('127.0.0.1', phone.sync.port)

  await waitFor(
    () => windows.store.todayML() === 900
      && windows.store.sizes.goal === 2200
      && windows.store.sizes.glass === 250
      && windows.store.count === 1
      && windows.store.savedCounters.length === 1,
    'Windows should receive the Mac state passed on through the iPhone'
  )

  // The timestamp is preserved so other devices order the state correctly.
  assert.equal(windows.store.waterUpdatedAt(), syncedTimestamp)
  assert.equal(windows.store.counterUpdatedAt(), phone.store.counterUpdatedAt())
})

test('Three devices at once: changes travel along the chain', async t => {
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

  // Chain Mac <-> iPhone <-> Windows (Mac and Windows are not directly connected).
  b.sync.connectTo('127.0.0.1', a.sync.port)
  c.sync.connectTo('127.0.0.1', b.sync.port)

  await waitFor(
    () => a.sync.peerCount === 1 && b.sync.peerCount === 2 && c.sync.peerCount === 1,
    'three devices should be connected at the same time'
  )

  clockA.value = base + 5_000
  a.store.addWater(300)
  a.store.increment()

  await waitFor(
    () => c.store.todayML() === 300 && c.store.count === 1,
    'Windows should reach the change through the iPhone'
  )
  assert.equal(b.store.todayML(), 300)
  assert.equal(b.store.count, 1)

  clockC.value = base + 10_000
  c.store.addWater(600)
  c.store.increment()

  await waitFor(
    () => a.store.todayML() === 900 && a.store.count === 2,
    'the Mac should receive the Windows change through the iPhone'
  )
  assert.equal(b.store.todayML(), 900)
  assert.equal(b.store.count, 2)
  assert.equal(a.store.waterUpdatedAt(), c.store.waterUpdatedAt())
})

test('A fresh device does not overwrite a newer state', async t => {
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
    'the fresh device should adopt the state'
  )

  // The fresh device has no own data and must not reset the Mac.
  assert.equal(old.store.todayML(), 650)
  assert.equal(old.store.sizes.goal, 2400)
  assert.equal(old.store.count, 1)
})

test('A size change on an offline device does not reset newer amounts', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockA = { value: base }
  const clockB = { value: base + 60_000 }

  const mac = createNode(t, 'Mac', clockA)
  const phone = createNode(t, 'iPhone', clockB)

  mac.store.addWater(850)
  mac.store.setSizes({ goal: 2400 })

  await startNode(mac)
  await startNode(phone)
  phone.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(
    () => phone.store.todayML() === 850 && phone.store.sizes.goal === 2400,
    'the iPhone receives the initial state'
  )

  // The iPhone goes offline with 850 ml; the Mac logs 100 ml more meanwhile.
  phone.sync.stop()
  await delay(100)
  clockA.value = base + 30_000
  mac.store.addWater(100)
  assert.equal(mac.store.todayML(), 950)

  // Later the iPhone changes only its sizes. With the old shared timestamp
  // its stale 850 ml would look newer and reset the Mac to 850 on reconnect.
  clockB.value = base + 60_000
  phone.store.setSizes({ glass: 300, bottle: 700, goal: 2700 })
  assert.equal(phone.store.todayML(), 850)

  phone.sync.start()
  await waitFor(() => phone.sync.listening, 'the iPhone is back online')
  mac.sync.connectTo('127.0.0.1', phone.sync.port)

  await waitFor(() => phone.store.todayML() === 950, 'the iPhone adopts the newer amount')
  await waitFor(
    () => mac.store.sizes.glass === 300 && mac.store.sizes.bottle === 700
      && mac.store.sizes.goal === 2700,
    'the Mac adopts the newer sizes'
  )

  assert.equal(mac.store.todayML(), 950, 'the Mac keeps its newer amount')
  assert.equal(phone.store.todayML(), 950)
  assert.deepEqual(mac.store.sizes, { glass: 300, bottle: 700, goal: 2700 })
  assert.deepEqual(phone.store.sizes, { glass: 300, bottle: 700, goal: 2700 })
  assert.equal(mac.store.waterUpdatedAt(), phone.store.waterUpdatedAt())
  assert.equal(mac.store.waterSizesUpdatedAt(), phone.store.waterSizesUpdatedAt())
})

test('A speed change on an offline device does not reset a newer count', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockA = { value: base }
  const clockB = { value: base + 60_000 }

  const mac = createNode(t, 'Mac', clockA)
  const phone = createNode(t, 'iPhone', clockB)

  mac.store.increment()
  mac.store.increment()

  await startNode(mac)
  await startNode(phone)
  phone.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(() => phone.store.count === 2, 'the iPhone receives the count')

  // The iPhone goes offline with count 2; the Mac counts one more meanwhile.
  phone.sync.stop()
  await delay(100)
  clockA.value = base + 30_000
  mac.store.increment()
  assert.equal(mac.store.count, 3)

  // Later the iPhone changes only the auto-count speed. With the old shared
  // timestamp its stale count 2 would look newer and reset the Mac.
  clockB.value = base + 60_000
  phone.store.setRate(9)
  assert.equal(phone.store.count, 2)

  phone.sync.start()
  await waitFor(() => phone.sync.listening, 'the iPhone is back online')
  mac.sync.connectTo('127.0.0.1', phone.sync.port)

  await waitFor(() => phone.store.count === 3, 'the iPhone adopts the newer count')
  await waitFor(() => mac.store.rate === 9, 'the Mac adopts the newer speed')

  assert.equal(mac.store.count, 3, 'the Mac keeps its newer count')
  assert.equal(phone.store.count, 3)
  assert.equal(mac.store.rate, 9)
  assert.equal(phone.store.rate, 9)
  assert.equal(mac.store.counterUpdatedAt(), phone.store.counterUpdatedAt())
  assert.equal(mac.store.counterRateUpdatedAt(), phone.store.counterRateUpdatedAt())
})

test('Three separate clients: v1 -> v2 -> new Windows, and back', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockMac = { value: base }
  const clockPhone = { value: base + 60_000 }
  const clockWindows = { value: base + 120_000 }

  const mac = createNode(t, 'Mac', clockMac)
  const phone = createNode(t, 'iPhone', clockPhone)
  const windows = createNode(t, 'Windows-PC', clockWindows)

  // v1 is created on the Mac before the iPhone is connected.
  mac.store.addWater(400)
  mac.store.setSizes({ glass: 250, bottle: 600, goal: 2400 })
  mac.store.increment()
  const v1Water = mac.store.waterUpdatedAt()
  const v1Counter = mac.store.counterUpdatedAt()

  await startNode(mac)
  await startNode(phone)
  phone.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(
    () => phone.store.todayML() === 400
      && phone.store.count === 1
      && phone.store.waterUpdatedAt() === v1Water
      && phone.store.counterUpdatedAt() === v1Counter,
    'the iPhone should receive v1 from the Mac'
  )

  // v2 is created on the Mac while the iPhone is already connected.
  clockMac.value = base + 30_000
  mac.store.addWater(200)

  await waitFor(
    () => phone.store.todayML() === 600
      && phone.store.waterUpdatedAt() === mac.store.waterUpdatedAt(),
    'the iPhone should receive v2 from the Mac'
  )
  const v2Water = mac.store.waterUpdatedAt()
  const v2Counter = mac.store.counterUpdatedAt()

  // Windows connects only now – and only to the iPhone.
  await startNode(windows)
  windows.sync.connectTo('127.0.0.1', phone.sync.port)

  await waitFor(
    () => windows.store.todayML() === 600
      && windows.store.count === 1
      && windows.store.waterUpdatedAt() === v2Water
      && windows.store.counterUpdatedAt() === v2Counter,
    'the new Windows device should receive v2 through the iPhone'
  )

  // The Windows change must travel back to Mac and iPhone via the iPhone.
  clockWindows.value = base + 90_000
  windows.store.addWater(250)
  windows.store.increment()

  await waitFor(
    () => mac.store.todayML() === 850
      && phone.store.todayML() === 850
      && mac.store.count === 2
      && phone.store.count === 2
      && mac.store.waterUpdatedAt() === windows.store.waterUpdatedAt()
      && phone.store.waterUpdatedAt() === windows.store.waterUpdatedAt(),
    'the Windows change should reach Mac and iPhone'
  )

  // All three stores must have the same state including the timestamp.
  assert.deepEqual(mac.store.waterSnapshot(), phone.store.waterSnapshot())
  assert.deepEqual(phone.store.waterSnapshot(), windows.store.waterSnapshot())
  assert.deepEqual(mac.store.counterSnapshot(), phone.store.counterSnapshot())
  assert.deepEqual(phone.store.counterSnapshot(), windows.store.counterSnapshot())
  assert.equal(mac.store.todayML(), 850)
  assert.equal(mac.store.count, 2)
  assert.deepEqual(mac.store.sizes, { glass: 250, bottle: 600, goal: 2400 })
})

test('Ohne Namen startet kein Abgleich', async t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const node = createNode(t, 'Mac', clock, '')

  node.sync.start()
  await delay(200)
  assert.equal(node.sync.running, false)
  assert.equal(node.sync.listening, false)
  assert.equal(node.sync.getStatus().enabled, true)
  assert.equal(node.sync.getStatus().syncName, '')

  node.sync.setSyncName('Familie')
  await waitFor(() => node.sync.listening, 'the server should start after the name is set')
  assert.equal(node.sync.running, true)
  assert.equal(node.sync.getStatus().syncName, 'Familie')
})

test('Only devices with the same name sync with each other', async t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clockMac = { value: base + 60_000 }
  const clockWindows = { value: base }

  const mac = createNode(t, 'Mac', clockMac, 'Familie')
  const windows = createNode(t, 'Windows-PC', clockWindows, 'Office')

  mac.store.addWater(450)
  mac.store.increment()
  windows.store.addWater(250)

  await startNode(mac)
  await startNode(windows)
  windows.sync.connectTo('127.0.0.1', mac.sync.port)

  await delay(600)
  assert.equal(mac.sync.peerCount, 0, 'fremder Name darf kein Peer werden')
  assert.equal(windows.sync.peerCount, 0, 'fremder Name darf kein Peer werden')
  assert.equal(mac.store.todayML(), 450, 'the Mac keeps its own state')
  assert.equal(windows.store.todayML(), 250, 'Windows keeps its own state')

  // The sync may only run with a matching name.
  windows.sync.setSyncName(' familie ')
  await waitFor(() => windows.sync.listening, 'Windows sync server starts after a name change')
  windows.sync.connectTo('127.0.0.1', mac.sync.port)

  await waitFor(
    () => windows.store.todayML() === 450
      && windows.store.count === 1
      && windows.store.waterUpdatedAt() === mac.store.waterUpdatedAt(),
    'after the same name the Mac state should arrive'
  )
  assert.ok(mac.sync.peerCount === 1 && windows.sync.peerCount === 1)
})
