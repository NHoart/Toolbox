'use strict'

const fs = require('node:fs')
const path = require('node:path')
const { EventEmitter } = require('node:events')

const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000

/// Checks GitHub once a day for a newer version and installs it
/// on request. electron-updater does the actual work; this
/// service keeps status, settings and the messages together.
class UpdateService extends EventEmitter {
  constructor({ filePath, currentVersion, isPackaged = false, storeManaged = false, updater = null, now = () => Date.now() } = {}) {
    super()
    this.filePath = filePath
    this.currentVersion = currentVersion || '0'
    this.isPackaged = Boolean(isPackaged)
    this.storeManaged = Boolean(storeManaged)
    this.now = now
    this.checking = false
    this.installing = false
    this.progress = null
    this.update = null
    this.upToDate = false
    this.error = null
    this.announceErrors = false
    this.settings = this.loadSettings()

    // In development there is no app-update.yml and therefore no feed;
    // it is not checked there at all. The updater can be
    // injected for tests without loading electron-updater. In the Store build
    // the Microsoft Store updates the app; electron-updater stays off.
    this.updater = this.storeManaged
      ? null
      : updater || require('electron-updater').autoUpdater
    if (this.updater) {
      this.updater.autoDownload = false
      this.updater.autoInstallOnAppQuit = false
      this.bindUpdater()
    }
  }

  // MARK: - Persistenz

  loadSettings() {
    try {
      const raw = JSON.parse(fs.readFileSync(this.filePath, 'utf8'))
      return {
        automaticChecks: raw.automaticChecks !== false,
        lastCheck: Number.isFinite(raw.lastCheck) ? raw.lastCheck : 0,
      }
    } catch {
      return { automaticChecks: true, lastCheck: 0 }
    }
  }

  saveSettings() {
    try {
      fs.mkdirSync(path.dirname(this.filePath), { recursive: true })
      fs.writeFileSync(this.filePath, JSON.stringify(this.settings, null, 2))
    } catch {
      // The settings are not critical; on the next start
      // the default values apply again.
    }
  }

  // MARK: - Status

  state() {
    return {
      currentVersion: this.currentVersion,
      automaticChecks: this.settings.automaticChecks,
      checking: this.checking,
      installing: this.installing,
      progress: this.progress,
      update: this.update,
      upToDate: this.upToDate,
      error: this.error,
      canInstall: this.isPackaged && !this.storeManaged,
      storeManaged: this.storeManaged,
    }
  }

  emitChange() {
    this.emit('changed', this.state())
  }

  setAutomatic(enabled) {
    if (this.storeManaged) return this.state()

    this.settings.automaticChecks = Boolean(enabled)
    this.saveSettings()
    this.emitChange()
    return this.state()
  }

  // MARK: - Checking

  /// Checks at launch, but at most once per day and without an error message.
  async checkIfNeeded() {
    if (this.storeManaged || !this.isPackaged || !this.settings.automaticChecks) return this.state()
    if (this.settings.lastCheck > 0 && this.now() - this.settings.lastCheck < CHECK_INTERVAL_MS) {
      return this.state()
    }
    return this.check({ manual: false })
  }

  async check({ manual = true } = {}) {
    if (this.storeManaged || this.checking || this.installing) return this.state()

    if (!this.isPackaged) {
      if (manual) {
        this.announceErrors = true
        this.error = 'Die Update-Prüfung ist nur in der installierten App verfügbar.'
        this.emitChange()
      }
      return this.state()
    }

    this.announceErrors = manual
    this.checking = true
    this.upToDate = false
    this.error = null
    this.emitChange()

    try {
      await this.updater.checkForUpdates()
    } catch (error) {
      // The error event may already have reset the state.
      if (this.checking) this.fail(error)
    }

    this.checking = false
    this.emitChange()
    return this.state()
  }

  // MARK: - Installieren

  /// Downloads the found update and restarts the app with it.
  async install() {
    if (this.storeManaged || !this.update || this.installing) return this.state()

    if (!this.isPackaged) {
      this.announceErrors = true
      this.error = 'Das Update kann nur in der installierten App installiert werden.'
      this.emitChange()
      return this.state()
    }

    this.announceErrors = true
    this.installing = true
    this.progress = 0
    this.error = null
    this.emitChange()

    try {
      await this.updater.downloadUpdate()
    } catch (error) {
      // The error event may already have reset the state.
      if (this.installing) this.fail(error)
    }

    return this.state()
  }

  // MARK: - electron-updater

  bindUpdater() {
    this.updater.on('update-available', info => {
      this.checking = false
      this.upToDate = false
      this.error = null
      this.update = {
        version: String(info?.version || ''),
        notes: releaseNotes(info?.releaseNotes),
      }
      this.settings.lastCheck = this.now()
      this.saveSettings()
      this.emitChange()
    })

    this.updater.on('update-not-available', () => {
      this.checking = false
      this.upToDate = true
      this.update = null
      this.settings.lastCheck = this.now()
      this.saveSettings()
      this.emitChange()
    })

    this.updater.on('download-progress', info => {
      if (!this.installing) return
      const percent = Number(info?.percent)
      this.progress = Number.isFinite(percent)
        ? Math.min(1, Math.max(0, percent / 100))
        : null
      this.emitChange()
    })

    this.updater.on('update-downloaded', () => {
      this.progress = null
      this.emitChange()
      this.updater.quitAndInstall(true, true)
    })

    this.updater.on('error', error => this.fail(error))
  }

  fail(error) {
    const wasInstalling = this.installing
    this.checking = false
    this.installing = false
    this.progress = null

    if (this.announceErrors) {
      this.error = wasInstalling
        ? withDetail('Das Update konnte nicht installiert werden. Bitte später erneut versuchen.', error)
        : withDetail('Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.', error)
    }

    this.emitChange()
  }
}

function releaseNotes(value) {
  if (typeof value === 'string') return value
  if (!Array.isArray(value)) return ''

  return value
    .map(entry => (typeof entry === 'string' ? entry : entry && entry.note))
    .filter(note => typeof note === 'string' && note.trim() !== '')
    .join('\n\n')
}

function withDetail(prefix, error) {
  const detail = error instanceof Error
    ? error.message
    : typeof error === 'string' ? error : ''
  const trimmed = detail.trim()
  return trimmed ? `${prefix}\n\n${trimmed}` : prefix
}

module.exports = { UpdateService }
