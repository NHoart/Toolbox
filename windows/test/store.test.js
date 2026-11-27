'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { APPLE_DISTANT_PAST, localDayString, toAppleTime } = require('../src/protocol')

function createStore(t, clock) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-store-'))
  const filePath = path.join(directory, 'data.json')
  const store = new ToolboxStore({ filePath, now: () => clock.value })
  t.after(() => {
    store.dispose()
    fs.rmSync(directory, { recursive: true, force: true })
  })
  return { store, filePath }
}

test('Fresh state has defaults and nothing to sync', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)
  const state = store.getState()

  assert.equal(state.water.today, 0)
  assert.equal(state.water.glass, 200)
  assert.equal(state.water.bottle, 500)
  assert.equal(state.water.goal, 2000)
  assert.equal(state.counter.count, 0)
  assert.equal(state.counter.rate, 5)
  assert.equal(state.syncEnabled, true)
  assert.equal(store.syncName, '')
  assert.equal(state.water.days.length, 30)
  assert.equal(store.waterSnapshot(), null)
  assert.equal(store.counterSnapshot(), null)
  assert.ok(store.deviceId.length > 0)
})

test('Log water, undo and reset', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  const changes = []
  store.on('changed', section => changes.push(section))

  assert.equal(store.addWater(250), true)
  clock.value += 1000
  assert.equal(store.addWater(500), true)
  assert.equal(store.todayML(), 750)
  assert.equal(store.lastAddedML(), 500)

  const snapshot = store.waterSnapshot()
  assert.equal(snapshot.total, 750)
  assert.equal(snapshot.history[localDayString(new Date(clock.value))], 750)
  assert.deepEqual(snapshot.recentAdds, [250, 500])
  assert.equal(snapshot.updatedAt, toAppleTime(clock.value))

  assert.equal(store.undoWater(), true)
  assert.equal(store.todayML(), 250)
  assert.equal(store.lastAddedML(), 250)

  store.resetToday()
  assert.equal(store.todayML(), 0)
  assert.equal(store.lastAddedML(), null)

  assert.deepEqual(changes, ['water', 'water', 'water', 'water'])
})

test('Amounts are clamped like in the Mac app settings', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.setSizes({ glass: 10, bottle: 5000, goal: 100 })
  assert.deepEqual(store.sizes, { glass: 50, bottle: 3000, goal: 500 })

  clock.value += 5000
  store.setSizes({ glass: 300, bottle: 750, goal: 2500 })
  assert.deepEqual(store.sizes, { glass: 300, bottle: 750, goal: 2500 })
  // A size change must not touch the amount timestamp.
  assert.equal(store.waterUpdatedAt(), null)
  assert.equal(store.waterSizesUpdatedAt(), toAppleTime(clock.value))
})

test('A size change keeps the amount timestamp and an older water level', t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clock = { value: base }
  const { store } = createStore(t, clock)

  store.addWater(750)
  const amountTime = store.waterUpdatedAt()

  clock.value = base + 60_000
  store.setSizes({ goal: 2500 })

  assert.equal(store.todayML(), 750)
  assert.equal(store.waterUpdatedAt(), amountTime, 'setSizes nur den Größen-Zeitstempel setzen')
  assert.equal(store.waterSizesUpdatedAt(), toAppleTime(clock.value))

  // A device with an older amount but newer sizes must not reset the level.
  const applied = store.applyRemoteWater({
    history: { '2026-11-13': 400 },
    recentAdds: [400],
    day: '2026-11-13',
    total: 400,
    glass: 200,
    bottle: 500,
    goal: 2000,
    updatedAt: amountTime - 120,
    sizesUpdatedAt: toAppleTime(clock.value) + 120,
  })

  assert.equal(applied, true)
  assert.equal(store.todayML(), 750, 'the newer amount wins')
  assert.equal(store.waterUpdatedAt(), amountTime)
  assert.deepEqual(store.sizes, { glass: 200, bottle: 500, goal: 2000 }, 'the newer sizes win')
  assert.equal(store.waterSizesUpdatedAt(), toAppleTime(clock.value) + 120)
})

test('A new day starts at 0 ml and without an old undo stack', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.addWater(500)
  const yesterday = localDayString(new Date(clock.value))
  clock.value += 24 * 60 * 60 * 1000

  assert.equal(localDayString(new Date(clock.value)) !== yesterday, true)
  assert.equal(store.todayML(), 0)
  assert.equal(store.lastAddedML(), null)

  store.addWater(200)
  assert.equal(store.todayML(), 200)
  assert.equal(store.lastAddedML(), 200)
  assert.equal(store.waterSnapshot().history[yesterday], 500)
})

test('Counter: plus, minus, undo, reset and rate', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.increment()
  store.increment()
  store.increment()
  assert.equal(store.count, 3)

  store.decrement()
  assert.equal(store.count, 2)

  store.undoCounter()
  assert.equal(store.count, 3)

  store.setRate(1000)
  assert.equal(store.rate, 100)
  store.setRate(0)
  assert.equal(store.rate, 1)

  store.resetCounter()
  assert.equal(store.count, 0)
})

