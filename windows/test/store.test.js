'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { localDayString, toAppleTime } = require('../src/protocol')

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

test('Frischer Stand hat Standardwerte und nichts zu synchronisieren', t => {
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
  assert.equal(state.water.days.length, 30)
  assert.equal(store.waterSnapshot(), null)
  assert.equal(store.counterSnapshot(), null)
  assert.ok(store.deviceId.length > 0)
})

test('Wasser eintragen, rückgängig machen und zurücksetzen', t => {
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

test('Mengen werden wie in den Einstellungen der Mac-App begrenzt', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store } = createStore(t, clock)

  store.setSizes({ glass: 10, bottle: 5000, goal: 100 })
  assert.deepEqual(store.sizes, { glass: 50, bottle: 3000, goal: 500 })

  clock.value += 5000
  store.setSizes({ glass: 300, bottle: 750, goal: 2500 })
  assert.deepEqual(store.sizes, { glass: 300, bottle: 750, goal: 2500 })
  assert.equal(store.waterUpdatedAt(), toAppleTime(clock.value))
})

test('Neuer Tag beginnt bei 0 ml und ohne alten Undo-Stapel', t => {
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

test('Zähler: Plus, Minus, Undo, Reset und Rate', t => {
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

test('Gespeicherte Zählerstände speichern, laden und löschen', t => {
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

test('Fremder Stand wird ohne lokale Änderungszeit übernommen', t => {
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
})

test('Stand überlebt einen Neustart der App', t => {
  const clock = { value: Date.UTC(2026, 10, 13, 9, 0, 0) }
  const { store, filePath } = createStore(t, clock)

  store.addWater(650)
  store.setSizes({ glass: 300, bottle: 800, goal: 2600 })
  store.increment()
  store.saveCounter('Test')
  store.flush()

  const reloaded = new ToolboxStore({ filePath, now: () => clock.value })
  t.after(() => reloaded.dispose())

  assert.equal(reloaded.deviceId, store.deviceId)
  assert.equal(reloaded.todayML(), 650)
  assert.deepEqual(reloaded.sizes, { glass: 300, bottle: 800, goal: 2600 })
  assert.equal(reloaded.count, 1)
  assert.equal(reloaded.savedCounters.length, 1)
  assert.equal(reloaded.savedCounters[0].name, 'Test')
})

test('Defekte Datendatei wird zur Seite gelegt statt zu crashen', t => {
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
