'use strict'

const net = require('node:net')
const os = require('node:os')
const { EventEmitter } = require('node:events')

const {
  decodeMessageLine,
  encodeMessage,
  isPeerBehind,
  shouldApply,
} = require('./protocol')

const SERVICE_TYPE = 'toolboxsync'
const BROADCAST_DELAY_MS = 400
const HEARTBEAT_MS = 20_000
const CONNECT_TIMEOUT_MS = 8_000
const MAX_BUFFER_BYTES = 2 * 1024 * 1024

/**
 * Abgleich im lokalen WLAN – kompatibel zur Apple-App (LocalSync.swift).
 *
 * Jedes Gerät öffnet einen TCP-Port, bietet ihn per Bonjour als
 * `_toolboxsync._tcp` an und sucht gleichzeitig nach anderen Geräten.
 * Beim Verbindungsaufbau schicken beide Seiten ihren vollständigen Stand;
 * pro Bereich gewinnt der zuletzt geänderte Stand. Übernommene Stände werden
 * an die übrigen Verbindungen weitergegeben – so erreichen Änderungen auch
 * ein drittes Gerät, das mit dem Ursprung nicht direkt verbunden ist.
 */
class SyncService extends EventEmitter {
  constructor({
    store,
    deviceName = os.hostname(),
    logger = console,
    discovery = true,
    port = 0,
    now = () => Date.now(),
  }) {
    super()
    this.store = store
    this.deviceName = String(deviceName || 'Windows-PC').slice(0, 120)
    this.logger = logger
    this.discoveryEnabled = discovery
    this.port = port
    this.now = now

    this.running = false
    this.listening = false
    this.isSearching = false
    this.server = null
    this.bonjour = null
    this.browser = null
    this.service = null
    this.discoveryError = null

    this.connections = new Map()
    this.endpoints = new Set()
    this.knownServices = new Map()
    this.peers = []
    this.lastSync = null
    this.connectionCounter = 0

    this.heartbeatTimer = null
    this.broadcastTimer = null
    this.serverRetryTimer = null
    this.discoveryRetryTimer = null
    this.networkSignature = this.networkFingerprint()
    this.heartbeatTicks = 0
    this.storeListener = null
    this.lastStatusSignature = ''
  }

  // MARK: - Steuerung

  start() {
    if (this.running) return
    if (!this.store.syncEnabled) {
      this.emitStatus()
      return
    }

    this.running = true
    this.startServer()
    if (this.discoveryEnabled) this.startDiscovery()
    this.startHeartbeat()
    this.subscribeStore()
    this.emitStatus()
  }

  stop() {
    this.running = false
    this.listening = false
    this.isSearching = false
    this.unsubscribeStore()

    clearInterval(this.heartbeatTimer)
    this.heartbeatTimer = null
    clearTimeout(this.broadcastTimer)
    this.broadcastTimer = null
    clearTimeout(this.serverRetryTimer)
    this.serverRetryTimer = null
    clearTimeout(this.discoveryRetryTimer)
    this.discoveryRetryTimer = null

    for (const id of [...this.connections.keys()]) this.drop(id)
    this.endpoints.clear()
    this.knownServices.clear()
    this.peers = []

    this.stopDiscovery()

    if (this.server) {
      try {
        this.server.close()
      } catch {
        // Server war bereits geschlossen.
      }
      this.server = null
    }

    this.emitStatus()
  }

  setEnabled(enabled) {
    const value = Boolean(enabled)
    this.store.setSyncEnabled(value)
    if (value) {
      this.start()
      this.syncNow()
    } else {
      this.stop()
    }
    this.emitStatus()
  }

  /** Sucht erneut nach Geräten und schickt den aktuellen Stand an alle. */
  syncNow() {
    if (!this.store.syncEnabled) return
    this.start()
    this.refreshDiscoveryIfNetworkChanged()

    if (this.browser) {
      try {
        this.browser.update()
      } catch {
        // Browser wurde gerade ersetzt.
      }
    }

    if (this.bonjour && !this.service && this.listening) this.publish()

    for (const service of [...this.knownServices.values()]) {
      this.connectToService(service)
    }
    this.broadcast()
  }

  /** Nach dem Aufwachen aus dem Standby / bei Netzwerkwechsel. */
  handleNetworkChange() {
    this.refreshDiscoveryIfNetworkChanged(true)
    this.syncNow()
  }

  get peerCount() {
    return this.peers.length
  }

