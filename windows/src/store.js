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
      syncName: '',
      water: {
        history: {},
        recentAdds: [],
        day: null,
        total: 0,
        glass: DEFAULT_SIZES.glass,
        bottle: DEFAULT_SIZES.bottle,
        goal: DEFAULT_SIZES.goal,
        updatedAt: null,
        sizesUpdatedAt: null,
      },
      counter: {
        count: 0,
        savedCounters: [],
        rate: DEFAULT_RATE,
        updatedAt: null,
        rateUpdatedAt: null,
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
      // Do not lose a broken file silently: move it aside.
      try {
        const backup = `${this.filePath}.corrupt-${Date.now()}`
        fs.renameSync(this.filePath, backup)
      } catch {
        // If that fails too, the app starts with empty data.
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
    if (typeof raw.syncName === 'string') data.syncName = raw.syncName.slice(0, 60)

    const water = normalizeWaterSnapshot(raw.water)
    if (water) {
      const legacyUpdatedAt = raw.water.updatedAt
      const legacySizesUpdatedAt = raw.water.sizesUpdatedAt
      data.water = {
        ...water,
        updatedAt: legacyUpdatedAt === null || legacyUpdatedAt === undefined ? null : water.updatedAt,
        // Older files only carry `updatedAt`. Freeze it once as the sizes
        // time so later amount changes no longer move it.
        sizesUpdatedAt: legacySizesUpdatedAt === null || legacySizesUpdatedAt === undefined
          ? (legacyUpdatedAt === null || legacyUpdatedAt === undefined ? null : water.updatedAt)
          : water.sizesUpdatedAt,
      }
    }

    const counter = normalizeCounterSnapshot(raw.counter)
    if (counter) {
      const legacyUpdatedAt = raw.counter.updatedAt
      const legacyRateUpdatedAt = raw.counter.rateUpdatedAt
      data.counter = {
        ...counter,
        updatedAt: legacyUpdatedAt === null || legacyUpdatedAt === undefined ? null : counter.updatedAt,
        // Older files only carry `updatedAt`. Freeze it once as the speed
        // time; new files always contain the key, so a count change never
        // moves it afterwards.
        rateUpdatedAt: legacyRateUpdatedAt === undefined
          ? (legacyUpdatedAt === null || legacyUpdatedAt === undefined ? null : counter.updatedAt)
          : counter.rateUpdatedAt,
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

  // MARK: - Device / sync switch

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

  get syncName() {
    return this.data.syncName
  }

  setSyncName(name) {
    const value = String(name ?? '').slice(0, 60)
    if (this.data.syncName === value) return
    this.data.syncName = value
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

    // Like WaterStore.add: on a new day the undo stack starts empty.
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

    if (changed) this.markSizesChanged()
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

  waterSizesUpdatedAt() {
    return this.data.water.sizesUpdatedAt
  }

  hasWaterData() {
    return Object.keys(this.data.water.history).length > 0 || this.data.water.total !== 0
  }

  /** null = nothing to sync yet (like WaterStore.sendState on the Mac). */
  waterSnapshot() {
    const updatedAt = this.data.water.updatedAt
    const sizesUpdatedAt = this.data.water.sizesUpdatedAt
    if (!this.hasWaterData() && updatedAt === null && sizesUpdatedAt === null) return null
    const sizes = this.sizes
    const today = localDayString(new Date(this.now()))
    // Only today's undo stack belongs to the current amount.
    const recentAdds = this.data.water.day === today
      ? [...this.data.water.recentAdds]
      : []
    return {
      history: { ...this.data.water.history },
      recentAdds,
      day: this.data.water.day,
      total: this.data.water.total,
      glass: sizes.glass,
      bottle: sizes.bottle,
      goal: sizes.goal,
      updatedAt: updatedAt === null ? APPLE_DISTANT_PAST : updatedAt,
      sizesUpdatedAt: sizesUpdatedAt === null ? APPLE_DISTANT_PAST : sizesUpdatedAt,
    }
  }

  /**
   * Merges a foreign state area by area. Amounts and sizes keep their own
   * timestamps: a device that only changed the goal keeps its old amount
   * timestamp and cannot overwrite newer amounts of this device.
   * Adopts a foreign state without marking it as a local change.
   */
  applyRemoteWater(snapshot) {
    const normalized = normalizeWaterSnapshot(snapshot)
    if (!normalized) return false

    const water = this.data.water
    let applied = false

    if (water.updatedAt === null || normalized.updatedAt > water.updatedAt) {
      water.history = normalized.history
      water.recentAdds = normalized.recentAdds
      water.day = normalized.day
      water.total = normalized.total
      water.updatedAt = normalized.updatedAt
      applied = true
    }

    if (water.sizesUpdatedAt === null || normalized.sizesUpdatedAt > water.sizesUpdatedAt) {
      water.glass = normalized.glass
      water.bottle = normalized.bottle
      water.goal = normalized.goal
      water.sizesUpdatedAt = normalized.sizesUpdatedAt
      applied = true
    }

    if (!applied) return false

    this.persistSoon()
    this.emit('remote', 'water')
    return true
  }

  /** Does the other device have older amounts or sizes? */
  isWaterPeerBehind(snapshot) {
    const normalized = normalizeWaterSnapshot(snapshot)
    if (!normalized) return false
    const water = this.data.water
    if (water.updatedAt !== null && normalized.updatedAt < water.updatedAt) return true
    if (water.sizesUpdatedAt !== null && normalized.sizesUpdatedAt < water.sizesUpdatedAt) return true
    return false
  }

  // MARK: - Counter

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
    this.markRateChanged()
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

  counterRateUpdatedAt() {
    return this.data.counter.rateUpdatedAt
  }

  hasCounterData() {
    return this.data.counter.count !== 0 || this.data.counter.savedCounters.length > 0
  }

  counterSnapshot() {
    const updatedAt = this.data.counter.updatedAt
    const rateUpdatedAt = this.data.counter.rateUpdatedAt
    if (!this.hasCounterData() && updatedAt === null && rateUpdatedAt === null) return null
    return {
      count: this.data.counter.count,
      savedCounters: this.data.counter.savedCounters.map(item => ({ ...item })),
      rate: this.data.counter.rate,
      updatedAt: updatedAt === null ? APPLE_DISTANT_PAST : updatedAt,
      rateUpdatedAt: rateUpdatedAt === null ? APPLE_DISTANT_PAST : rateUpdatedAt,
    }
  }

  /**
   * Merges a foreign state area by area. Count (including saved values) and
   * speed keep their own timestamps: a device that only changed the speed
   * cannot overwrite a newer count of this device.
   */
  applyRemoteCounter(snapshot) {
    const normalized = normalizeCounterSnapshot(snapshot)
    if (!normalized) return false

    const counter = this.data.counter
    let applied = false

    if (counter.updatedAt === null || normalized.updatedAt > counter.updatedAt) {
      this.stopAuto({ silent: true })
      counter.count = normalized.count
      counter.savedCounters = normalizeSavedCounters(normalized.savedCounters)
      counter.updatedAt = normalized.updatedAt
      applied = true
    }

    if (counter.rateUpdatedAt === null || normalized.rateUpdatedAt > counter.rateUpdatedAt) {
      counter.rate = normalized.rate
      counter.rateUpdatedAt = normalized.rateUpdatedAt
      applied = true
    }

    if (!applied) return false

    this.persistSoon()
    this.emit('remote', 'counter')
    return true
  }

  /** Does the other device have older count data or speed? */
  isCounterPeerBehind(snapshot) {
    const normalized = normalizeCounterSnapshot(snapshot)
    if (!normalized) return false
    const counter = this.data.counter
    if (counter.updatedAt !== null && normalized.updatedAt < counter.updatedAt) return true
    if (counter.rateUpdatedAt !== null && normalized.rateUpdatedAt < counter.rateUpdatedAt) return true
    return false
  }

  // MARK: - State for the interface

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

  /** Notes a size change; the amount timestamp stays untouched. */
  markSizesChanged() {
    this.data.water.sizesUpdatedAt = toAppleTime(this.now())
    this.persistSoon()
    this.emit('changed', 'water')
  }

  /** Notes a speed change; the count timestamp stays untouched. */
  markRateChanged() {
    this.data.counter.rateUpdatedAt = toAppleTime(this.now())
    this.persistSoon()
    this.emit('changed', 'counter')
  }
}

module.exports = { ToolboxStore, DEFAULT_SIZES }
