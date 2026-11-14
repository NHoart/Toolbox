'use strict'

// Beweist die Drei-Geräte-Kette mit den veröffentlichten 3.1.0-Artefakten:
// - macOS-App aus Toolbox.dmg (Release-Binary)
// - iOS-App aus dem v3.1.0-Tag im Simulator
// - Windows-Client (Store + SyncService) aus Toolbox-Setup.exe
//
// Die Apps werden über ihre isolierten Defaults-Suites gesteuert. Änderungen
// auf Mac und iPhone werden vor dem Relaunch in die Suite geschrieben; die
// Windows-Änderung läuft live über den extrahierten Release-Client. Damit werden
// echte App-/Sync-Prozesse und keine Dev-Harnesses geprüft.
//
// Voraussetzungen:
//   bash scripts/prepare-release-sync-test.sh
//   node scripts/test-release-sync-chain.js

const assert = require('node:assert/strict')
const { spawn, execFileSync } = require('node:child_process')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const readline = require('node:readline')

const ROOT = path.resolve(__dirname, '..')
const REL = path.resolve(process.env.TOOLBOX_RELEASE_TEST_DIR || path.join(ROOT, 'build/release-3.1.0'))
const MAC_APP = path.join(REL, 'Toolbox.app')
const IOS_APP = path.join(REL, 'ios-derived/Build/Products/Debug-iphonesimulator/Toolbox.app')
const WIN_ASAR = path.join(REL, 'win-asar')
const UDID = process.env.TOOLBOX_SIMULATOR_UDID || '65C65642-D348-4211-9F48-16183C5199C6'
const BUNDLE = 'com.noahsapps.Toolbox'
const PLIST_BUDDY = '/usr/libexec/PlistBuddy'
const APPLE_EPOCH = 978_307_200
const nonce = `${process.pid}-${Date.now()}`
const MAC_SUITE = `com.noahsapps.Toolbox.release-chain.mac.${nonce}`
const PHONE_SUITE = `com.noahsapps.Toolbox.release-chain.phone.${nonce}`
const WINDOWS_DATA = path.join(REL, 'run', `windows-${nonce}.json`)
const MAC_PLIST = path.join(REL, 'run', `mac-${nonce}.plist`)

let macProcess = null
let windowsPeer = null

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
const run = (command, args, options = {}) => execFileSync(command, args, { encoding: 'utf8', ...options })
const runQuiet = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'ignore'],
  ...options,
})
const escapeXml = value => String(value)
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&apos;')

function readPlist(file) {
  return runQuiet('plutil', ['-convert', 'xml1', '-o', '-', file])
}

function plistRaw(file, key) {
  try {
    return runQuiet('plutil', ['-extract', key, 'raw', '-o', '-', file]).trim()
  } catch {
    return null
  }
}

function plistJSON(file, key) {
  try {
    return JSON.parse(runQuiet('plutil', ['-extract', key, 'json', '-o', '-', file]))
  } catch {
    return null
  }
}

function plistData(file, key) {
  const raw = plistRaw(file, key)
  if (!raw) return null
  return Buffer.from(raw, 'base64').toString('utf8')
}

function plistDate(file, key) {
  const xml = readPlist(file)
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const match = new RegExp(`<key>${escaped}</key>\\s*<date>([^<]+)</date>`).exec(xml)
  if (!match) return null
  const ms = Date.parse(match[1])
  return Number.isFinite(ms) ? ms / 1000 - APPLE_EPOCH : null
}

