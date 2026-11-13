'use strict'

const fs = require('node:fs')
const path = require('node:path')
const crypto = require('node:crypto')
const { EventEmitter } = require('node:events')

const {
  APPLE_DISTANT_PAST,
  DEFAULT_BOTTLE,
  DEFAULT_GLASS,
  DEFAULT_GOAL,
  DEFAULT_RATE,
  MAX_RATE,
  MIN_RATE,
  localDayString,
  pruneHistory,
  normalizeSavedCounters,
  normalizeWaterSnapshot,
  normalizeCounterSnapshot,
  toAppleTime,
} = require('./protocol')

const SAVE_DELAY_MS = 200
const AUTO_PERSIST_MS = 500
const AUTO_TICK_MS = 1000 / 30
const MAX_UNDO_STEPS = 100

const DEFAULT_SIZES = {
  glass: DEFAULT_GLASS,
  bottle: DEFAULT_BOTTLE,
  goal: DEFAULT_GOAL,
}

class ToolboxStore extends EventEmitter {
  constructor({ filePath, now = () => Date.now() } = {}) {
    super()
    this.filePath = filePath
    this.now = now
    this.saveTimer = null
    this.autoTimer = null
    this.autoRemainder = 0
    this.countAtAutoStart = 0
    this.lastAutoPersist = 0
    this.undoStack = []
    this.data = this.emptyData()
    this.load()
  }

  // MARK: - Persistenz

  emptyData() {
    return {
      version: 1,
      deviceId: crypto.randomUUID(),
      syncEnabled: true,
      water: {
        history: {},
        recentAdds: [],
        day: null,
        total: 0,
        glass: DEFAULT_SIZES.glass,
        bottle: DEFAULT_SIZES.bottle,
        goal: DEFAULT_SIZES.goal,
        updatedAt: null,
      },
      counter: {
        count: 0,
        savedCounters: [],
        rate: DEFAULT_RATE,
        updatedAt: null,
      },
    }
  }

  load() {
    if (!this.filePath) return
    let raw
    try {
      raw = fs.readFileSync(this.filePath, 'utf8')
    } catch {
      return
    }

    try {
      const parsed = JSON.parse(raw)
      this.data = this.normalize(parsed)
    } catch {
      // Defekte Datei nicht stillschweigend verlieren: zur Seite legen.
      try {
        const backup = `${this.filePath}.corrupt-${Date.now()}`
        fs.renameSync(this.filePath, backup)
      } catch {
        // Wenn auch das scheitert, startet die App mit leeren Daten.
      }
      this.data = this.emptyData()
    }
  }

  normalize(raw) {
    const data = this.emptyData()
    if (!raw || typeof raw !== 'object') return data

    if (typeof raw.deviceId === 'string' && raw.deviceId.length > 0) {
      data.deviceId = raw.deviceId
    }
    data.syncEnabled = raw.syncEnabled !== false

    const water = normalizeWaterSnapshot(raw.water)
    if (water) {
      data.water = {
        ...water,
        updatedAt: raw.water.updatedAt === null || raw.water.updatedAt === undefined ? null : water.updatedAt,
      }
    }

    const counter = normalizeCounterSnapshot(raw.counter)
    if (counter) {
      data.counter = {
        ...counter,
        updatedAt: raw.counter.updatedAt === null || raw.counter.updatedAt === undefined ? null : counter.updatedAt,
      }
    }

    return data
  }

