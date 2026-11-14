'use strict'

const api = window.toolbox
const $ = id => document.getElementById(id)

const APPLE_EPOCH_OFFSET_SECONDS = 978_307_200
const RING_CIRCUMFERENCE = 2 * Math.PI * 92
const RING_RADIUS = 92

const PAGES = {
  today: { title: 'Wassertracker', subtitle: 'Dein Fortschritt für heute' },
  history: { title: 'Verlauf', subtitle: 'Die letzten 30 Tage im Überblick' },
  units: { title: 'Einheiten', subtitle: 'MB/GB und Mbit/MB umrechnen' },
  counter: { title: 'Zähler', subtitle: 'Manuell oder automatisch zählen' },
  download: { title: 'Downloadzeit', subtitle: 'Dateigröße und Geschwindigkeit' },
  energy: { title: 'Stromverbrauch', subtitle: 'Leistung, Dauer und Kosten' },
}

const TAB_ORDER = ['today', 'history', 'units', 'counter', 'download', 'energy']

const SIZE_LIMITS = {
  glass: { min: 50, max: 1000 },
  bottle: { min: 100, max: 3000 },
  goal: { min: 500, max: 6000 },
}

const UNIT_MODES = {
  mbToGB: {
    field: 'Wert in MB',
    suffix: 'MB',
    result: 'GB',
    convert: value => value / 1000,
  },
  gbToMB: {
    field: 'Wert in GB',
    suffix: 'GB',
    result: 'MB',
    convert: value => value * 1000,
  },
  mbitToMB: {
    field: 'Wert in Mbit',
    suffix: 'Mbit',
    result: 'MB',
    convert: value => value / 8,
  },
  mbToMbit: {
    field: 'Wert in MB',
    suffix: 'MB',
    result: 'Mbit',
    convert: value => value * 8,
  },
}

const ICONS = {
  play: '<svg class="i" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5.2 19 12 8 18.8V5.2z"/></svg>',
  stop: '<svg class="i" viewBox="0 0 24 24" fill="currentColor"><rect x="6.5" y="6.5" width="11" height="11" rx="1.6"/></svg>',
  check: '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12.5 9 17.5 20 6.5"/></svg>',
  bookmark: '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h12v18l-6-4-6 4V3z"/></svg>',
  trash: '<svg class="i" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14"/></svg>',
}

let state = null
let activeTab = 'today'
let unitMode = 'mbToGB'
let speedUnit = 'mbit'
let settingsOpen = false
let sizeDraft = {}
let sizeTimer = null
let syncNameTimer = null
let pendingSyncName = null
let toastTimer = null
let amountValue = null
let lastRenderedWater = null
let updateState = null
let promptedUpdateVersion = null

// ------------------------------------------------------------------ Start

document.addEventListener('DOMContentLoaded', init)

async function init() {
  document.body.dataset.platform = 'win32'

  if (!api) {
    toast('Toolbox konnte die Windows-Schnittstelle nicht laden.')
    return
  }

  bindNavigation()
  bindToday()
  bindUnits()
  bindDownload()
  bindEnergy()
  bindCounter()
  bindSettings()
  bindUpdates()
  bindModals()
  bindKeyboard()
  buildAmountPresets()

  api.onStateChanged(() => refresh())
  api.onCounterTick(payload => {
    if (!state || !payload) return
    state.counter.count = payload.count
    if (activeTab === 'counter') renderCounterValue()
  })
  api.onUpdateChanged(next => applyUpdateState(next))

  await refresh()
  await refreshUpdate()
  setTab('today')
}

async function refresh() {
  try {
    const next = await api.getState()
    if (next) applyState(next)
  } catch (error) {
    console.error('Zustand konnte nicht geladen werden:', error)
  }
}

function applyState(next) {
  // Noch nicht gespeicherte Mengen-Änderungen aus den Einstellungen nicht überschreiben.
  if (settingsOpen && Object.keys(sizeDraft).length > 0) {
    Object.assign(next.water, sizeDraft)
  }

  state = next
  document.body.dataset.platform = next.platform || 'win32'

  renderSyncChip()
  renderSettingsValues()

  if (activeTab === 'today') renderToday()
  if (activeTab === 'history') {
    renderHistory()
    requestAnimationFrame(drawChart)
  }
  if (activeTab === 'counter') renderCounter()
  if (settingsOpen) renderSettings()
}

// --------------------------------------------------------------- Navigation

function bindNavigation() {
  document.querySelectorAll('.nav-row').forEach(button => {
    button.addEventListener('click', () => setTab(button.dataset.tab))
  })
}

