'use strict'

// Diagnose: verbindet sich mit der ersten gefundenen Toolbox-App und zeigt
// nur die Struktur der Sync-Nachricht (keine Mengen oder Namen von Ständen).
//   node scripts/inspect-peer.js

const net = require('node:net')
const { Bonjour } = require('bonjour-service')

const bonjour = new Bonjour({}, error => {
  console.error('Bonjour-Fehler:', error.message)
  process.exit(1)
})

const browser = bonjour.find({ type: 'toolboxsync', protocol: 'tcp' })
let connected = false

browser.on('up', service => {
  if (connected) return
  const address = (service.addresses || []).find(candidate => net.isIPv4(candidate))
    || (service.referer && net.isIPv4(service.referer.address) ? service.referer.address : null)
  if (!address) return

  connected = true
  const socket = net.createConnection({ host: address, port: service.port })
  socket.setEncoding('utf8')
  let buffer = ''

  const finish = code => {
    try { socket.destroy() } catch { /* egal */ }
    try { bonjour.destroy() } catch { /* egal */ }
    setTimeout(() => process.exit(code), 150)
  }

  socket.on('data', chunk => {
    buffer += chunk
    let newline
    while ((newline = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, newline)
      buffer = buffer.slice(newline + 1)

      let message
      try {
        message = JSON.parse(line)
      } catch (error) {
        console.log(JSON.stringify({ error: `JSON: ${error.message}` }))
        finish(2)
        return
      }

      const water = message.water
      const counter = message.counter
      console.log(JSON.stringify({
        serviceHost: service.host,
        hasWater: Boolean(water),
        historyType: water ? typeof water.history : null,
        historyKeys: water && water.history && typeof water.history === 'object'
          ? Object.keys(water.history).length
          : null,
        historySampleKeys: water && water.history && typeof water.history === 'object'
          ? Object.keys(water.history).slice(0, 2)
          : [],
        day: water ? water.day : null,
        recentAdds: water && Array.isArray(water.recentAdds) ? water.recentAdds.length : null,
        updatedAtType: water ? typeof water.updatedAt : null,
        totalPositive: water && typeof water.total === 'number' ? water.total > 0 : null,
        goal: water ? water.goal : null,
        hasCounter: Boolean(counter),
        counterPositive: counter && typeof counter.count === 'number' ? counter.count > 0 : null,
        savedCounters: counter && Array.isArray(counter.savedCounters) ? counter.savedCounters.length : null,
        counterUpdatedAtType: counter ? typeof counter.updatedAt : null,
      }, null, 2))
      finish(0)
      return
    }
  })

  socket.on('error', error => {
    console.log(JSON.stringify({ error: error.message }))
    finish(1)
  })

  setTimeout(() => {
    console.log(JSON.stringify({ error: 'keine Nachricht erhalten' }))
    finish(1)
  }, 8000)
})

setTimeout(() => {
  if (!connected) {
    console.log(JSON.stringify({ error: 'kein Gerät gefunden' }))
    process.exit(3)
  }
}, 12_000)