  getStatus() {
    return {
      enabled: this.store.syncEnabled,
      running: this.running,
      isSearching: this.isSearching,
      peerCount: this.peers.length,
      peers: this.peers.map(peer => ({ ...peer })),
      lastSync: this.lastSync,
      deviceName: this.deviceName,
      discoveryError: this.discoveryError,
    }
  }

  emitStatus() {
    const status = this.getStatus()
    const signature = JSON.stringify(status)
    if (signature === this.lastStatusSignature) return
    this.lastStatusSignature = signature
    this.emit('status', status)
  }

  subscribeStore() {
    if (this.storeListener) return
    this.storeListener = () => this.scheduleBroadcast()
    this.store.on('changed', this.storeListener)
  }

  unsubscribeStore() {
    if (!this.storeListener) return
    this.store.removeListener('changed', this.storeListener)
    this.storeListener = null
  }

  // MARK: - TCP-Server

  startServer() {
    if (this.server) return

    const server = net.createServer(socket => this.accept(socket))
    this.server = server

    server.on('error', error => {
      this.discoveryError = `Netzwerk-Port: ${error.message}`
      this.emitStatus()
      try {
        server.close()
      } catch {
        // Ignorieren.
      }
      this.server = null
      this.listening = false
      this.serverRetryTimer = setTimeout(() => {
        this.serverRetryTimer = null
        if (this.running) this.startServer()
      }, 3000)
    })

    server.listen(this.port, '0.0.0.0', () => {
      this.port = server.address().port
      this.listening = true
      this.discoveryError = null
      if (this.discoveryEnabled && this.running) this.publish()
      this.emitStatus()
    })
  }

  accept(socket) {
    this.attach(socket, { endpoint: null, outgoing: false })
  }

  attach(socket, { endpoint, outgoing }) {
    const id = ++this.connectionCounter
    const conn = {
      id,
      socket,
      endpoint,
      outgoing,
      buffer: '',
      peerId: null,
      peerName: null,
      connected: !outgoing,
    }
    this.connections.set(id, conn)

    socket.setEncoding('utf8')
    socket.setNoDelay(true)
    socket.setKeepAlive(true, 15_000)

    let connectTimer = null
    if (outgoing) {
      this.endpoints.add(endpoint)
      connectTimer = setTimeout(() => {
        if (!conn.connected) socket.destroy()
      }, CONNECT_TIMEOUT_MS)
    }

    socket.on('connect', () => {
      conn.connected = true
      clearTimeout(connectTimer)
      connectTimer = null
    })
    socket.on('data', chunk => this.onData(conn, chunk))
    socket.on('error', () => this.drop(id))
    socket.on('close', () => {
      clearTimeout(connectTimer)
      this.drop(id)
    })

    // Beide Seiten schicken ihren Stand sofort nach dem Verbinden.
    this.sendState(conn)
    return conn
  }

  drop(id) {
    const conn = this.connections.get(id)
    if (!conn) return
    this.connections.delete(id)
    if (conn.endpoint) this.endpoints.delete(conn.endpoint)
    try {
      conn.socket.destroy()
    } catch {
      // Socket war bereits geschlossen.
    }
    this.updatePeers()
  }

  onData(conn, chunk) {
    if (!this.connections.has(conn.id)) return
    conn.buffer += chunk
    if (conn.buffer.length > MAX_BUFFER_BYTES) {
      this.drop(conn.id)
      return
    }

    let newline
    while ((newline = conn.buffer.indexOf('\n')) !== -1) {
      const line = conn.buffer.slice(0, newline)
      conn.buffer = conn.buffer.slice(newline + 1)
      this.handleLine(conn, line)
    }
  }

  // MARK: - Abgleich

  sendState(conn) {
    if (!conn || !this.connections.has(conn.id)) return
    if (!conn.socket.writable) return

    const payload = encodeMessage({
      deviceID: this.store.deviceId,
      deviceName: this.deviceName,
      water: this.store.waterSnapshot(),
      counter: this.store.counterSnapshot(),
    })

    try {
      conn.socket.write(payload)
    } catch {
      this.drop(conn.id)
    }
  }