function setTab(tab) {
  if (!PAGES[tab]) return
  activeTab = tab

  document.querySelectorAll('.nav-row').forEach(button => {
    button.classList.toggle('active', button.dataset.tab === tab)
  })
  document.querySelectorAll('.page').forEach(page => {
    page.hidden = page.dataset.page !== tab
  })

  $('pageTitle').textContent = PAGES[tab].title
  $('pageSubtitle').textContent = PAGES[tab].subtitle
  $('pageScroll').scrollTop = 0

  if (tab === 'today') renderToday()
  if (tab === 'history') {
    renderHistory()
    requestAnimationFrame(drawChart)
  }
  if (tab === 'counter') renderCounter()
}

// -------------------------------------------------------------------- Heute

function bindToday() {
  $('quickGlass').addEventListener('click', () => {
    if (state) run(api.water.add(state.water.glass))
  })
  $('quickBottle').addEventListener('click', () => {
    if (state) run(api.water.add(state.water.bottle))
  })
  $('undoWater').addEventListener('click', () => run(api.water.undo()))
  $('addCustom').addEventListener('click', openAmountModal)
}

function renderToday() {
  if (!state) return
  const water = state.water
  const goal = Math.max(water.goal, 1)
  const progress = Math.min(1, water.today / goal)
  const percent = Math.round(progress * 100)
  const remaining = Math.max(water.goal - water.today, 0)

  const valueElement = $('todayML')
  valueElement.textContent = formatInteger(water.today)
  if (lastRenderedWater !== null && lastRenderedWater !== water.today) {
    valueElement.classList.remove('bump')
    void valueElement.offsetWidth
    valueElement.classList.add('bump')
  }
  lastRenderedWater = water.today

  $('ringPercent').textContent = String(percent)
  $('ringSub').textContent = `${formatInteger(water.today)} / ${formatInteger(water.goal)}`
  $('ringValue').style.strokeDasharray = String(RING_CIRCUMFERENCE)
  $('ringValue').style.strokeDashoffset = String(RING_CIRCUMFERENCE * (1 - progress))
  $('ringValue').setAttribute('r', String(RING_RADIUS))

  $('todaySub').textContent = remaining === 0
    ? `Tagesziel erreicht – ${formatInteger(water.goal)} ml geschafft.`
    : `von ${formatInteger(water.goal)} ml Ziel · noch ${formatInteger(remaining)} ml offen`

  $('todayBar').style.width = `${(progress * 100).toFixed(2)}%`

  $('quickGlassSub').textContent = `+${formatInteger(water.glass)} ml`
  $('quickBottleSub').textContent = `+${formatInteger(water.bottle)} ml`

  const undoButton = $('undoWater')
  undoButton.disabled = water.lastAdded === null
  $('undoLabel').textContent = water.lastAdded === null
    ? 'Rückgängig'
    : `Rückgängig (${formatInteger(water.lastAdded)} ml)`

  $('tileGlass').textContent = `${formatInteger(water.glass)} ml`
  $('tileBottle').textContent = `${formatInteger(water.bottle)} ml`
  $('tileGoal').textContent = `${formatInteger(water.goal)} ml`

  if (settingsOpen) renderSettingsValues()
}

// ------------------------------------------------------------------ Verlauf

function renderHistory() {
  if (!state) return
  const days = state.water.days
  const goal = Math.max(state.water.goal, 1)
  const total = days.reduce((sum, day) => sum + day.ml, 0)

  $('histAvg').textContent = `${formatInteger(Math.round(total / Math.max(days.length, 1)))} ml`
  $('histReached').textContent = `${days.filter(day => day.ml >= goal).length} von ${days.length}`
  $('histBest').textContent = `${formatInteger(Math.max(0, ...days.map(day => day.ml)))} ml`

  renderDayList(days, goal)
}

function renderDayList(days, goal) {
  const list = $('dayList')
  list.replaceChildren()

  for (const day of [...days].reverse()) {
    const row = document.createElement('div')
    row.className = 'day-row'

    const date = document.createElement('div')
    date.className = 'day-date'
    date.textContent = formatDayLabel(day.date)

    const ml = document.createElement('div')
    ml.className = 'day-ml'
    ml.textContent = `${formatInteger(day.ml)} ml`

    const spacer = document.createElement('div')
    spacer.className = 'day-spacer'

    const check = document.createElement('div')
    check.className = day.ml >= goal ? 'day-check reached' : 'day-check'
    if (day.ml >= goal) check.innerHTML = ICONS.check

    row.append(date, ml, spacer, check)
    list.append(row)
  }
}

