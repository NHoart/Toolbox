'use strict'

// Wire-Format des Toolbox-Abgleichs.
//
// Die Apple-App (macOS/iOS) verschickt pro Zeile ein JSON-Objekt:
//   { "deviceID": "...", "deviceName": "...", "water": {...}, "counter": {...} }
//
// Swift kodiert `Date` als Double in Sekunden seit dem 01.01.2001
// (timeIntervalSinceReferenceDate). Die Windows-App muss exakt dasselbe
// Format sprechen, sonst können Mac/iPhone und Windows nicht zusammenarbeiten.

const APPLE_EPOCH_OFFSET_SECONDS = 978_307_200 // 1970-01-01 -> 2001-01-01
const MAX_HISTORY_DAYS = 400
const MAX_RECENT_ADDS = 50
const MAX_SAVED_COUNTERS = 500
const DEFAULT_GLASS = 200
const DEFAULT_BOTTLE = 500
const DEFAULT_GOAL = 2000
const DEFAULT_RATE = 5
const MIN_RATE = 1
const MAX_RATE = 100

// Date.distantPast der Apple-Clients, als Referenzsekunden.
const APPLE_DISTANT_PAST = -63_113_904_000

function toAppleTime(ms = Date.now()) {
  return ms / 1000 - APPLE_EPOCH_OFFSET_SECONDS
}

function fromAppleTime(seconds) {
  return (seconds + APPLE_EPOCH_OFFSET_SECONDS) * 1000
}

/**
 * Liest einen Zeitstempel der Apple-Clients. Erlaubt zusätzlich ISO-Strings,
 * damit ein künftiger Client das Feld nicht zwingend numerisch schicken muss.
 * Rückgabe: Referenzsekunden oder `fallback`.
 */
function parseAppleTime(value, fallback = APPLE_DISTANT_PAST) {
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (typeof value === 'string' && value.length > 0) {
    const parsed = Date.parse(value)
    if (Number.isFinite(parsed)) return toAppleTime(parsed)
  }
  return fallback
}

function localDayString(date = new Date()) {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

function isDayString(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
}

function toInteger(value, fallback = 0) {
  const number = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(number)) return fallback
  return Math.trunc(number)
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

/** Entfernt Einträge, die älter als 400 Tage sind – wie WaterStore.setToday. */
function pruneHistory(history, now = new Date()) {
  if (!history || typeof history !== 'object') return {}
  const cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate() - MAX_HISTORY_DAYS)
  const cutoffKey = localDayString(cutoff)
  const result = {}
  for (const [key, value] of Object.entries(history)) {
    if (!isDayString(key) || key < cutoffKey) continue
    result[key] = Math.max(0, toInteger(value, 0))
  }
  return result
}

function normalizeSavedCounters(raw) {
  if (!Array.isArray(raw)) return []
  const counters = []
  for (const item of raw.slice(0, MAX_SAVED_COUNTERS)) {
    if (!item || typeof item !== 'object') continue
    const name = typeof item.name === 'string' ? item.name.slice(0, 200) : 'Stand'
    counters.push({
      id: typeof item.id === 'string' && item.id.length > 0 ? item.id : randomId(),
      name,
      value: Math.max(0, toInteger(item.value, 0)),
      date: parseAppleTime(item.date, toAppleTime()),
    })
  }
  return counters
}

function normalizeWaterSnapshot(raw) {
  if (!raw || typeof raw !== 'object') return null
  const glass = toInteger(raw.glass, DEFAULT_GLASS)
  const bottle = toInteger(raw.bottle, DEFAULT_BOTTLE)
  const goal = toInteger(raw.goal, DEFAULT_GOAL)
  const recentAdds = Array.isArray(raw.recentAdds)
    ? raw.recentAdds
        .map(value => Math.max(0, toInteger(value, 0)))
        .filter(value => value > 0)
        .slice(-MAX_RECENT_ADDS)
    : []

  return {
    history: pruneHistory(raw.history),
    recentAdds,
    day: isDayString(raw.day) ? raw.day : null,
    total: Math.max(0, toInteger(raw.total, 0)),
    // Wie die Apple-Getter: 0 bedeutet „Standardwert".
    glass: glass > 0 ? glass : DEFAULT_GLASS,
    bottle: bottle > 0 ? bottle : DEFAULT_BOTTLE,
    goal: goal > 0 ? goal : DEFAULT_GOAL,
    updatedAt: parseAppleTime(raw.updatedAt),
  }
}

function normalizeCounterSnapshot(raw) {
  if (!raw || typeof raw !== 'object') return null
  const rate = toInteger(raw.rate, DEFAULT_RATE)
  return {
    count: Math.max(0, toInteger(raw.count, 0)),
    savedCounters: normalizeSavedCounters(raw.savedCounters),
    rate: clamp(rate > 0 ? rate : DEFAULT_RATE, MIN_RATE, MAX_RATE),
    updatedAt: parseAppleTime(raw.updatedAt),
  }
}

/** Baut die Nachricht, die über TCP geht (eine Zeile, wie bei den Apple-Clients). */
function encodeMessage({ deviceID, deviceName, water, counter }) {
  const message = { deviceID, deviceName }
  // Swift lässt `nil`-Felder beim Kodieren weg.
  if (water) message.water = water
  if (counter) message.counter = counter
  return `${JSON.stringify(message)}\n`
}

function decodeMessageLine(line) {
  const trimmed = String(line).trim()
  if (trimmed.length === 0) return null
  let message
  try {
    message = JSON.parse(trimmed)
  } catch {
    return null
  }
  if (!message || typeof message !== 'object') return null
  if (typeof message.deviceID !== 'string' || message.deviceID.length === 0) return null
  return {
    deviceID: message.deviceID,
    deviceName: typeof message.deviceName === 'string' ? message.deviceName : 'Gerät',
    water: normalizeWaterSnapshot(message.water),
    counter: normalizeCounterSnapshot(message.counter),
  }
}

/** Pro Bereich gewinnt der zuletzt geänderte Stand – ohne eigenen Stand immer. */
function shouldApply(localUpdatedAt, remoteUpdatedAt) {
  if (localUpdatedAt === null || localUpdatedAt === undefined) return true
  return remoteUpdatedAt > localUpdatedAt
}

function isPeerBehind(localUpdatedAt, remoteUpdatedAt) {
  if (localUpdatedAt === null || localUpdatedAt === undefined) return false
  return remoteUpdatedAt < localUpdatedAt
}

function randomId() {
  return require('node:crypto').randomUUID()
}

module.exports = {
  APPLE_EPOCH_OFFSET_SECONDS,
  APPLE_DISTANT_PAST,
  MAX_HISTORY_DAYS,
  DEFAULT_GLASS,
  DEFAULT_BOTTLE,
  DEFAULT_GOAL,
  DEFAULT_RATE,
  MIN_RATE,
  MAX_RATE,
  toAppleTime,
  fromAppleTime,
  parseAppleTime,
  localDayString,
  isDayString,
  pruneHistory,
  normalizeWaterSnapshot,
  normalizeCounterSnapshot,
  normalizeSavedCounters,
  encodeMessage,
  decodeMessageLine,
  shouldApply,
  isPeerBehind,
  randomId,
}