function readSuite(file) {
  const saved = plistData(file, 'saved_counters')
  return {
    water: {
      total: Number(plistRaw(file, 'totalML')),
      history: plistJSON(file, 'historyML') || {},
      recentAdds: plistJSON(file, 'recentAddsML') || [],
      day: plistRaw(file, 'totalDay'),
      glass: Number(plistRaw(file, 'glassML')),
      bottle: Number(plistRaw(file, 'bottleML')),
      goal: Number(plistRaw(file, 'goalML')),
      updatedAt: plistDate(file, 'sync.water.updatedAt'),
    },
    counter: {
      count: Number(plistRaw(file, 'counter_value')),
      savedCounters: saved ? JSON.parse(saved) : [],
      rate: Number(plistRaw(file, 'counter_rate')),
      updatedAt: plistDate(file, 'sync.counter.updatedAt'),
    },
    lastSync: plistDate(file, 'lan_sync_lastSync'),
    device: plistRaw(file, 'lan_sync_device_id'),
  }
}

function suiteXml(state) {
  const savedData = Buffer.from(JSON.stringify(state.counter.savedCounters)).toString('base64')
  const history = Object.entries(state.water.history)
    .map(([day, value]) => `<key>${escapeXml(day)}</key><integer>${value}</integer>`)
    .join('')
  const recent = state.water.recentAdds.map(value => `<integer>${value}</integer>`).join('')
  const date = ms => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z')

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>lan_sync_enabled</key><true/>
  <key>glassML</key><integer>${state.water.glass}</integer>
  <key>bottleML</key><integer>${state.water.bottle}</integer>
  <key>goalML</key><integer>${state.water.goal}</integer>
  <key>totalML</key><integer>${state.water.total}</integer>
  <key>totalDay</key><string>${escapeXml(state.water.day)}</string>
  <key>historyML</key><dict>${history}</dict>
  <key>recentAddsML</key><array>${recent}</array>
  <key>sync.water.updatedAt</key><date>${date(state.water.updatedAt)}</date>
  <key>counter_value</key><integer>${state.counter.count}</integer>
  <key>counter_rate</key><integer>${state.counter.rate}</integer>
  <key>saved_counters</key><data>${savedData}</data>
  <key>sync.counter.updatedAt</key><date>${date(state.counter.updatedAt)}</date>
</dict>
</plist>
`
}

function writeSuiteFile(file, state) {
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, suiteXml(state))
  run('plutil', ['-lint', file])
}

function phoneContainer() {
  return run('xcrun', ['simctl', 'get_app_container', UDID, BUNDLE, 'data']).trim()
}

function phoneSuitePath() {
  return path.join(phoneContainer(), 'Library/Preferences', `${PHONE_SUITE}.plist`)
}

function writeMacSuite(state) {
  writeSuiteFile(MAC_PLIST, state)
  run('defaults', ['import', MAC_SUITE, MAC_PLIST])
}

function readMacState() {
  const exportPath = path.join(REL, 'run', `mac-export-${nonce}.plist`)
  run('defaults', ['export', MAC_SUITE, exportPath])
  return readSuite(exportPath)
}

function writePhoneSuite(state) {
  writeSuiteFile(phoneSuitePath(), state)
}

function readPhoneState() {
  const file = phoneSuitePath()
  if (!fs.existsSync(file)) return null
  return readSuite(file)
}

function launchMac() {
  if (macProcess) throw new Error('Mac-App läuft bereits')
  macProcess = spawn(path.join(MAC_APP, 'Contents/MacOS/Toolbox'), [], {
    env: { ...process.env, TOOLBOX_DEFAULTS_SUITE: MAC_SUITE },
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  macProcess.stdout.on('data', data => process.stdout.write(`[mac] ${data}`))
  macProcess.stderr.on('data', data => process.stdout.write(`[mac:err] ${data}`))
  macProcess.on('exit', (code, signal) => {
    if (code !== 0 && signal !== 'SIGTERM') {
      console.error(`Mac-App beendet: code=${code} signal=${signal}`)
    }
  })
}

async function stopMac() {
  if (!macProcess) return
  const child = macProcess
  macProcess = null
  child.kill('SIGTERM')
  const exited = new Promise(resolve => child.once('exit', resolve))
  await Promise.race([exited, sleep(3000)])
  if (child.exitCode === null && child.signalCode === null) {
    child.kill('SIGKILL')
    await Promise.race([exited, sleep(1000)])
  }
}

function stopOldApps() {
  const lines = run('ps', ['-axo', 'pid=,command=']).split('\n')
  for (const line of lines) {
    const match = line.trim().match(/^(\d+)\s+\/Applications\/Toolbox\.app\/Contents\/MacOS\/Toolbox$/)
    if (!match) continue
    try {
      process.kill(Number(match[1]), 'SIGTERM')
      console.log(`Installierte Toolbox-Altinstanz beendet (PID ${match[1]})`)
    } catch {
      // Schon beendet.
    }
  }
  try { runQuiet('xcrun', ['simctl', 'terminate', UDID, BUNDLE]) } catch {}
}

function launchPhone() {
  const output = run('xcrun', ['simctl', 'launch', '--terminate-running-process', UDID, BUNDLE], {
    env: { ...process.env, SIMCTL_CHILD_TOOLBOX_DEFAULTS_SUITE: PHONE_SUITE },
  }).trim()
  console.log(`iPhone-App: ${output}`)
}

function stopPhone() {
  try { runQuiet('xcrun', ['simctl', 'terminate', UDID, BUNDLE]) } catch {}
}

function startWindowsPeer() {
  fs.mkdirSync(path.dirname(WINDOWS_DATA), { recursive: true })
  fs.rmSync(WINDOWS_DATA, { force: true })

  const child = spawn(process.execPath, [
    path.join(ROOT, 'scripts/release-windows-peer.js'),
    WIN_ASAR,
    WINDOWS_DATA,
  ], { stdio: ['pipe', 'pipe', 'pipe'] })

  const lines = []
  const statusWaiters = []
  const snapshotWaiters = []
  let readyResolve
  let readyReject
  const ready = new Promise((resolve, reject) => {
    readyResolve = resolve
    readyReject = reject
  })

  const rl = readline.createInterface({ input: child.stdout, crlfDelay: Infinity })
  rl.on('line', line => {
    lines.push(line)
    if (line.startsWith('READY ')) {
      readyResolve(JSON.parse(line.slice(6)))
      return
    }
    if (line.startsWith('STATUS ')) {
      const value = JSON.parse(line.slice(7))
      const waiter = statusWaiters.shift()
      if (waiter) waiter.resolve(value)
      return
    }
    if (line.startsWith('SNAPSHOT ')) {
      const value = JSON.parse(line.slice(9))
      const waiter = snapshotWaiters.shift()
      if (waiter) waiter.resolve(value)
    }
  })
  child.stderr.on('data', data => process.stdout.write(`[windows:err] ${data}`))
  child.on('exit', code => {
    const error = new Error(`Windows-Release-Peer beendet (${code})`)
    readyReject(error)
    for (const waiter of statusWaiters.splice(0)) waiter.reject(error)
    for (const waiter of snapshotWaiters.splice(0)) waiter.reject(error)
  })

  function request(command, waiters) {
    return new Promise((resolve, reject) => {
      waiters.push({ resolve, reject })
      child.stdin.write(`${command}\n`)
    })
  }

  return {
    child,
    lines,
    ready,
    status: () => request('status', statusWaiters),
    snapshot: () => request('snapshot', snapshotWaiters),
    command: command => child.stdin.write(`${command}\n`),
    async close() {
      try { child.stdin.end() } catch {}
      child.kill('SIGTERM')
      await new Promise(resolve => child.once('exit', resolve))
    },
  }
}

async function readWindowsState() {
  const snapshot = await windowsPeer.snapshot()
  const status = await windowsPeer.status()
  if (!fs.existsSync(WINDOWS_DATA)) return null
  const file = JSON.parse(fs.readFileSync(WINDOWS_DATA, 'utf8'))
  return {
    water: { ...file.water, ...snapshot.water },
    counter: { ...file.counter, ...snapshot.counter },
    lastSync: status.lastSync,
    peerCount: status.peerCount,
  }
}

function expectedSeconds(value) {
  return Math.abs(value) > 1e12 ? value / 1000 - APPLE_EPOCH : value
}

function assertWater(label, actual, expected) {
  assert.equal(actual.total, expected.total, `${label}: Wasser-Gesamtmenge`)
  assert.deepEqual(actual.history, expected.history, `${label}: Wasser-Verlauf`)
  assert.deepEqual(actual.recentAdds, expected.recentAdds, `${label}: recentAdds`)
  assert.equal(actual.day, expected.day, `${label}: Tag`)
  assert.equal(actual.glass, expected.glass, `${label}: Glasgröße`)
  assert.equal(actual.bottle, expected.bottle, `${label}: Flaschengröße`)
  assert.equal(actual.goal, expected.goal, `${label}: Tagesziel`)
  const expectedUpdatedAt = expectedSeconds(expected.updatedAt)
  assert.ok(
    Math.abs(actual.updatedAt - expectedUpdatedAt) < 2,
    `${label}: Wasser-Zeitstempel ${actual.updatedAt} != ${expectedUpdatedAt}`
  )
}

function assertCounter(label, actual, expected) {
  assert.equal(actual.count, expected.count, `${label}: Zählerstand`)
  assert.equal(actual.rate, expected.rate, `${label}: Zählerrate`)
  assert.equal(
    actual.savedCounters.length,
    expected.savedCounters.length,
    `${label}: gespeicherte Zähler-Länge`
  )
  for (let index = 0; index < expected.savedCounters.length; index++) {
    const a = actual.savedCounters[index]
    const e = expected.savedCounters[index]
    assert.equal(a.name, e.name, `${label}: gespeicherter Name ${index}`)
    assert.equal(a.value, e.value, `${label}: gespeicherter Wert ${index}`)
    assert.ok(
      Math.abs(a.date - e.date) < 2,
      `${label}: gespeichertes Datum ${index}`
    )
  }
  const expectedUpdatedAt = expectedSeconds(expected.updatedAt)
  assert.ok(
    Math.abs(actual.updatedAt - expectedUpdatedAt) < 2,
    `${label}: Zähler-Zeitstempel ${actual.updatedAt} != ${expectedUpdatedAt}`
  )
}

function assertState(label, actual, expected) {
  assert.ok(actual, `${label}: Zustand fehlt`)
  assertWater(label, actual.water, expected.water)
  assertCounter(label, actual.counter, expected.counter)
}

function assertAllEqual(label, states) {
  const [first, ...rest] = states
  for (const state of rest) {
    assert.equal(state.water.total, first.water.total, `${label}: Gesamtmenge`)
    assert.deepEqual(state.water.history, first.water.history, `${label}: Verlauf`)
    assert.deepEqual(state.water.recentAdds, first.water.recentAdds, `${label}: recentAdds`)
    assert.equal(state.water.glass, first.water.glass, `${label}: Glasgröße`)
    assert.equal(state.water.bottle, first.water.bottle, `${label}: Flaschengröße`)
    assert.equal(state.water.goal, first.water.goal, `${label}: Ziel`)
    assert.equal(state.counter.count, first.counter.count, `${label}: Zähler`)
    assert.equal(state.counter.rate, first.counter.rate, `${label}: Rate`)
    assert.equal(
      state.counter.savedCounters.length,
      first.counter.savedCounters.length,
      `${label}: gespeicherte Zähler`
    )
    assert.ok(
      Math.abs(state.water.updatedAt - first.water.updatedAt) < 2,
      `${label}: gemeinsamer Wasser-Zeitstempel`
    )
    assert.ok(
      Math.abs(state.counter.updatedAt - first.counter.updatedAt) < 2,
      `${label}: gemeinsamer Zähler-Zeitstempel`
    )
  }
}

async function waitForState(label, reader, predicate, timeout = 25_000) {
  const started = Date.now()
  let last = null
  while (Date.now() - started < timeout) {
    last = await reader()
    if (predicate(last)) return last
    await sleep(250)
  }
  throw new Error(`${label} nicht erreicht; letzter Stand: ${JSON.stringify(last)}`)
}

function checkArtifacts() {
  for (const file of [MAC_APP, IOS_APP, WIN_ASAR]) {
    if (!fs.existsSync(file)) throw new Error(`Release-Artefakt fehlt: ${file}`)
  }

  const macVersion = run(PLIST_BUDDY, ['-c', 'Print :CFBundleShortVersionString', path.join(MAC_APP, 'Contents/Info.plist')]).trim()
  const iosVersion = run(PLIST_BUDDY, ['-c', 'Print :CFBundleShortVersionString', path.join(IOS_APP, 'Info.plist')]).trim()
  const windowsVersion = JSON.parse(fs.readFileSync(path.join(WIN_ASAR, 'package.json'), 'utf8')).version

  assert.equal(macVersion, '3.1.0', 'macOS-Release-Version')
  assert.equal(iosVersion, '3.1.0', 'iOS-Release-Version')
  assert.equal(windowsVersion, '3.1.0', 'Windows-Release-Version')
  console.log(`Artefakte: macOS ${macVersion}, iOS ${iosVersion}, Windows ${windowsVersion}`)
}

function makeStates() {
  const base = Date.now() - 60_000
  const today = new Date(base).toISOString().slice(0, 10)
  const yesterday = new Date(base - 86_400_000).toISOString().slice(0, 10)
  const savedCounter = {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Abend',
    value: 2,
    date: (base + 10_000) / 1000 - APPLE_EPOCH,
  }
  const history = value => ({ [yesterday]: 250, [today]: value })

  const v1 = {
    water: {
      total: 400,
      history: history(400),
      recentAdds: [200, 200],
      day: today,
      glass: 200,
      bottle: 500,
      goal: 2000,
      updatedAt: base,
    },
    counter: {
      count: 2,
      savedCounters: [savedCounter],
      rate: 5,
      updatedAt: base,
    },
  }

  const v2 = {
    water: {
      ...v1.water,
      total: 650,
      history: history(650),
      recentAdds: [200, 200, 250],
      glass: 250,
      bottle: 600,
      goal: 2400,
      updatedAt: base + 20_000,
    },
    counter: {
      ...v1.counter,
      count: 3,
      updatedAt: base + 22_000,
    },
  }

  const v3 = {
    water: {
      ...v2.water,
      total: 800,
      history: history(800),
      recentAdds: [200, 200, 250, 150],
      glass: 300,
      bottle: 700,
      goal: 2500,
      updatedAt: base + 40_000,
    },
    counter: {
      ...v2.counter,
      count: 4,
      updatedAt: base + 42_000,
    },
  }

  const stale = {
    water: {
      ...v1.water,
      total: 300,
      history: history(300),
      recentAdds: [200],
      updatedAt: base + 5_000,
    },
    counter: {
      ...v1.counter,
      count: 2,
      updatedAt: base + 5_000,
    },
  }

  const v4 = {
    water: {
      ...v3.water,
      total: 950,
      history: history(950),
      recentAdds: [200, 200, 250, 150, 150],
    },
    counter: {
      ...v3.counter,
      count: 5,
    },
  }

  return { base, today, savedCounter, v1, v2, v3, v4, stale }
}

async function main() {
  checkArtifacts()
  fs.mkdirSync(path.join(REL, 'run'), { recursive: true })

  try { runQuiet('xcrun', ['simctl', 'boot', UDID]) } catch {}
  runQuiet('xcrun', ['simctl', 'bootstatus', UDID, '-b'])
  stopOldApps()
  await sleep(1000)

  run('xcrun', ['simctl', 'install', UDID, IOS_APP])
  try { runQuiet('xcrun', ['simctl', 'privacy', UDID, 'grant', 'all', BUNDLE]) } catch {}
  stopPhone()
  fs.rmSync(phoneSuitePath(), { force: true })

  const { base, savedCounter, v1, v2, v3, v4, stale } = makeStates()
  console.log(`Test-Suites: ${MAC_SUITE} / ${PHONE_SUITE}`)

  // 1. Mac legt v1 an, iPhone übernimmt.
  writeMacSuite(v1)
  launchMac()
  launchPhone()
  const phoneV1 = await waitForState('iPhone v1', readPhoneState,
    state => state?.water.total === 400 && state?.counter.count === 2, 30_000)
  assertState('iPhone v1', phoneV1, v1)
  assert.equal(phoneV1.counter.savedCounters[0].name, savedCounter.name)
  console.log('1/7 Mac → iPhone: 400 ml / Zähler 2 inklusive Verlauf und gespeichertem Stand')

  // 2. Mac vollständig trennen. Das iPhone bleibt allein.
  await stopMac()
  await sleep(1000)

  // 3. Windows startet später und bekommt den Stand ausschließlich vom iPhone.
  windowsPeer = startWindowsPeer()
  await windowsPeer.ready
  await sleep(1000)
  const windowsV1 = await waitForState('Windows v1', readWindowsState,
    state => state?.water.total === 400 && state?.counter.count === 2, 30_000)
  assertState('Windows v1', windowsV1, v1)
  assert.equal(windowsV1.peerCount, 1, 'Windows muss nur das iPhone sehen')
  console.log('2/7 iPhone → Windows ohne Mac: 400 ml / Zähler 2 übernommen')

  // 4. Mac wieder dazu; alle drei sind gleichzeitig verbunden.
  writeMacSuite(v1)
  launchMac()
  await waitForState('drei Peers', async () => {
    const status = await windowsPeer.status()
    return { peerCount: status.peerCount, peers: status.peers }
  }, state => state.peerCount === 2, 30_000)
  const macV1 = await waitForState('Mac v1 nach Relaunch', readMacState,
    state => state.water.total === 400, 15_000)
  assertState('Mac v1', macV1, v1)
  console.log('3/7 Drei Peers gleichzeitig: Windows sieht Mac und iPhone')

  // 5. Mac-Änderung auf v2, iPhone und Windows übernehmen.
  await stopMac()
  writeMacSuite(v2)
  launchMac()
  const phoneV2 = await waitForState('iPhone v2', readPhoneState,
    state => state?.water.total === 650 && state?.counter.count === 3, 30_000)
  const windowsV2 = await waitForState('Windows v2', readWindowsState,
    state => state?.water.total === 650 && state?.counter.count === 3, 30_000)
  assertState('iPhone v2', phoneV2, v2)
  assertState('Windows v2', windowsV2, v2)
  console.log('4/7 Mac-Update v2: 650 ml / Zähler 3 auf iPhone und Windows')

  // 6. iPhone-Änderung auf v3, Mac und Windows übernehmen.
  // Ein Reinstall leert die vom Simulator zwischengespeicherte
  // UserDefaults-Domain; sonst ignoriert die App den direkt geschriebenen
  // Suite-Stand und würde weiterhin v2 senden.
  stopPhone()
  try { runQuiet('xcrun', ['simctl', 'uninstall', UDID, BUNDLE]) } catch {}
  run('xcrun', ['simctl', 'install', UDID, IOS_APP])
  try { runQuiet('xcrun', ['simctl', 'privacy', UDID, 'grant', 'all', BUNDLE]) } catch {}
  await sleep(1000)
  writePhoneSuite(v3)
  launchPhone()
  const macV3 = await waitForState('Mac v3', readMacState,
    state => state?.water.total === 800 && state?.counter.count === 4, 30_000)
  const windowsV3 = await waitForState('Windows v3', readWindowsState,
    state => state?.water.total === 800 && state?.counter.count === 4, 30_000)
  assertState('Mac v3', macV3, v3)
  assertState('Windows v3', windowsV3, v3)
  console.log('5/7 iPhone-Update v3: 800 ml / Zähler 4 auf Mac und Windows')

  // 7. Windows-Änderung live auf v4; beide Apple-Apps übernehmen.
  windowsPeer.command('addwater 150')
  await sleep(300)
  windowsPeer.command('increment')
  const windowsV4 = await waitForState('Windows v4', readWindowsState,
    state => state?.water.total === 950 && state?.counter.count === 5, 15_000)
  const phoneV4 = await waitForState('iPhone v4', readPhoneState,
    state => state?.water.total === 950 && state?.counter.count === 5, 30_000)
  const macV4 = await waitForState('Mac v4', readMacState,
    state => state?.water.total === 950 && state?.counter.count === 5, 30_000)
  const expectedV4 = {
    water: { ...v4.water, updatedAt: windowsV4.water.updatedAt },
    counter: { ...v4.counter, updatedAt: windowsV4.counter.updatedAt },
  }
  assertState('Windows v4', windowsV4, expectedV4)
  assertState('iPhone v4', phoneV4, expectedV4)
  assertState('Mac v4', macV4, expectedV4)
  console.log('6/7 Windows-Update v4: 950 ml / Zähler 5 auf Mac und iPhone')

  // 8. Verspäteter alter Mac-Stand darf v4 nicht überschreiben.
  await stopMac()
  writeMacSuite(stale)
  launchMac()
  const macAfterStale = await waitForState('Mac nach altem Stand', readMacState,
    state => state?.water.total === 950 && state?.counter.count === 5, 30_000)
  const phoneAfterStale = await waitForState('iPhone nach altem Stand', readPhoneState,
    state => state?.water.total === 950 && state?.counter.count === 5, 15_000)
  const windowsAfterStale = await waitForState('Windows nach altem Stand', readWindowsState,
    state => state?.water.total === 950 && state?.counter.count === 5, 15_000)
  assertState('Mac nach altem Stand', macAfterStale, expectedV4)
  assertState('iPhone nach altem Stand', phoneAfterStale, expectedV4)
  assertState('Windows nach altem Stand', windowsAfterStale, expectedV4)
  assertAllEqual('finaler Stand', [windowsV4, macAfterStale, phoneAfterStale, windowsAfterStale])
  console.log('7/7 Verspäteter Mac-Stand verworfen; alle drei bleiben bei 950 ml / Zähler 5')

  assert.equal(windowsAfterStale.counter.savedCounters[0].name, savedCounter.name)
  assert.equal(windowsAfterStale.peerCount, 2, 'Windows muss weiterhin beide Apple-Peers sehen')
  assert.ok(windowsAfterStale.lastSync, 'Windows muss einen letzten Sync-Zeitpunkt haben')

  console.log(
    `Drei-Geräte-Release-Kette erfolgreich: Mac→iPhone→Windows; `
    + `v1 400 → iPhone 400 → Windows 400; v2 650; v3 800; Windows v4 950; `
    + `alter Mac-Stand 300 verworfen; Verlauf, Größen und gespeicherter Zähler erhalten. `
    + `Builds: macOS 3.1.0 (DMG), iOS 3.1.0 (Tag), Windows 3.1.0 (Setup.exe/app.asar).`
  )
  console.log(`Basis-Timestamp: ${base}`)
}

async function cleanup() {
  try { await stopMac() } catch {}
  try { stopPhone() } catch {}
  if (windowsPeer) {
    try { await windowsPeer.close() } catch {}
    windowsPeer = null
  }
  fs.rmSync(WINDOWS_DATA, { force: true })
  fs.rmSync(MAC_PLIST, { force: true })
  fs.rmSync(path.join(REL, 'run', `mac-export-${nonce}.plist`), { force: true })
}

main()
  .catch(error => {
    console.error('Release-Sync-Kette fehlgeschlagen:', error)
    process.exitCode = 1
  })
  .finally(cleanup)
