'use strict'

// Renders the Microsoft Store screenshots from the real Windows interface.
// Run from the windows directory:
//   node_modules/.bin/electron scripts/capture-store-screenshots.js
//
// The window is frameless and rendered at 2x, so the PNGs are 2464 x 1648 and
// contain no window chrome from the host operating system.

const { app, BrowserWindow, ipcMain } = require('electron')
const path = require('node:path')
const os = require('node:os')
const fs = require('node:fs')

const { ToolboxStore } = require('../src/store')
const { UpdateService } = require('../src/updater')

const VIEWPORT = { width: 2464, height: 1648 }
const LANGUAGES = ['de', 'en', 'es', 'fr']
const TABS = [
  { id: 'today', name: '01-today' },
  { id: 'history', name: '02-history' },
  { id: 'units', name: '03-units' },
  { id: 'counter', name: '04-counter' },
  { id: 'download', name: '05-download' },
  { id: 'energy', name: '06-energy' },
]

app.commandLine.appendSwitch('force-device-scale-factor', '1')
app.disableHardwareAcceleration()

const windowsRoot = path.join(__dirname, '..')
const outputRoot = path.join(windowsRoot, 'store', 'screenshots')
const version = require(path.join(windowsRoot, 'package.json')).version
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-screenshots-'))

app.setName('Toolbox')
app.setPath('userData', path.join(tempRoot, 'userData'))

let store
let updater

const wait = ms => new Promise(resolve => setTimeout(resolve, ms))

function syncStatus() {
  return {
    enabled: false,
    running: false,
    isSearching: false,
    peerCount: 0,
    peers: [],
    lastSync: null,
    deviceName: os.hostname() || 'Windows-PC',
    syncName: '',
    discoveryError: null,
  }
}

function statePayload() {
  return {
    ...store.getState(),
    sync: syncStatus(),
    version,
    platform: 'win32',
  }
}

function registerIpc() {
  ipcMain.handle('app:state', () => statePayload())
  ipcMain.handle('app:reload', () => undefined)
  ipcMain.handle('update:state', () => updater.state())
  ipcMain.handle('update:check', () => updater.state())
  ipcMain.handle('update:install', () => updater.state())
  ipcMain.handle('update:set-automatic', () => updater.state())

  const stateChannels = [
    'water:add',
    'water:undo',
    'water:reset',
    'water:set-sizes',
    'counter:increment',
    'counter:decrement',
    'counter:reset',
    'counter:undo',
    'counter:set-rate',
    'counter:toggle-auto',
    'counter:save',
    'counter:load',
    'counter:delete',
    'sync:set-enabled',
    'sync:sync-now',
    'sync:set-name',
  ]
  for (const channel of stateChannels) {
    ipcMain.handle(channel, () => statePayload())
  }
}

async function waitForPage(win) {
  await win.webContents.executeJavaScript(
    'document.fonts && document.fonts.ready ? document.fonts.ready.then(() => true) : true'
  )
  await wait(600)
}

async function capture(win) {
  for (const language of LANGUAGES) {
    await win.webContents.executeJavaScript(
      `localStorage.setItem('toolbox.locale', ${JSON.stringify(language)})`
    )

    const loaded = new Promise(resolve => win.webContents.once('did-finish-load', resolve))
    win.webContents.reload()
    await loaded
    await waitForPage(win)

    const directory = path.join(outputRoot, language)
    fs.mkdirSync(directory, { recursive: true })

    for (const tab of TABS) {
      await win.webContents.executeJavaScript(
        `document.querySelector('.nav-row[data-tab="${tab.id}"]').click()`
      )
      await wait(450)

      const image = await win.webContents.capturePage()
      const { width, height } = image.getSize()
      fs.writeFileSync(path.join(directory, `${language}-${tab.name}.png`), image.toPNG())
      console.log(`${language}/${tab.name}: ${width}x${height}`)
    }
  }
}

async function run() {
  store = new ToolboxStore({ filePath: path.join(tempRoot, 'data.json') })
  updater = new UpdateService({
    filePath: path.join(tempRoot, 'updates.json'),
    currentVersion: version,
    isPackaged: false,
    storeManaged: true,
  })

  registerIpc()

  const win = new BrowserWindow({
    width: VIEWPORT.width,
    height: VIEWPORT.height,
    useContentSize: true,
    frame: false,
    show: false,
    backgroundColor: '#080b13',
    webPreferences: {
      preload: path.join(windowsRoot, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      backgroundThrottling: false,
      offscreen: true,
      zoomFactor: 2,
    },
  })

  await win.loadFile(path.join(windowsRoot, 'renderer', 'index.html'))
  await waitForPage(win)
  await capture(win)

  win.destroy()
  store.dispose()
  fs.rmSync(tempRoot, { recursive: true, force: true })
  app.quit()
}

app.whenReady().then(run).catch(error => {
  console.error(error)
  app.exit(1)
})
