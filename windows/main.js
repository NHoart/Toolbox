'use strict'

const path = require('node:path')
const os = require('node:os')
const { app, BrowserWindow, ipcMain, Menu, nativeTheme, powerMonitor } = require('electron')

const { ToolboxStore } = require('./src/store')
const { SyncService } = require('./src/sync')
const { UpdateService } = require('./src/updater')

app.setName('Toolbox')
if (process.platform === 'win32') {
  app.setAppUserModelId('com.noahsapps.Toolbox')
}

let mainWindow = null
let store = null
let sync = null
let updater = null
let notifyTimer = null
let dayRolloverTimer = null
let lastTickSent = 0

const gotSingleInstanceLock = app.requestSingleInstanceLock()
if (!gotSingleInstanceLock) {
  app.quit()
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return
    if (mainWindow.isMinimized()) mainWindow.restore()
    mainWindow.focus()
  })

  app.whenReady().then(bootstrap)
}

function bootstrap() {
  if (process.platform === 'win32') Menu.setApplicationMenu(null)

  const dataPath = path.join(app.getPath('userData'), 'data.json')
  store = new ToolboxStore({ filePath: dataPath })

  updater = new UpdateService({
    filePath: path.join(app.getPath('userData'), 'updates.json'),
    currentVersion: app.getVersion(),
    isPackaged: app.isPackaged,
  })
  updater.on('changed', () => sendUpdateState())

  sync = new SyncService({
    store,
    deviceName: os.hostname() || 'Windows-PC',
  })

  registerIpc()
  createWindow()

  store.on('changed', () => notifyState(false))
  store.on('remote', () => notifyState(true))
  store.on('tick', () => sendCounterTick())
  sync.on('status', () => notifyState(true))

  sync.start()
  scheduleDayRollover()

  // Höchstens einmal pro Tag; Fehler bleiben im Hintergrund.
  void updater.checkIfNeeded()

  powerMonitor.on('resume', () => sync.handleNetworkChange())
  powerMonitor.on('unlock-screen', () => sync.handleNetworkChange())
  nativeTheme.on('updated', applyTitleBarOverlay)

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
}

function createWindow() {
  const isWindows = process.platform === 'win32'

  mainWindow = new BrowserWindow({
    width: 1180,
    height: 780,
    minWidth: 1000,
    minHeight: 620,
    show: false,
    backgroundColor: nativeTheme.shouldUseDarkColors ? '#080b13' : '#eef1f8',
    autoHideMenuBar: true,
    title: 'Toolbox',
    titleBarStyle: isWindows ? 'hidden' : 'hiddenInset',
    titleBarOverlay: isWindows
      ? titleBarOverlayOptions()
      : undefined,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
      backgroundThrottling: false,
    },
  })

  mainWindow.once('ready-to-show', () => mainWindow.show())
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'))
  mainWindow.webContents.setWindowOpenHandler(() => ({ action: 'deny' }))
  mainWindow.webContents.on('will-navigate', event => event.preventDefault())
  mainWindow.on('closed', () => {
    mainWindow = null
  })
}

function titleBarOverlayOptions() {
  return nativeTheme.shouldUseDarkColors
    ? { color: '#080b13', symbolColor: '#d7deee', height: 44 }
    : { color: '#eef1f8', symbolColor: '#1c2333', height: 44 }
}

function applyTitleBarOverlay() {
  if (process.platform !== 'win32' || !mainWindow || mainWindow.isDestroyed()) return
  try {
    mainWindow.setTitleBarOverlay(titleBarOverlayOptions())
  } catch {
    // Overlay ist auf dieser Windows-Version nicht verfügbar.
  }
}

function statePayload() {
  return {
    ...store.getState(),
    sync: sync.getStatus(),
    version: app.getVersion(),
    platform: process.platform,
  }
}

function notifyState(immediate) {
  if (!mainWindow || mainWindow.isDestroyed()) return

  if (immediate) {
    clearTimeout(notifyTimer)
    notifyTimer = null
    mainWindow.webContents.send('state:changed')
    return
  }

  if (notifyTimer) return
  notifyTimer = setTimeout(() => {
    notifyTimer = null
    if (mainWindow && !mainWindow.isDestroyed()) mainWindow.webContents.send('state:changed')
  }, 60)
}

function sendUpdateState() {
  if (!mainWindow || mainWindow.isDestroyed()) return
  mainWindow.webContents.send('update:changed', updater.state())
}

function sendCounterTick() {
  if (!mainWindow || mainWindow.isDestroyed()) return
  const now = Date.now()
  if (now - lastTickSent < 30) return
  lastTickSent = now
  mainWindow.webContents.send('counter:tick', { count: store.count })
}

function scheduleDayRollover() {
  const now = new Date()
  const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 2)
  const delay = Math.max(1000, next.getTime() - now.getTime())

  clearTimeout(dayRolloverTimer)
  dayRolloverTimer = setTimeout(() => {
    // Der Tageszähler springt um Mitternacht zurück.
    notifyState(true)
    scheduleDayRollover()
  }, delay)
}

function registerIpc() {
  ipcMain.handle('app:state', () => statePayload())

  ipcMain.handle('water:add', (_event, ml) => {
    store.addWater(ml)
    return statePayload()
  })
  ipcMain.handle('water:undo', () => {
    store.undoWater()
    return statePayload()
  })
  ipcMain.handle('water:reset', () => {
    store.resetToday()
    return statePayload()
  })
  ipcMain.handle('water:set-sizes', (_event, sizes) => {
    store.setSizes(sizes && typeof sizes === 'object' ? sizes : {})
    return statePayload()
  })

  ipcMain.handle('counter:increment', () => {
    store.increment()
    return statePayload()
  })
  ipcMain.handle('counter:decrement', () => {
    store.decrement()
    return statePayload()
  })
  ipcMain.handle('counter:reset', () => {
    store.resetCounter()
    return statePayload()
  })
  ipcMain.handle('counter:undo', () => {
    store.undoCounter()
    return statePayload()
  })
  ipcMain.handle('counter:set-rate', (_event, rate) => {
    store.setRate(rate)
    return statePayload()
  })
  ipcMain.handle('counter:toggle-auto', () => {
    store.toggleAuto()
    return statePayload()
  })
  ipcMain.handle('counter:save', (_event, name) => {
    store.saveCounter(name)
    return statePayload()
  })
  ipcMain.handle('counter:load', (_event, id) => {
    store.loadCounter(id)
    return statePayload()
  })
  ipcMain.handle('counter:delete', (_event, id) => {
    store.deleteCounter(id)
    return statePayload()
  })

  ipcMain.handle('sync:set-enabled', (_event, enabled) => {
    sync.setEnabled(enabled)
    return statePayload()
  })
  ipcMain.handle('sync:sync-now', () => {
    sync.syncNow()
    return statePayload()
  })
  ipcMain.handle('sync:set-name', (_event, name) => {
    sync.setSyncName(name)
    return statePayload()
  })

  ipcMain.handle('update:state', () => updater.state())
  ipcMain.handle('update:check', () => updater.check({ manual: true }))
  ipcMain.handle('update:install', () => updater.install())
  ipcMain.handle('update:set-automatic', (_event, enabled) => updater.setAutomatic(enabled))
}

app.on('window-all-closed', () => {
  app.quit()
})

app.on('before-quit', () => {
  store?.flush()
})

app.on('will-quit', () => {
  clearTimeout(notifyTimer)
  clearTimeout(dayRolloverTimer)
  sync?.stop()
  store?.dispose()
})