  handleLine(conn, line) {
    const message = decodeMessageLine(line)
    if (!message) return

    // Eigene Ankündigung über den eigenen Listener ignorieren.
    if (message.deviceID === this.store.deviceId) {
      this.drop(conn.id)
      return
    }

    conn.peerId = message.deviceID
    conn.peerName = message.deviceName
    this.updatePeers()

    let applied = false
    let peerIsBehind = false

    if (message.water) {
      const local = this.store.waterUpdatedAt()
      if (shouldApply(local, message.water.updatedAt)) {
        this.store.applyRemoteWater(message.water)
        applied = true
      } else if (isPeerBehind(local, message.water.updatedAt)) {
        peerIsBehind = true
      }
    }

    if (message.counter) {
      const local = this.store.counterUpdatedAt()
      if (shouldApply(local, message.counter.updatedAt)) {
        this.store.applyRemoteCounter(message.counter)
        applied = true
      } else if (isPeerBehind(local, message.counter.updatedAt)) {
        peerIsBehind = true
      }
    }

    if (applied) {
      this.lastSync = this.now()
      this.emitStatus()
      // An die anderen Geräte weiterreichen, damit auch sie den neuen Stand
      // bekommen, wenn sie mit dem Ursprung nicht direkt verbunden sind.
      this.broadcast(conn.id)
    }

    if (peerIsBehind) this.sendState(conn)
  }

  broadcast(excludingId = null) {
    if (!this.store.syncEnabled) return
    for (const conn of this.connections.values()) {
      if (conn.id === excludingId) continue
      this.sendState(conn)
    }
  }

  scheduleBroadcast() {
    if (!this.store.syncEnabled) return
    if (this.broadcastTimer) return
    this.broadcastTimer = setTimeout(() => {
      this.broadcastTimer = null
      this.broadcast()
    }, BROADCAST_DELAY_MS)
  }

  updatePeers() {
    const peers = new Map()
    for (const conn of this.connections.values()) {
      if (!conn.peerId) continue
      peers.set(conn.peerId, conn.peerName || 'Gerät')
    }
    this.peers = [...peers.entries()].map(([id, name]) => ({ id, name }))
    this.emitStatus()
  }

  startHeartbeat() {
    if (this.heartbeatTimer) return
    this.heartbeatTimer = setInterval(() => {
      this.heartbeatTicks += 1
      // Vollständiger Stand als Lebenszeichen und Nachzügler-Abgleich.
      this.broadcast()
      if (this.browser && this.heartbeatTicks % 3 === 0) {
        try {
          this.browser.update()
        } catch {
          // Ignorieren, der nächste Heartbeat sucht erneut.
        }
      }
      if (this.heartbeatTicks % 3 === 0) {
        this.refreshDiscoveryIfNetworkChanged()
        if (this.bonjour && !this.service && this.listening) this.publish()
      }
    }, HEARTBEAT_MS)
  }

  // MARK: - Bonjour

  startDiscovery() {
    if (!this.discoveryEnabled || !this.running || this.bonjour) return

    try {
      const { Bonjour } = require('bonjour-service')
      this.bonjour = new Bonjour({}, error => {
        this.discoveryError = `Bonjour: ${error.message}`
        this.emitStatus()
      })
    } catch (error) {
      this.discoveryError = `Bonjour konnte nicht gestartet werden: ${error.message}`
      this.emitStatus()
      return
    }

    this.networkSignature = this.networkFingerprint()

    try {
      this.browser = this.bonjour.find({ type: SERVICE_TYPE, protocol: 'tcp' })
      this.browser.on('up', service => this.onServiceUp(service))
      this.browser.on('srv-update', service => this.onServiceUp(service))
      this.isSearching = true
    } catch (error) {
      this.discoveryError = `Suche im WLAN fehlgeschlagen: ${error.message}`
      this.isSearching = false
    }

    if (this.listening) this.publish()
    this.emitStatus()
  }

  publish() {
    if (!this.bonjour || this.service || !this.listening) return

    try {
      this.service = this.bonjour.publish({
        name: this.serviceName(),
        type: SERVICE_TYPE,
        protocol: 'tcp',
        port: this.port,
        host: this.mdnsHost(),
        txt: { id: this.store.deviceId },
        disableIPv6: true,
        // Der Name gehört zu genau diesem Rechner; das erspart die 750-ms-Probe
        // und verhindert, dass ein veralteter Eintrag das Veröffentlichen blockiert.
        probe: false,
      })

      this.service.on('error', error => {
        this.discoveryError = `Ankündigung im WLAN: ${error.message}`
        this.emitStatus()
      })
      this.service.on('up', () => {
        this.discoveryError = null
        this.emitStatus()
      })
    } catch (error) {
      this.discoveryError = `Ankündigung im WLAN fehlgeschlagen: ${error.message}`
      this.service = null
      this.emitStatus()
    }
  }

