'use strict'

const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { EventEmitter } = require('node:events')

const { UpdateService } = require('../src/updater')

class FakeUpdater extends EventEmitter {
  constructor({ version = '3.2.0', notes = 'Neue Funktionen' } = {}) {
    super()
    this.info = { version, releaseNotes: notes }
    this.checkCalls = 0
    this.downloadCalls = 0
    this.installs = []
    this.autoDownload = true
    this.autoInstallOnAppQuit = true
  }

  async checkForUpdates() {
    this.checkCalls += 1
    this.emit('update-available', this.info)
    return { updateInfo: this.info }
  }

  async downloadUpdate() {
    this.downloadCalls += 1
    this.emit('download-progress', { percent: 40 })
    this.emit('update-downloaded', this.info)
  }

  quitAndInstall(isSilent, isForceRunAfter) {
    this.installs.push([isSilent, isForceRunAfter])
  }
}

function createFile() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-update-'))
  return path.join(dir, 'updates.json')
}

function createService({
  updater = new FakeUpdater(),
  filePath = createFile(),
  now = () => 1_000_000,
  isPackaged = true,
} = {}) {
  const service = new UpdateService({
    filePath,
    currentVersion: '3.1.0',
    isPackaged,
    updater,
    now,
  })
  return { service, updater, filePath }
}

test('meldet eine neuere Version und merkt sich die Prüfung', async () => {
  const { service, updater, filePath } = createService()

  const state = await service.check()

  assert.equal(updater.autoDownload, false)
  assert.equal(updater.autoInstallOnAppQuit, false)
  assert.equal(state.update.version, '3.2.0')
  assert.equal(state.update.notes, 'Neue Funktionen')
  assert.equal(state.checking, false)
  assert.equal(state.upToDate, false)
  assert.equal(state.error, null)

  const saved = JSON.parse(fs.readFileSync(filePath, 'utf8'))
  assert.equal(saved.lastCheck, 1_000_000)
})

test('prüft beim Start höchstens einmal pro Tag', async () => {
  let now = 1_000_000
  const { service, updater } = createService({ now: () => now })

  await service.checkIfNeeded()
  assert.equal(updater.checkCalls, 1)

  now += 60 * 60 * 1000
  await service.checkIfNeeded()
  assert.equal(updater.checkCalls, 1)

  now += 24 * 60 * 60 * 1000
  await service.checkIfNeeded()
  assert.equal(updater.checkCalls, 2)
})

test('lässt sich die automatische Prüfung abschalten und merkt sie sich', async () => {
  const filePath = createFile()
  const first = createService({ filePath })

  first.service.setAutomatic(false)
  assert.equal(first.service.state().automaticChecks, false)

  await first.service.checkIfNeeded()
  assert.equal(first.updater.checkCalls, 0)

  const second = createService({ filePath })
  assert.equal(second.service.state().automaticChecks, false)
})

test('installiert das geladene Update und startet die App neu', async () => {
  const { service, updater } = createService()

  await service.check()
  const state = await service.install()

  assert.equal(updater.downloadCalls, 1)
  assert.deepEqual(updater.installs, [[true, true]])
  assert.equal(state.installing, true)
  assert.equal(state.progress, null)
})

test('prüft im Entwicklungsmodus nicht und meldet den Grund', async () => {
  const { service, updater } = createService({ isPackaged: false })

  const state = await service.check()

  assert.equal(updater.checkCalls, 0)
  assert.match(state.error, /installierten App/)
})