test('A rate change keeps the count timestamp and an older count', t => {
  const base = Date.UTC(2026, 10, 13, 9, 0, 0)
  const clock = { value: base }
  const { store } = createStore(t, clock)

  store.increment()
  store.increment()
  const countTime = store.counterUpdatedAt()

  clock.value = base + 60_000
  store.setRate(9)

  assert.equal(store.count, 2)
  assert.equal(store.counterUpdatedAt(), countTime, 'setRate darf den Zähler-Zeitstempel nicht ändern')
  assert.equal(store.counterRateUpdatedAt(), toAppleTime(clock.value))

  // A device with an older count but newer speed must not reset the count.
  const applied = store.applyRemoteCounter({
    count: 1,
    savedCounters: [],
    rate: 12,
    updatedAt: countTime - 120,
    rateUpdatedAt: toAppleTime(clock.value) + 120,
  })

  assert.equal(applied, true)
  assert.equal(store.count, 2, 'the newer count wins')
  assert.equal(store.counterUpdatedAt(), countTime)
  assert.equal(store.rate, 12, 'the newer speed wins')
  assert.equal(store.counterRateUpdatedAt(), toAppleTime(clock.value) + 120)
})

test('A remote speed keeps a running auto count alive, a remote count stops it', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.increment()
  const amountTime = store.counterUpdatedAt()
  store.startAuto()
  assert.equal(store.isAutoRunning, true)

  // A speed-only state must not stop the local auto count.
  clock.value += 1000
  assert.equal(store.applyRemoteCounter({
    count: 1,
    savedCounters: [],
    rate: 9,
    updatedAt: amountTime - 60,
    rateUpdatedAt: toAppleTime(clock.value + 60),
  }), true)
  assert.equal(store.isAutoRunning, true, 'a speed-only state keeps auto running')
  assert.equal(store.rate, 9)
  assert.equal(store.counterUpdatedAt(), amountTime)

  // A newer count from another device still stops it.
  clock.value += 1000
  assert.equal(store.applyRemoteCounter({
    count: 50,
    savedCounters: [],
    rate: 9,
    updatedAt: toAppleTime(clock.value),
    rateUpdatedAt: toAppleTime(clock.value - 60),
  }), true)
  assert.equal(store.isAutoRunning, false, 'a foreign count stops auto counting')
  assert.equal(store.count, 50)
})

test('Save, load and delete stored counter values', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.increment()
  store.increment()
  const name = store.saveCounter('  Runde 1  ')
  assert.equal(name, 'Runde 1')
  assert.equal(store.savedCounters.length, 1)
  assert.equal(store.savedCounters[0].value, 2)

  store.resetCounter()
  assert.equal(store.count, 0)

  const saved = store.savedCounters[0]
  assert.equal(store.loadCounter(saved.id), true)
  assert.equal(store.count, 2)

  assert.equal(store.deleteCounter(saved.id), true)
  assert.equal(store.savedCounters.length, 0)
})

test('Foreign state is adopted without a local change time', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  const changes = []
  store.on('changed', section => changes.push(section))

  const applied = store.applyRemoteWater({
    history: { '2026-11-12': 900, '2026-11-13': 1400 },
    recentAdds: [400],
    day: '2026-11-13',
    total: 1400,
    glass: 250,
    bottle: 700,
    goal: 2200,
    updatedAt: 12345,
  })

  assert.equal(applied, true)
  assert.equal(store.todayML(), 1400)
  assert.deepEqual(store.sizes, { glass: 250, bottle: 700, goal: 2200 })
  assert.equal(store.waterUpdatedAt(), 12345)
  assert.deepEqual(changes, [])

  store.applyRemoteCounter({
    count: 9,
    savedCounters: [{ id: 'abc', name: 'Stand', value: 9, date: 100 }],
    rate: 12,
    updatedAt: 777,
  })
  assert.equal(store.count, 9)
  assert.equal(store.rate, 12)
  assert.equal(store.counterUpdatedAt(), 777)
  assert.deepEqual(changes, [])
  assert.equal(store.counterRateUpdatedAt(), APPLE_DISTANT_PAST)
})

test('State survives an app restart', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store, filePath } = createStore(t, clock)

  store.addWater(650)
  store.setSizes({ glass: 300, bottle: 800, goal: 2600 })
  store.increment()
  store.saveCounter('Test')
  store.setSyncName('Familie')
  store.flush()

  const reloaded = new ToolboxStore({ filePath, now: () => clock.value })
  t.after(() => reloaded.dispose())

  assert.equal(reloaded.deviceId, store.deviceId)
  assert.equal(reloaded.syncName, 'Familie')
  assert.equal(reloaded.todayML(), 650)
  assert.deepEqual(reloaded.sizes, { glass: 300, bottle: 800, goal: 2600 })
  assert.equal(reloaded.count, 1)
  assert.equal(reloaded.savedCounters.length, 1)
  assert.equal(reloaded.savedCounters[0].name, 'Test')
})

test('Broken data file is moved aside instead of crashing', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-corrupt-'))
  const filePath = path.join(directory, 'data.json')
  fs.writeFileSync(filePath, '{ kaputt', 'utf8')

  const store = new ToolboxStore({ filePath, now: () => Date.now() })
  t.after(() => {
    store.dispose()
    fs.rmSync(directory, { recursive: true, force: true })
  })

  assert.equal(store.todayML(), 0)
  const backups = fs.readdirSync(directory).filter(name => name.includes('.corrupt-'))
  assert.equal(backups.length, 1)
})