function drawChart() {
  if (!state || activeTab !== 'history') return
  const canvas = $('chart')
  const wrap = canvas.parentElement
  const rect = wrap.getBoundingClientRect()
  if (rect.width < 40 || rect.height < 40) return

  const dpr = window.devicePixelRatio || 1
  canvas.width = Math.round(rect.width * dpr)
  canvas.height = Math.round(rect.height * dpr)

  const ctx = canvas.getContext('2d')
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0)

  const style = getComputedStyle(document.documentElement)
  const grid = style.getPropertyValue('--chart-grid').trim() || 'rgba(255,255,255,.1)'
  const label = style.getPropertyValue('--chart-label').trim() || 'rgba(255,255,255,.4)'

  const width = rect.width
  const height = rect.height
  const padding = { top: 16, right: 14, bottom: 28, left: 54 }
  const plotWidth = width - padding.left - padding.right
  const plotHeight = height - padding.top - padding.bottom

  const days = state.water.days
  const goal = Math.max(state.water.goal, 1)
  const highest = Math.max(goal, ...days.map(day => day.ml), 250)
  const maxValue = Math.ceil((highest * 1.12) / 250) * 250

  const yFor = value => padding.top + plotHeight - (value / maxValue) * plotHeight

  ctx.clearRect(0, 0, width, height)
  ctx.font = '11px "Segoe UI", system-ui, sans-serif'
  ctx.textBaseline = 'middle'

  // Gitterlinien und Y-Beschriftung
  const gridCount = 4
  for (let index = 0; index <= gridCount; index += 1) {
    const value = (maxValue / gridCount) * index
    const y = yFor(value)

    ctx.beginPath()
    ctx.setLineDash([3, 4])
    ctx.strokeStyle = grid
    ctx.lineWidth = 1
    ctx.moveTo(padding.left, y)
    ctx.lineTo(width - padding.right, y)
    ctx.stroke()

    ctx.setLineDash([])
    ctx.fillStyle = label
    ctx.textAlign = 'right'
    ctx.fillText(formatInteger(Math.round(value)), padding.left - 9, y)
  }

  const slot = plotWidth / Math.max(days.length, 1)
  const barWidth = Math.max(4, Math.min(26, slot * 0.62))
  const baseline = padding.top + plotHeight

  // Balken
  let lastLabeledIndex = -10
  for (let index = 0; index < days.length; index += 1) {
    const day = days[index]
    const x = padding.left + slot * index + (slot - barWidth) / 2
    const top = yFor(day.ml)
    const barHeight = Math.max(day.ml > 0 ? 2 : 1, baseline - top)

    const gradient = ctx.createLinearGradient(0, top, 0, baseline)
    if (day.ml >= goal) {
      gradient.addColorStop(0, '#5fe3a8')
      gradient.addColorStop(1, '#33d4ed')
    } else {
      gradient.addColorStop(0, 'rgba(74, 163, 255, 0.95)')
      gradient.addColorStop(1, 'rgba(74, 163, 255, 0.28)')
    }
    ctx.fillStyle = gradient
    ctx.beginPath()
    ctx.roundRect(x, top, barWidth, barHeight, 3)
    ctx.fill()

    if (index % 7 === 0 || (index === days.length - 1 && index - lastLabeledIndex >= 4)) {
      ctx.fillStyle = label
      ctx.textAlign = 'center'
      ctx.fillText(formatShortDate(day.date), x + barWidth / 2, height - 12)
      lastLabeledIndex = index
    }
  }

  // Tagesziel
  const goalY = yFor(goal)
  ctx.beginPath()
  ctx.setLineDash([6, 4])
  ctx.strokeStyle = 'rgba(161, 132, 255, 0.9)'
  ctx.lineWidth = 1.5
  ctx.moveTo(padding.left, goalY)
  ctx.lineTo(width - padding.right, goalY)
  ctx.stroke()
  ctx.setLineDash([])

  ctx.fillStyle = 'rgba(161, 132, 255, 1)'
  ctx.textAlign = 'right'
  ctx.fillText(`Ziel: ${formatInteger(goal)} ml`, width - padding.right, Math.max(10, goalY - 10))
}

// ----------------------------------------------------------------- Einheiten

function bindUnits() {
  document.querySelectorAll('#unitModes button').forEach(button => {
    button.addEventListener('click', () => {
      unitMode = button.dataset.mode
      document.querySelectorAll('#unitModes button').forEach(item => {
        item.classList.toggle('active', item === button)
      })
      renderUnitMode()
    })
  })

  $('unitInput').addEventListener('input', computeUnits)
  $('unitReset').addEventListener('click', () => {
    $('unitInput').value = ''
    computeUnits()
  })

  renderUnitMode()
}

