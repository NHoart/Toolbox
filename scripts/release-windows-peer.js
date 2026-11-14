'use strict'

// Test-Runner für den Windows-Release-Client.
//
// Er lädt Store und SyncService aus dem app.asar des veröffentlichten
// Toolbox-Setup.exe und stellt sie über stdin/stdout bereit. Damit lässt sich
// der echte Windows-Sync-Code auf einem Mac als Peer starten, ohne die
// Windows-Electron-Oberfläche zu benötigen.

const path = require('node:path')
const readline = require('node:readline')

const asarRoot = process.argv[2]
const dataFile = process.argv[3]

if (!asarRoot || !dataFile) {
  console.error('Aufruf: release-windows-peer.js <app.asar-Ordner> <data.json>')
  process.exit(2)
}

const { ToolboxStore } = require(path.join(asarRoot, 'src/store.js'))
const { SyncService } = require(path.join(asarRoot, 'src/sync.js'))

const store = new ToolboxStore({ filePath: dataFile })
const sync = new SyncService({
  store,
  deviceName: 'Windows-Release-3.1.0',
  discovery: true,
})

function emit(prefix, value) {
  process.stdout.write(`${prefix} ${JSON.stringify(value)}\n`)
}

function status() {
  return { ...sync.getStatus(), ...syncSnapshot() }
}

function syncSnapshot() {
  return {
    water: store.waterSnapshot(),
    counter: store.counterSnapshot(),
  }
}

sync.on('status', () => {
  emit('STATUS', sync.getStatus())
})

sync.start()
emit('READY', { port: sync.port })

const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity })

rl.on('line', line => {
  const [command, ...rest] = line.trim().split(/\s+/)
  const text = rest.join(' ')

  switch (command) {
    case 'addwater': {
      const amount = Number(text)
      if (Number.isFinite(amount)) store.addWater(amount)
      break
    }
    case 'increment':
      store.increment()
      break
    case 'setsizes': {
      const [glass, bottle, goal] = text.split(/\s+/).map(Number)
      if ([glass, bottle, goal].every(Number.isFinite)) store.setSizes({ glass, bottle, goal })
      break
    }
    case 'savecounter':
      store.saveCounter(text || 'Release-Stand')
      break
    case 'status':
      emit('STATUS', sync.getStatus())
      break
    case 'snapshot':
      emit('SNAPSHOT', status())
      break
    case 'quit':
      process.exit(0)
      break
    default:
      break
  }
})

process.on('SIGTERM', () => {
  sync.stop()
  store.dispose()
  process.exit(0)
})
