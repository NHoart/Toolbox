'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { SyncService } = require('../src/sync')

const silentLogger = { log() {}, warn() {}, error() {} }

function createNode(name, clock) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-smoke-'))
  const store = new ToolboxStore({
    filePath: path.join(directory, 'data.json'),
    now: () => clock.value,
  })
  const sync = new SyncService({
    store,
    deviceName: name,
    discovery: false,
    logger: silentLogger,
    now: () => clock.value,
  })
  return { directory, store, sync }
}

async function waitFor(predicate, message, timeout = 10_000) {
  const started = Date.now()
  while (Date.now() - started < timeout) {
    if (predicate()) return
    await new Promise(resolve => setTimeout(resolve, 20))
  }
  throw new Error(`Zeitüberschreitung: ${message}`)
}

async function main() {
  const base = Date.now()
  const clockMac = { value: base }
  const clockWindows = { value: base + 60_000 }
  const nodes = []

  const mac = createNode('Mac', clockMac)
  const windows = createNode('Windows-PC', clockWindows)
  nodes.push(mac, windows)

  try {
    mac.store.addWater(500)
    mac.store.increment()

    mac.sync.start()
    windows.sync.start()
    await waitFor(
      () => mac.sync.listening && windows.sync.listening,
      'die Sync-Server sollten lauschen'
    )
    windows.sync.connectTo('127.0.0.1', mac.sync.port)

    await waitFor(
      () => windows.store.todayML() === 500
        && windows.store.count === 1
        && windows.store.waterUpdatedAt() === mac.store.waterUpdatedAt(),
      'Windows sollte den Mac-Stand übernehmen'
    )

    windows.store.addWater(250)
    windows.store.increment()

    await waitFor(
      () => mac.store.todayML() === 750
        && mac.store.count === 2
        && mac.store.waterUpdatedAt() === windows.store.waterUpdatedAt(),
      'der Mac sollte die Windows-Änderung übernehmen'
    )

    assert.deepEqual(mac.store.waterSnapshot(), windows.store.waterSnapshot())
    assert.deepEqual(mac.store.counterSnapshot(), windows.store.counterSnapshot())
    console.log('Sync-Smoke-Test erfolgreich: Mac und Windows teilen 750 ml und Zählerstand 2.')
  } finally {
    for (const node of nodes) {
      node.sync.stop()
      node.store.dispose()
      fs.rmSync(node.directory, { recursive: true, force: true })
    }
  }
}

main().catch(error => {
  console.error('Sync-Smoke-Test fehlgeschlagen:', error)
  process.exitCode = 1
})