function renderUnitMode() {
  const mode = UNIT_MODES[unitMode]
  $('unitFieldLabel').textContent = mode.field
  $('unitSuffix').textContent = mode.suffix
  computeUnits()
}

function computeUnits() {
  const mode = UNIT_MODES[unitMode]
  const value = parseDecimal($('unitInput').value)
  const result = $('unitResult')

  if (value === null) {
    result.textContent = '—'
    result.classList.add('empty')
    $('unitResultSub').textContent = 'Wert eingeben'
    return
  }

  result.textContent = formatDecimal(mode.convert(value))
  result.classList.remove('empty')
  $('unitResultSub').textContent = `Ergebnis in ${mode.result}`
}

// -------------------------------------------------------------- Downloadzeit

function bindDownload() {
  document.querySelectorAll('#speedUnits button').forEach(button => {
    button.addEventListener('click', () => {
      speedUnit = button.dataset.unit
      document.querySelectorAll('#speedUnits button').forEach(item => {
        item.classList.toggle('active', item === button)
      })
      $('speedSuffix').textContent = speedUnit === 'mbit' ? 'Mbit/s' : 'MB/s'
      computeDownload()
    })
  })

  $('downloadSize').addEventListener('input', computeDownload)
  $('downloadSpeed').addEventListener('input', computeDownload)
  $('downloadReset').addEventListener('click', () => {
    $('downloadSize').value = ''
    $('downloadSpeed').value = ''
    computeDownload()
  })

  computeDownload()
}

function computeDownload() {
  const size = parseDecimal($('downloadSize').value)
  const speed = parseDecimal($('downloadSpeed').value)
  const result = $('downloadResult')

  if (size === null || speed === null || speed <= 0) {
    result.textContent = '—'
    result.classList.add('empty')
    $('downloadResultSub').textContent = 'Dateigröße und Geschwindigkeit eingeben'
    return
  }

  const sizeInMB = size * 1000
  const speedInMBPerSecond = speed * (speedUnit === 'mbit' ? 1 / 8 : 1)
  const seconds = sizeInMB / speedInMBPerSecond

  result.textContent = formatDuration(seconds)
  result.classList.remove('empty')
  $('downloadResultSub').textContent = 'Berechnet ohne zusätzliche Verzögerungen'
}

// ------------------------------------------------------------ Stromverbrauch

function bindEnergy() {
  for (const id of ['energyPower', 'energyDuration', 'energyPrice']) {
    $(id).addEventListener('input', computeEnergy)
  }
  $('energyReset').addEventListener('click', () => {
    $('energyPower').value = ''
    $('energyDuration').value = ''
    $('energyPrice').value = ''
    computeEnergy()
  })
  computeEnergy()
}

function computeEnergy() {
  const power = parseDecimal($('energyPower').value)
  const hours = parseDecimal($('energyDuration').value)
  const price = parseDecimal($('energyPrice').value)
  const result = $('energyResult')

  if (power === null || hours === null) {
    result.textContent = '—'
    result.classList.add('empty')
    $('energyCost').textContent = 'Kosten: Kein Strompreis angegeben'
    return
  }

  const energy = (power / 1000) * hours
  result.textContent = `${formatDecimal(energy)} kWh`
  result.classList.remove('empty')

  $('energyCost').textContent = price === null
    ? 'Kosten: Kein Strompreis angegeben'
    : `Kosten: ${formatCurrency(energy * price)}`
}

// ------------------------------------------------------------------- Zähler

function bindCounter() {
  $('counterPlus').addEventListener('click', () => run(api.counter.increment()))
  $('counterMinus').addEventListener('click', () => run(api.counter.decrement()))
  $('counterReset').addEventListener('click', () => run(api.counter.reset()))
  $('counterUndo').addEventListener('click', () => run(api.counter.undo()))
  $('rateDown').addEventListener('click', () => {
    if (state) run(api.counter.setRate(state.counter.rate - 1))
  })
  $('rateUp').addEventListener('click', () => {
    if (state) run(api.counter.setRate(state.counter.rate + 1))
  })
  $('autoToggle').addEventListener('click', () => run(api.counter.toggleAuto()))
  $('saveCounter').addEventListener('click', openSaveModal)
}

function renderCounter() {
  if (!state) return
  const counter = state.counter

  renderCounterValue()
  $('autoBadge').hidden = !counter.autoRunning
  $('autoRate').textContent = `${counter.rate}× pro Sekunde`
  $('rateDown').disabled = counter.rate <= 1
  $('rateUp').disabled = counter.rate >= 100

  const toggle = $('autoToggle')
  toggle.className = counter.autoRunning ? 'btn danger' : 'btn primary'
  toggle.innerHTML = `${counter.autoRunning ? ICONS.stop : ICONS.play}${counter.autoRunning ? 'Stopp' : 'Start'}`

  renderSavedCounters(counter.savedCounters)
}

