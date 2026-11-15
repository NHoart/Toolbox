'use strict'

const fs = require('node:fs')
const path = require('node:path')
const { build, Platform, Arch } = require('electron-builder')

const root = path.join(__dirname, '..')
const configPath = path.join(root, 'store', 'store.config.json')
const pkg = require(path.join(root, 'package.json'))

const checkOnly = process.argv.includes('--check')
const allowPlaceholder = process.env.ALLOW_STORE_PLACEHOLDER === '1'

function fail(message) {
  console.error(`\n${message}\n`)
  process.exit(1)
}

let store
try {
  store = JSON.parse(fs.readFileSync(configPath, 'utf8'))
} catch (error) {
  fail(`windows/store/store.config.json konnte nicht gelesen werden: ${error.message}`)
}

const identityName = String(store.identityName || '').trim()
const publisher = String(store.publisher || '').trim()
const publisherDisplayName = String(store.publisherDisplayName || pkg.author || '').trim()
const displayName = String(store.displayName || pkg.productName || 'Toolbox').trim()
const applicationId = String(store.applicationId || 'Toolbox').trim()
const placeholder = !identityName
  || !publisher
  || identityName.startsWith('TODO')
  || publisher.startsWith('CN=TODO')

if (placeholder && !allowPlaceholder) {
  fail([
    'Die Microsoft-Store-Identität ist noch nicht eingetragen.',
    '',
    'Trage in windows/store/store.config.json die Werte aus Partner Center ein:',
    '  identityName         = Package/Identity/Name',
    '  publisher            = Package/Identity/Publisher',
    '  publisherDisplayName = Anzeigename des Herausgebers',
    '',
    'Für einen reinen Testbau ohne Store-Identität:',
    '  ALLOW_STORE_PLACEHOLDER=1 npm run dist:store',
  ].join('\n'))
}

if (!/^[A-Za-z0-9.-]{3,50}$/.test(identityName)) {
  fail(`identityName ist ungültig (3–50 Zeichen, nur A–Z, a–z, 0–9, Punkt und Bindestrich): ${identityName}`)
}
if (!/^CN=.+/.test(publisher)) {
  fail(`publisher muss mit "CN=" beginnen und exakt dem Wert aus Partner Center entsprechen: ${publisher}`)
}
if (!/^[A-Za-z][A-Za-z0-9.]*$/.test(applicationId)) {
  fail(`applicationId ist ungültig (alphanumerische, mit einem Buchstaben beginnende Segmente, durch Punkte getrennt): ${applicationId}`)
}
if (!displayName) fail('displayName darf nicht leer sein.')
if (!publisherDisplayName) fail('publisherDisplayName darf nicht leer sein.')

if (placeholder) {
  console.warn('WARNUNG: Testbau mit Platzhalter-Identität. Dieses Paket kann nicht im Microsoft Store eingereicht werden.')
}

const config = {
  ...pkg.build,
  win: {
    ...pkg.build.win,
    target: [{ target: 'appx', arch: ['x64'] }],
  },
  appx: {
    ...(pkg.build.appx || {}),
    identityName,
    publisher,
    publisherDisplayName,
    displayName,
    applicationId,
    artifactName: 'Toolbox-${version}.${ext}',
  },
}

if (checkOnly) {
  console.log('Store-Konfiguration OK.')
  console.log(`  identityName: ${identityName}`)
  console.log(`  publisher: ${publisher}`)
  console.log(`  publisherDisplayName: ${publisherDisplayName}`)
  console.log(`  displayName: ${displayName}`)
  console.log(`  applicationId: ${applicationId}`)
  console.log(`  capabilities: ${(config.appx.capabilities || []).join(', ')}`)
  if (placeholder) console.log('  Hinweis: Platzhalter-Identität (Testbau).')
  process.exit(0)
}

// Der Store signiert das Paket beim Einreichen neu. Ein lokales Zertifikat
// würde nur einen falschen Publisher in das Manifest schreiben.
process.env.CSC_IDENTITY_AUTO_DISCOVERY = 'false'

console.log(`Baue AppX für ${identityName} …`)
build({
  targets: Platform.WINDOWS.createTarget('appx', Arch.x64),
  config,
  publish: 'never',
}).then(() => {
  console.log('AppX fertig. Die Datei liegt unter windows/dist/.')
}).catch(error => {
  console.error('AppX-Build fehlgeschlagen:', error)
  process.exit(1)
})
