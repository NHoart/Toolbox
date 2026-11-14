'use strict'

// Manueller Test gegen eine echte Toolbox-App (Mac/iPhone) im selben WLAN:
//   node test/manual-mdns.js [Sekunden]
//
// Startet einen Windows-Abgleich mit leerem Stand, sucht per Bonjour nach
// Geräten und meldet, ob eine Verbindung zustande kommt und Daten ankommen.
// Es werden keine Inhalte ausgegeben, nur ob Wasser/Zähler empfangen wurden.

const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const { ToolboxStore } = require('../src/store')
const { SyncService } = require('../src/sync')

const seconds = Number(process.argv[2] || 20)
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'toolbox-mdns-'))
const store = new ToolboxStore({ filePath: path.join(directory, 'data.json') })
// Muss mit dem Namen im Feld „Lokales Netzwerk“ der echten App übereinstimmen.
store.setSyncName(process.env.TOOLBOX_SYNC_NAME || 'Familie')
const sync = new SyncService({
  store,
  deviceName: `Windows-Test (${os.hostname()})`,
})

let receivedWater = false
let receivedCounter = false

// Mit --incoming-only wird nur gelauscht. Kommt trotzdem eine Verbindung
// zustande, hat die Apple-App die Windows-Ankündigung per Bonjour gefunden.
if (process.argv.includes('--incoming-only')) {
  sync.connectTo = () => {}
}

sync.on('status', status => {
  const connections = [...sync.connections.values()]
  console.log('STATUS', JSON.stringify({
    peerCount: status.peerCount,
    peers: status.peers.map(peer => peer.name),
    searching: status.isSearching,
    incoming: connections.filter(connection => !connection.outgoing).length,
    outgoing: connections.filter(connection => connection.outgoing).length,
    error: status.discoveryError,
  }))
})

store.on('remote', section => {
  if (section === 'water') receivedWater = true
  if (section === 'counter') receivedCounter = true
  console.log('REMOTE', section)
})

sync.start()

setTimeout(() => {
  const status = sync.getStatus()
  const result = {
    peerCount: status.peerCount,
    peers: status.peers.map(peer => peer.name),
    receivedWater,
    receivedCounter,
    discoveryError: status.discoveryError,
  }
  console.log('RESULT', JSON.stringify(result))

  sync.stop()
  store.dispose()
  fs.rmSync(directory, { recursive: true, force: true })
  setTimeout(() => process.exit(status.peerCount > 0 ? 0 : 2), 250)
}, seconds * 1000)