function renderCounterValue() {
  if (!state) return
  $('counterValue').textContent = formatInteger(state.counter.count)
}

function renderSavedCounters(counters) {
  const list = $('savedList')
  list.replaceChildren()

  if (counters.length === 0) {
    const empty = document.createElement('div')
    empty.className = 'saved-empty'
    empty.innerHTML = `${ICONS.bookmark}<strong>Noch nichts gespeichert</strong><small>Speichere den aktuellen Stand über das Lesezeichen oben.</small>`
    list.append(empty)
    return
  }

  for (const item of counters) {
    const row = document.createElement('div')
    row.className = 'saved-row'
    row.title = 'Stand laden'

    const copy = document.createElement('div')
    copy.className = 'saved-copy'

    const name = document.createElement('span')
    name.className = 'saved-name'
    name.textContent = item.name

    const date = document.createElement('span')
    date.className = 'saved-date'
    date.textContent = formatSavedDate(item.date)

    copy.append(name, date)

    const value = document.createElement('span')
    value.className = 'saved-value'
    value.textContent = formatInteger(item.value)

    const remove = document.createElement('button')
    remove.className = 'saved-delete'
    remove.title = 'Stand löschen'
    remove.setAttribute('aria-label', 'Stand löschen')
    remove.innerHTML = ICONS.trash
    remove.addEventListener('click', event => {
      event.stopPropagation()
      run(api.counter.remove(item.id))
    })

    row.append(copy, value, remove)
    row.addEventListener('click', () => run(api.counter.load(item.id)))
    list.append(row)
  }
}

// ------------------------------------------------------------------ Einstellungen

function bindSettings() {
  $('openSettings').addEventListener('click', openSettings)
  $('syncChip').addEventListener('click', openSettings)
  $('settingsDone').addEventListener('click', () => closeModal('settingsModal'))

  document.querySelectorAll('.stepper button').forEach(button => {
    button.addEventListener('click', () => {
      changeSize(button.dataset.size, Number(button.dataset.step))
    })
  })

  $('syncToggle').addEventListener('change', async event => {
    const enabled = event.target.checked
    await run(api.sync.setEnabled(enabled))
    toast(enabled ? 'Sync im WLAN eingeschaltet' : 'Sync im WLAN ausgeschaltet')
  })

  $('syncName').addEventListener('input', event => scheduleSyncName(event.target.value))
  $('syncName').addEventListener('change', event => scheduleSyncName(event.target.value, 0))

  $('syncNow').addEventListener('click', async () => {
    await run(api.sync.syncNow())
    toast('Suche nach Geräten im WLAN…')
  })

  $('resetWater').addEventListener('click', async () => {
    await run(api.water.reset())
    toast('Heutige Trinkmenge zurückgesetzt')
  })
}

function bindUpdates() {
  $('autoUpdateToggle').addEventListener('change', event => {
    const enabled = event.target.checked
    runUpdate(api.update.setAutomatic(enabled))
    toast(enabled ? 'Automatische Update-Prüfung eingeschaltet' : 'Automatische Update-Prüfung ausgeschaltet')
  })

  $('checkUpdates').addEventListener('click', () => {
    if (updateState && updateState.update) {
      openModal('updateModal', $('checkUpdates'))
      return
    }
    runUpdate(api.update.check())
  })

  $('updateLater').addEventListener('click', () => closeModal('updateModal'))
  $('updateInstall').addEventListener('click', () => runUpdate(api.update.install()))
}

function openSettings() {
  settingsOpen = true
  renderSettings()
  openModal('settingsModal', $('openSettings'))
}

function renderSettings() {
  if (!state) return
  renderSettingsValues()

  const sync = state.sync
  $('syncToggle').checked = Boolean(sync.enabled)

  // Während des Tippens nicht überschreiben; der Name wird entprellt gespeichert.
  const nameInput = $('syncName')
  if (document.activeElement !== nameInput) nameInput.value = sync.syncName || ''

  $('syncStatus').textContent = syncStatusText(sync)
  $('syncDeviceName').textContent = sync.deviceName || 'Windows-PC'
  $('syncNow').disabled = !sync.enabled || !String(sync.syncName || '').trim()

  const error = $('syncError')
  error.hidden = !sync.discoveryError
  error.textContent = sync.discoveryError || ''

  const peers = $('peerList')
  peers.replaceChildren()
  if (!sync.enabled) {
    const hint = document.createElement('div')
    hint.className = 'hint'
    hint.textContent = 'Der Abgleich ist ausgeschaltet.'
    peers.append(hint)
  } else if (sync.peers.length === 0) {
    const hint = document.createElement('div')
    hint.className = 'hint'
    hint.textContent = 'Noch kein Gerät verbunden. Öffne Toolbox auf einem Gerät mit demselben Namen im selben WLAN.'
    peers.append(hint)
  } else {
    for (const peer of sync.peers) {
      const row = document.createElement('div')
      row.className = 'peer'
      const dot = document.createElement('span')
      dot.className = 'peer-dot'
      const name = document.createElement('span')
      name.textContent = peer.name || 'Gerät'
      row.append(dot, name)
      peers.append(row)
    }
  }

  $('versionText').textContent = `Version ${state.version || ''}`
  renderUpdateSection()
}