  persist() {
    if (!this.filePath) return
    this.clearSaveTimer()
    try {
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true })
      const temporary = `${this.filePath}.tmp`
      fs.writeFileSync(temporary, `${JSON.stringify(this.data, null, 2)}\n`, 'utf8')
      fs.renameSync(temporary, this.filePath)
    } catch (error) {
      this.emit('persist-error', error)
    }
  }

  persistSoon() {
    if (this.saveTimer) return
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null
      this.persist()
    }, SAVE_DELAY_MS)
  }

  flush() {
    if (this.saveTimer) this.persist()
  }

  clearSaveTimer() {
    if (!this.saveTimer) return
    clearTimeout(this.saveTimer)
    this.saveTimer = null
  }

  dispose() {
    this.stopAuto({ silent: true })
    this.flush()
    this.removeAllListeners()
  }

  // MARK: - Gerät / Sync-Schalter

  get deviceId() {
    return this.data.deviceId
  }

  get syncEnabled() {
    return this.data.syncEnabled
  }

  setSyncEnabled(enabled) {
    const value = Boolean(enabled)
    if (this.data.syncEnabled === value) return
    this.data.syncEnabled = value
    this.persistSoon()
  }

  // MARK: - Wasser

  get water() {
    return this.data.water
  }

  todayML() {
    const today = localDayString(new Date(this.now()))
    const history = this.data.water.history
    if (Object.prototype.hasOwnProperty.call(history, today)) return history[today]
    if (this.data.water.day === today) return Math.max(0, this.data.water.total)
    return 0
  }

  get sizes() {
    const water = this.data.water
    return {
      glass: water.glass > 0 ? water.glass : DEFAULT_SIZES.glass,
      bottle: water.bottle > 0 ? water.bottle : DEFAULT_SIZES.bottle,
      goal: water.goal > 0 ? water.goal : DEFAULT_SIZES.goal,
    }
  }

  lastAddedML() {
    const water = this.data.water
    if (water.day !== localDayString(new Date(this.now()))) return null
    const adds = water.recentAdds
    return adds.length > 0 ? adds[adds.length - 1] : null
  }

  addWater(ml) {
    const amount = Math.trunc(Number(ml))
    if (!Number.isFinite(amount) || amount <= 0) return false

    // Wie WaterStore.add: an einem neuen Tag beginnt der Undo-Stapel leer.
    if (this.data.water.day !== localDayString(new Date(this.now()))) {
      this.data.water.recentAdds = []
    }

    this.setToday(this.todayML() + amount)
    const recent = this.data.water.recentAdds
    recent.push(amount)
    if (recent.length > 50) recent.splice(0, recent.length - 50)
    this.data.water.recentAdds = recent
    return true
  }

  undoWater() {
    const water = this.data.water
    if (water.day !== localDayString(new Date(this.now()))) return false
    const stack = water.recentAdds
    const last = stack.pop()
    if (last === undefined) return false
    water.recentAdds = stack
    this.setToday(Math.max(0, this.todayML() - last))
    return true
  }

  resetToday() {
    this.data.water.recentAdds = []
    this.setToday(0)
  }

  setSizes({ glass, bottle, goal }) {
    const water = this.data.water
    let changed = false

    if (Number.isFinite(Number(glass))) {
      const value = Math.min(1000, Math.max(50, Math.trunc(Number(glass))))
      if (value !== water.glass) {
        water.glass = value
        changed = true
      }
    }
    if (Number.isFinite(Number(bottle))) {
      const value = Math.min(3000, Math.max(100, Math.trunc(Number(bottle))))
      if (value !== water.bottle) {
        water.bottle = value
        changed = true
      }
    }
    if (Number.isFinite(Number(goal))) {
      const value = Math.min(6000, Math.max(500, Math.trunc(Number(goal))))
      if (value !== water.goal) {
        water.goal = value
        changed = true
      }
    }

    if (changed) this.markChanged('water')
    return changed
  }

  setToday(value) {
    const today = localDayString(new Date(this.now()))
    const total = Math.max(0, Math.trunc(value))
    this.data.water.total = total
    this.data.water.day = today
    this.data.water.history[today] = total
    this.data.water.history = pruneHistory(this.data.water.history, new Date(this.now()))
    this.markChanged('water')
  }

  lastDays(count) {
    const now = new Date(this.now())
    const days = []
    for (let offset = count - 1; offset >= 0; offset -= 1) {
      const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() - offset)
      const key = localDayString(date)
      const ml = key === localDayString(now)
        ? this.todayML()
        : Math.max(0, this.data.water.history[key] ?? 0)
      days.push({ date: key, ml })
    }
    return days
  }

  waterUpdatedAt() {
    return this.data.water.updatedAt
  }

  hasWaterData() {
    return Object.keys(this.data.water.history).length > 0 || this.data.water.total !== 0
  }

  /** null = noch nichts zu synchronisieren (wie WaterStore.sendState auf dem Mac). */
  waterSnapshot() {
    const updatedAt = this.data.water.updatedAt
    if (!this.hasWaterData() && updatedAt === null) return null
    const sizes = this.sizes
    return {
      history: { ...this.data.water.history },
      recentAdds: [...this.data.water.recentAdds],
      day: this.data.water.day,
      total: this.data.water.total,
      glass: sizes.glass,
      bottle: sizes.bottle,
      goal: sizes.goal,
      updatedAt: updatedAt === null ? APPLE_DISTANT_PAST : updatedAt,
    }
  }

  /** Übernimmt einen fremden Stand, ohne ihn als lokale Änderung zu markieren. */
  applyRemoteWater(snapshot) {
    const normalized = normalizeWaterSnapshot(snapshot)
    if (!normalized) return false
    this.data.water = { ...normalized }
    this.persistSoon()
    this.emit('remote', 'water')
    return true
  }

  // MARK: - Zähler

  get counter() {
    return this.data.counter
  }

  get count() {
    return this.data.counter.count
  }

  get rate() {
    return this.data.counter.rate
  }

  get savedCounters() {
    return this.data.counter.savedCounters
  }

  get isAutoRunning() {
    return this.autoTimer !== null
  }

  increment() {
    this.setCount(this.count + 1)
  }

  decrement() {
    if (this.count <= 0) return
    this.setCount(this.count - 1)
  }

  resetCounter() {
    this.stopAuto()
    if (this.count === 0) return
    this.setCount(0)
  }

  undoCounter() {
    const previous = this.undoStack.pop()
    if (previous === undefined) return
    this.data.counter.count = previous
    this.markChanged('counter')
  }

  setCount(value) {
    this.undoStack.push(this.count)
    if (this.undoStack.length > MAX_UNDO_STEPS) this.undoStack.shift()
    this.data.counter.count = Math.max(0, Math.trunc(value))
    this.markChanged('counter')
  }

  setRate(value) {
    const rate = Math.min(MAX_RATE, Math.max(MIN_RATE, Math.trunc(Number(value))))
    if (!Number.isFinite(rate) || rate === this.data.counter.rate) return
    this.data.counter.rate = rate
    this.markChanged('counter')
  }

  startAuto() {
    if (this.autoTimer) return
    this.autoRemainder = 0
    this.countAtAutoStart = this.count
    this.lastAutoPersist = this.now()

    this.autoTimer = setInterval(() => {
      const interval = AUTO_TICK_MS / 1000
      this.autoRemainder += this.data.counter.rate * interval
      const steps = Math.floor(this.autoRemainder)
      if (steps <= 0) return
      this.autoRemainder -= steps
      this.data.counter.count = Math.max(0, this.data.counter.count + steps)
      this.emit('tick')

      const now = this.now()
      if (now - this.lastAutoPersist >= AUTO_PERSIST_MS) {
        this.lastAutoPersist = now
        this.persistSoon()
      }
    }, AUTO_TICK_MS)

    this.emit('tick')
  }

  stopAuto({ silent = false } = {}) {
    if (!this.autoTimer) return
    clearInterval(this.autoTimer)
    this.autoTimer = null
    this.autoRemainder = 0

    if (this.data.counter.count !== this.countAtAutoStart) {
      this.undoStack.push(this.countAtAutoStart)
      if (this.undoStack.length > MAX_UNDO_STEPS) this.undoStack.shift()
    }
    if (!silent) {
      this.persist()
      this.markChanged('counter')
    }
  }

  toggleAuto() {
    if (this.isAutoRunning) {
      this.stopAuto()
      return false
    }
    this.startAuto()
    return true
  }

  saveCounter(name) {
    const trimmed = typeof name === 'string' ? name.trim() : ''
    const finalName = trimmed.length > 0 ? trimmed.slice(0, 200) : `Stand ${this.savedCounters.length + 1}`
    this.data.counter.savedCounters.unshift({
      id: crypto.randomUUID(),
      name: finalName,
      value: this.count,
      date: toAppleTime(this.now()),
    })
    this.markChanged('counter')
    return finalName
  }

  loadCounter(id) {
    const saved = this.savedCounters.find(item => item.id === id)
    if (!saved) return false
    this.stopAuto()
    this.setCount(saved.value)
    return true
  }

  deleteCounter(id) {
    const index = this.savedCounters.findIndex(item => item.id === id)
    if (index === -1) return false
    this.savedCounters.splice(index, 1)
    this.markChanged('counter')
    return true
  }

  counterUpdatedAt() {
    return this.data.counter.updatedAt
  }

  hasCounterData() {
    return this.data.counter.count !== 0 || this.data.counter.savedCounters.length > 0
  }

  counterSnapshot() {
    const updatedAt = this.data.counter.updatedAt
    if (!this.hasCounterData() && updatedAt === null) return null
    return {
      count: this.data.counter.count,
      savedCounters: this.data.counter.savedCounters.map(item => ({ ...item })),
      rate: this.data.counter.rate,
      updatedAt: updatedAt === null ? APPLE_DISTANT_PAST : updatedAt,
    }
  }

  applyRemoteCounter(snapshot) {
    const normalized = normalizeCounterSnapshot(snapshot)
    if (!normalized) return false
    this.stopAuto({ silent: true })
    this.data.counter = { ...normalized, savedCounters: normalizeSavedCounters(normalized.savedCounters) }
    this.persistSoon()
    this.emit('remote', 'counter')
    return true
  }

  // MARK: - Zustand für die Oberfläche

  getState() {
    const sizes = this.sizes
    return {
      water: {
        today: this.todayML(),
        goal: sizes.goal,
        glass: sizes.glass,
        bottle: sizes.bottle,
        lastAdded: this.lastAddedML(),
        days: this.lastDays(30),
      },
      counter: {
        count: this.count,
        rate: this.rate,
        autoRunning: this.isAutoRunning,
        savedCounters: this.savedCounters.map(item => ({ ...item })),
      },
      syncEnabled: this.syncEnabled,
    }
  }

  markChanged(section) {
    if (section === 'water') {
      this.data.water.updatedAt = toAppleTime(this.now())
    } else {
      this.data.counter.updatedAt = toAppleTime(this.now())
    }
    this.persistSoon()
    this.emit('changed', section)
  }
}

module.exports = { ToolboxStore, DEFAULT_SIZES }
