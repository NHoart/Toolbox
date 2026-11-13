'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const {
  APPLE_DISTANT_PAST,
  encodeMessage,
  decodeMessageLine,
  fromAppleTime,
  isPeerBehind,
  normalizeCounterSnapshot,
  normalizeWaterSnapshot,
  parseAppleTime,
  pruneHistory,
  shouldApply,
  toAppleTime,
} = require('../src/protocol')

test('Apple-Referenzzeit wird korrekt umgerechnet', () => {
  assert.equal(toAppleTime(978_307_200_000), 0)
  assert.equal(fromAppleTime(0), 978_307_200_000)
  assert.equal(toAppleTime(978_307_200_000 + 90_000), 90)
})

test('Zeitstempel werden als Zahl, ISO-String oder Fallback gelesen', () => {
  assert.equal(parseAppleTime(1234.5), 1234.5)
  assert.ok(Number.isFinite(parseAppleTime('2026-11-13T10:00:00Z')))
  assert.equal(parseAppleTime(undefined), APPLE_DISTANT_PAST)
  assert.equal(parseAppleTime('keine Zeit'), APPLE_DISTANT_PAST)
})

test('Verlauf wird auf 400 Tage begrenzt und bereinigt', () => {
  const now = new Date(2026, 10, 13)
  const pruned = pruneHistory({
    '2026-11-13': 1500,
    '2025-01-01': 900,
    'kein-datum': 500,
    '2026-11-12': '250',
  }, now)

  assert.deepEqual(pruned, {
    '2026-11-13': 1500,
    '2026-11-12': 250,
  })
})

test('Ein leerer Stand meldet beide Bereiche als nichts zu synchronisieren', () => {
  assert.equal(normalizeWaterSnapshot(null), null)
  assert.equal(normalizeCounterSnapshot(undefined), null)
})

test('Wasserstand wird defensiv normalisiert', () => {
  const snapshot = normalizeWaterSnapshot({
    history: { '2026-11-13': 1750 },
    recentAdds: [250, 500, 0, -10],
    day: '2026-11-13',
    total: 1750,
    glass: 0,
    bottle: 750,
    goal: 3000,
    updatedAt: 42,
  })

  assert.equal(snapshot.glass, 200)
  assert.equal(snapshot.bottle, 750)
  assert.equal(snapshot.goal, 3000)
  assert.deepEqual(snapshot.recentAdds, [250, 500])
  assert.equal(snapshot.updatedAt, 42)
})

test('Zählerstand wird begrenzt und gespeicherte Stände ergänzt', () => {
  const snapshot = normalizeCounterSnapshot({
    count: 12,
    rate: 500,
    savedCounters: [
      { name: 'Runde 1', value: 12, date: 77 },
      null,
    ],
    updatedAt: 5,
  })

  assert.equal(snapshot.rate, 100)
  assert.equal(snapshot.savedCounters.length, 1)
  assert.equal(snapshot.savedCounters[0].name, 'Runde 1')
  assert.ok(snapshot.savedCounters[0].id.length > 0)
  assert.equal(snapshot.savedCounters[0].date, 77)
})

test('Nachricht entspricht dem Swift-Format (eine Zeile, nil-Felder fehlen)', () => {
  const line = encodeMessage({
    deviceID: 'windows-1',
    deviceName: 'Noahs-PC',
    water: {
      history: { '2026-11-13': 750 },
      recentAdds: [250, 500],
      day: '2026-11-13',
      total: 750,
      glass: 200,
      bottle: 500,
      goal: 2000,
      updatedAt: 100,
    },
    counter: null,
  })

  assert.ok(line.endsWith('\n'))
  assert.equal(line.indexOf('\n'), line.length - 1)

  const parsed = JSON.parse(line)
  assert.deepEqual(Object.keys(parsed), ['deviceID', 'deviceName', 'water'])
  assert.equal(parsed.water.total, 750)
  assert.equal(parsed.water.updatedAt, 100)
})

test('Swift-Nachricht mit Zahlendaten wird dekodiert', () => {
  const line = JSON.stringify({
    deviceID: 'mac-1',
    deviceName: 'Noahs-MacBook-Air',
    water: {
      history: { '2026-11-13': 1250 },
      recentAdds: [250],
      day: '2026-11-13',
      total: 1250,
      glass: 200,
      bottle: 500,
      goal: 2000,
      updatedAt: 812_345_678.5,
    },
    counter: {
      count: 3,
      savedCounters: [],
      rate: 5,
      updatedAt: 812_345_679,
    },
  })

  const message = decodeMessageLine(line)
  assert.equal(message.deviceID, 'mac-1')
  assert.equal(message.deviceName, 'Noahs-MacBook-Air')
  assert.equal(message.water.total, 1250)
  assert.equal(message.water.updatedAt, 812_345_678.5)
  assert.equal(message.counter.count, 3)
})

test('Ungültige Zeilen werden verworfen', () => {
  assert.equal(decodeMessageLine('kein json'), null)
  assert.equal(decodeMessageLine('{}'), null)
  assert.equal(decodeMessageLine('{"deviceID":""}'), null)
  assert.equal(decodeMessageLine(''), null)
})

test('Merge-Regeln: ohne eigenen Stand immer, sonst nur der neuere', () => {
  assert.equal(shouldApply(null, 10), true)
  assert.equal(shouldApply(5, 10), true)
  assert.equal(shouldApply(10, 5), false)
  assert.equal(shouldApply(10, 10), false)

  assert.equal(isPeerBehind(10, 5), true)
  assert.equal(isPeerBehind(5, 10), false)
  assert.equal(isPeerBehind(null, 10), false)
})