function renderSettingsValues() {
  if (!state) return
  $('settingGlass').textContent = `${formatInteger(state.water.glass)} ml`
  $('settingBottle').textContent = `${formatInteger(state.water.bottle)} ml`
  $('settingGoal').textContent = `${formatInteger(state.water.goal)} ml`
}

function changeSize(field, delta) {
  if (!state || !SIZE_LIMITS[field]) return
  const limits = SIZE_LIMITS[field]
  const current = sizeDraft[field] ?? state.water[field]
  const next = Math.min(limits.max, Math.max(limits.min, current + delta))

  sizeDraft[field] = next
  state.water[field] = next
  renderSettingsValues()
  if (activeTab === 'today') renderToday()

  clearTimeout(sizeTimer)
  sizeTimer = setTimeout(flushSizeDraft, 220)
}

function flushSizeDraft() {
  clearTimeout(sizeTimer)
  sizeTimer = null
  if (!state || Object.keys(sizeDraft).length === 0) return

  const sizes = {
    glass: state.water.glass,
    bottle: state.water.bottle,
    goal: state.water.goal,
  }
  sizeDraft = {}
  run(api.water.setSizes(sizes))
}

function scheduleSyncName(value, delay = 400) {
  pendingSyncName = value
  clearTimeout(syncNameTimer)
  syncNameTimer = setTimeout(flushSyncName, delay)
}

function flushSyncName() {
  clearTimeout(syncNameTimer)
  syncNameTimer = null
  if (pendingSyncName === null) return
  const name = pendingSyncName
  pendingSyncName = null
  run(api.sync.setName(name))
}

function syncStatusText(sync) {
  if (!sync.enabled) return 'Aus'
  if (!String(sync.syncName || '').trim()) return 'Name fehlt'
  if (sync.peerCount === 1) return 'Verbunden mit 1 Gerät'
  if (sync.peerCount > 1) return `Verbunden mit ${sync.peerCount} Geräten`
  if (sync.discoveryError) return 'Netzwerk-Problem'
  if (sync.lastSync) return `Zuletzt ${formatTime(sync.lastSync)}`
  return sync.isSearching ? 'Suche im WLAN…' : 'Kein Gerät gefunden'
}

function renderSyncChip() {
  if (!state) return
  const sync = state.sync

  $('syncChipTitle').textContent = sync.enabled ? 'Sync im WLAN' : 'Sync aus'
  $('syncChipSub').textContent = syncStatusText(sync)

  const dot = $('syncDot')
  dot.classList.toggle('online', sync.enabled && sync.peerCount > 0)
  dot.classList.toggle('searching', sync.enabled && sync.peerCount === 0)
  dot.classList.toggle('off', !sync.enabled)
}

// -------------------------------------------------------------------- Modals

function bindModals() {
  document.querySelectorAll('[data-close]').forEach(button => {
    button.addEventListener('click', () => closeModal(button.dataset.close))
  })

  document.querySelectorAll('.overlay').forEach(overlay => {
    overlay.addEventListener('mousedown', event => {
      if (event.target === overlay) closeModal(overlay.id)
    })
  })

  $('amountInput').addEventListener('input', validateAmount)
  $('amountInput').addEventListener('keydown', event => {
    if (event.key === 'Enter') {
      event.preventDefault()
      saveAmount()
    }
  })
  $('amountSave').addEventListener('click', saveAmount)

  $('saveNameInput').addEventListener('keydown', event => {
    if (event.key === 'Enter') {
      event.preventDefault()
      saveCounterStand()
    }
  })
  $('saveConfirm').addEventListener('click', saveCounterStand)
}