  stopDiscovery() {
    this.isSearching = false
    this.service = null

    if (this.browser) {
      try {
        this.browser.stop()
      } catch {
        // Browser war bereits gestoppt.
      }
      this.browser = null
    }

    const bonjour = this.bonjour
    this.bonjour = null
    if (!bonjour) return

    try {
      bonjour.unpublishAll(() => {
        try {
          bonjour.destroy()
        } catch {
          // Socket war bereits zu.
        }
      })
    } catch {
      try {
        bonjour.destroy()
      } catch {
        // Ignorieren.
      }
    }
  }

  onServiceUp(service) {
    if (!service || !service.port) return

    const announcedId = service.txt && service.txt.id
    if (typeof announcedId === 'string' && announcedId === this.store.deviceId) return

    const key = service.fqdn || `${service.name}:${service.port}`
    this.knownServices.set(key, service)
    this.connectToService(service)
  }

  connectToService(service) {
    if (!this.store.syncEnabled || !this.running) return
    const address = this.pickAddress(service)
    if (!address) return
    this.connectTo(address, service.port)
  }

  /** Bevorzugt eine Adresse aus dem eigenen Subnetz (statt VPN-/VM-Adaptern). */
  pickAddress(service) {
    const candidates = []
    if (Array.isArray(service.addresses)) {
      for (const address of service.addresses) {
        if (net.isIPv4(address)) candidates.push(address)
      }
    }
    if (service.referer && net.isIPv4(service.referer.address)) {
      candidates.push(service.referer.address)
    }
    if (candidates.length === 0) return null

    const locals = this.localIPv4Addresses()
    const score = address => {
      if (address.startsWith('169.254.')) return 3
      const prefix = address.split('.').slice(0, 3).join('.')
      return locals.some(local => local.split('.').slice(0, 3).join('.') === prefix) ? 0 : 1
    }

    candidates.sort((a, b) => score(a) - score(b))
    return candidates[0]
  }

  connectTo(host, port) {
    if (!host || !Number.isInteger(port) || port <= 0 || port > 65535) return
    const key = `${host}:${port}`
    if (this.endpoints.has(key)) return
    if (this.connections.size >= 16) return

    try {
      const socket = net.createConnection({ host, port })
      this.attach(socket, { endpoint: key, outgoing: true })
    } catch {
      this.endpoints.delete(key)
    }
  }

  // MARK: - Netzwerkwechsel

  localIPv4Addresses() {
    const addresses = []
    const interfaces = os.networkInterfaces()
    for (const entries of Object.values(interfaces)) {
      for (const entry of entries || []) {
        if (entry.family === 'IPv4' && !entry.internal) addresses.push(entry.address)
      }
    }
    return addresses
  }

  networkFingerprint() {
    return this.localIPv4Addresses().sort().join('|')
  }

  refreshDiscoveryIfNetworkChanged(force = false) {
    if (!this.discoveryEnabled || !this.running) return
    const signature = this.networkFingerprint()
    if (!force && signature === this.networkSignature) return
    this.networkSignature = signature

    // Alte Verbindungen gehören meist zum alten Netz – verwerfen und neu suchen.
    for (const id of [...this.connections.keys()]) this.drop(id)
    this.knownServices.clear()

    if (!this.bonjour) {
      this.startDiscovery()
      return
    }

    // Neu veröffentlichen, damit die A-Records die aktuelle IP enthalten.
    // Der Bonjour-Socket bleibt bestehen; nur die Records werden ersetzt.
    if (this.service) {
      try {
        this.service.stop()
      } catch {
        // Dienst war bereits abgemeldet.
      }
      this.service = null
    }
    if (this.listening) this.publish()
    if (this.browser) {
      try {
        this.browser.update()
      } catch {
        // Der nächste Heartbeat sucht erneut.
      }
    }
    this.emitStatus()
  }

  // MARK: - Namen

  serviceName() {
    const name = this.deviceName.replace(/\s+/g, ' ').trim() || os.hostname()
    return `Toolbox (${name})`.slice(0, 60)
  }

  /** Bonjour-service hängt kein `.local` an; der Zielname muss vollständig sein. */
  mdnsHost() {
    const base = this.deviceName
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 28) || 'toolbox'
    const suffix = this.store.deviceId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 6) || 'windows'
    return `toolbox-${base}-${suffix}.local`.slice(0, 63)
  }
}

module.exports = { SyncService, SERVICE_TYPE }