function openModal(id, opener = null) {
  const overlay = $(id)
  if (!overlay) return
  overlay.hidden = false
  overlay.dataset.opener = opener && opener.id ? opener.id : ''

  const focusTarget = overlay.querySelector('input:not([type="checkbox"]):not([type="radio"])')
    || overlay.querySelector('.modal-foot .btn.primary')
    || overlay.querySelector('button')
  if (focusTarget) {
    requestAnimationFrame(() => {
      focusTarget.focus()
      if (typeof focusTarget.select === 'function') focusTarget.select()
    })
  }
}

function closeModal(id) {
  const overlay = $(id)
  if (!overlay || overlay.hidden) return
  overlay.hidden = true

  if (id === 'settingsModal') {
    settingsOpen = false
    flushSizeDraft()
    flushSyncName()
  }

  if (id === 'amountModal') {
    $('amountInput').value = ''
    amountValue = null
  }
  if (id === 'saveModal') $('saveNameInput').value = ''

  const opener = overlay.dataset.opener ? $(overlay.dataset.opener) : null
  if (opener) opener.focus()
}

function closeTopModal() {
  const ids = ['settingsModal', 'amountModal', 'saveModal', 'updateModal']
  for (const id of [...ids].reverse()) {
    if (!$(id).hidden) {
      closeModal(id)
      return true
    }
  }
  return false
}

// Eigene Menge

function buildAmountPresets() {
  const grid = $('amountPresets')
  const presets = [100, 150, 200, 250, 330, 500, 750, 1000]

  for (const preset of presets) {
    const button = document.createElement('button')
    button.type = 'button'
    button.textContent = `${preset} ml`
    button.addEventListener('click', () => {
      $('amountInput').value = String(preset)
      validateAmount()
      $('amountSave').disabled = false
    })
    grid.append(button)
  }
}

function openAmountModal() {
  amountValue = null
  $('amountInput').value = ''
  $('amountError').hidden = true
  $('amountInput').classList.remove('invalid')
  $('amountSave').disabled = true
  openModal('amountModal', $('addCustom'))
}

function validateAmount() {
  const value = parseInteger($('amountInput').value)
  const valid = value !== null && value >= 1 && value <= 10000

  amountValue = valid ? value : null
  $('amountSave').disabled = !valid
  $('amountError').hidden = valid || $('amountInput').value.trim() === ''
  $('amountInput').classList.toggle('invalid', !valid && $('amountInput').value.trim() !== '')
}

function saveAmount() {
  if (amountValue === null) {
    validateAmount()
    return
  }
  closeModal('amountModal')
  run(api.water.add(amountValue))
}

// Stand speichern

function openSaveModal() {
  if (!state) return
  $('saveSubtitle').textContent = `Aktueller Stand: ${formatInteger(state.counter.count)}`
  $('saveNameInput').value = ''
  openModal('saveModal', $('saveCounter'))
}

function saveCounterStand() {
  const name = $('saveNameInput').value
  closeModal('saveModal')
  run(api.counter.save(name))
}

// ---------------------------------------------------------------- Tastatur

function bindKeyboard() {
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      if (closeTopModal()) event.preventDefault()
      return
    }

    if (!event.ctrlKey || event.shiftKey || event.altKey || event.metaKey) return

    if (event.key >= '1' && event.key <= '6') {
      const tab = TAB_ORDER[Number(event.key) - 1]
      if (tab) {
        event.preventDefault()
        setTab(tab)
      }
    }

    if (event.key === ',') {
      event.preventDefault()
      if (!settingsOpen) openSettings()
    }
  })
}

// -------------------------------------------------------------------- Updates

async function refreshUpdate() {
  try {
    const next = await api.update.getState()
    if (next) applyUpdateState(next)
  } catch (error) {
    console.error('Update-Status konnte nicht geladen werden:', error)
  }
}

function applyUpdateState(next) {
  updateState = next
  renderUpdateSection()
  renderUpdateModal()

  if (!next.update) {
    if (!$('updateModal').hidden) closeModal('updateModal')
    return
  }

  // Nur einmal pro gefundener Version automatisch öffnen; „Später“ bleibt so bestehen.
  if (next.update.version !== promptedUpdateVersion) {
    promptedUpdateVersion = next.update.version
    if ($('updateModal').hidden) openModal('updateModal', $('checkUpdates'))
  }
}

function renderUpdateSection() {
  if (!updateState) return

  const toggle = $('autoUpdateToggle')
  toggle.checked = Boolean(updateState.automaticChecks)
  toggle.disabled = Boolean(updateState.installing)

  $('updateStatus').textContent = updateStatusText()

  const error = $('updateError')
  error.hidden = !updateState.error
  error.textContent = updateState.error || ''

  const button = $('checkUpdates')
  button.textContent = updateState.update
    ? `Update ${updateState.update.version} installieren`
    : 'Jetzt nach Updates suchen'
  button.disabled = Boolean(updateState.checking || updateState.installing)
}

function updateStatusText() {
  if (updateState.installing) {
    return typeof updateState.progress === 'number'
      ? `Wird geladen … ${Math.round(updateState.progress * 100)} %`
      : 'Wird installiert…'
  }
  if (updateState.checking) return 'Suche nach Updates…'
  if (updateState.update) return `Version ${updateState.update.version} verfügbar`
  if (updateState.error) return 'Prüfung fehlgeschlagen'
  if (updateState.upToDate) return `Aktuell (Version ${updateState.currentVersion})`
  return `Version ${updateState.currentVersion}`
}

function renderUpdateModal() {
  const update = updateState && updateState.update
  if (!update) return

  $('updateSubtitle').textContent =
    `Version ${update.version} ist verfügbar – du benutzt ${updateState.currentVersion}.`
  $('updateNotes').textContent = (update.notes || '').trim() || 'Keine Versionshinweise angegeben.'

  const error = $('updateInstallError')
  error.hidden = !updateState.error
  error.textContent = updateState.error || ''

  const installing = Boolean(updateState.installing)
  $('updateLater').disabled = installing
  $('updateInstall').hidden = installing
  $('updateProgress').hidden = !installing

  if (!installing) return

  const percent = typeof updateState.progress === 'number'
    ? Math.round(updateState.progress * 100)
    : 100
  $('updateProgressBar').style.width = `${percent}%`
  $('updateProgressText').textContent = percent < 100
    ? `Wird geladen … ${percent} %`
    : 'Wird installiert…'
}

async function runUpdate(promise) {
  try {
    const next = await promise
    if (next) applyUpdateState(next)
  } catch (error) {
    console.error('Update-Aktion fehlgeschlagen:', error)
    toast('Update-Aktion fehlgeschlagen')
  }
}

// ------------------------------------------------------------------ Helfer

async function run(promise) {
  try {
    const payload = await promise
    if (payload) applyState(payload)
  } catch (error) {
    console.error('Aktion fehlgeschlagen:', error)
    toast('Aktion fehlgeschlagen')
  }
}

function toast(message) {
  const element = $('toast')
  if (!element) return
  element.textContent = message
  element.hidden = false
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => {
    element.hidden = true
  }, 2800)
}

function parseDecimal(text) {
  let cleaned = String(text).trim().replace(/\s/g, '')
  if (cleaned === '') return null
  if (cleaned.includes(',')) {
    cleaned = cleaned.replace(/\./g, '').replace(',', '.')
  } else if (/^\d{1,3}(\.\d{3})+$/.test(cleaned)) {
    // Deutsche Tausendertrennung: 1.000 = eintausend.
    cleaned = cleaned.replace(/\./g, '')
  }
  const value = Number(cleaned)
  return Number.isFinite(value) ? value : null
}

function parseInteger(text) {
  const value = parseDecimal(text)
  if (value === null || !Number.isInteger(value)) return null
  return value
}

function formatInteger(value) {
  return Math.round(Number(value) || 0).toLocaleString('de-DE')
}

function formatDecimal(value) {
  if (!Number.isFinite(value)) return '—'
  return new Intl.NumberFormat('de-DE', { maximumFractionDigits: 3 }).format(value)
}

function formatCurrency(value) {
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(value)
}

function formatTime(timestamp) {
  return new Date(timestamp).toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' })
}

function formatDayLabel(day) {
  const date = new Date(`${day}T12:00:00`)
  if (Number.isNaN(date.getTime())) return day
  return date.toLocaleDateString('de-DE', { weekday: 'short', day: '2-digit', month: 'short' })
}

function formatShortDate(day) {
  return `${day.slice(8, 10)}.${day.slice(5, 7)}.`
}

function formatSavedDate(appleSeconds) {
  const date = new Date((Number(appleSeconds) + APPLE_EPOCH_OFFSET_SECONDS) * 1000)
  if (Number.isNaN(date.getTime())) return ''
  return date.toLocaleString('de-DE', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatDuration(seconds) {
  const total = Math.max(0, Math.round(seconds))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const remaining = total % 60

  if (hours > 0) return `${hours} Std. ${minutes} Min. ${remaining} Sek.`
  if (minutes > 0) return `${minutes} Min. ${remaining} Sek.`
  return `${remaining} Sek.`
}

// Beim Wechsel von Hell/Dunkel die Canvas-Farben nachziehen.
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
  if (activeTab === 'history') drawChart()
})

window.addEventListener('resize', () => {
  if (activeTab === 'history') drawChart()
})
