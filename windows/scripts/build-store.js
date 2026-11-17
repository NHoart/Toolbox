'use strict'

const fs = require('node:fs')
const path = require('node:path')
const { build, Platform, Arch } = require('electron-builder')
const { validateConfiguration } = require('app-builder-lib/out/util/config/config')
const { APPX_LANGUAGES } = require('./appx-languages')

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
  fail(`Could not read windows/store/store.config.json: ${error.message}`)
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
    'The Microsoft Store identity has not been entered yet.',
    '',
    'Enter the values from Partner Center in windows/store/store.config.json:',
    '  identityName         = Package/Identity/Name',
    '  publisher            = Package/Identity/Publisher',
    '  publisherDisplayName = Anzeigename des Herausgebers',
    '',
    'For a pure test build without a Store identity:',
    '  ALLOW_STORE_PLACEHOLDER=1 npm run dist:store',
  ].join('\n'))
}

if (!/^[A-Za-z0-9.-]{3,50}$/.test(identityName)) {
  fail(`identityName is invalid (3–50 characters, only A–Z, a–z, 0–9, period and hyphen): ${identityName}`)
}
if (!/^CN=.+/.test(publisher)) {
  fail(`publisher must start with "CN=" and match the Partner Center value exactly: ${publisher}`)
}
if (!/^[A-Za-z][A-Za-z0-9.]*$/.test(applicationId)) {
  fail(`applicationId is invalid (alphanumeric segments starting with a letter, separated by periods): ${applicationId}`)
}
if (!displayName) fail('displayName must not be empty.')
if (!publisherDisplayName) fail('publisherDisplayName must not be empty.')

const configuredLanguages = Array.isArray(pkg.build && pkg.build.appx && pkg.build.appx.languages)
  ? pkg.build.appx.languages.map(language => String(language).trim())
  : []
if (configuredLanguages.join(',') !== APPX_LANGUAGES.join(',')) {
  fail([
    'The AppX languages in windows/package.json are incomplete.',
    `Erwartet: ${APPX_LANGUAGES.join(', ')}`,
    `Gefunden: ${configuredLanguages.length ? configuredLanguages.join(', ') : '(keine)'}`,
  ].join('\n'))
}

if (placeholder) {
  console.warn('WARNING: test build with placeholder identity. This package cannot be submitted to the Microsoft Store.')
}

const config = {
  ...pkg.build,
  // The old winCodeSign-2.6.0 toolchain is no longer reliable for AppX on
  // current Windows runners. Use Windows Kits 10.0.26100.0;
  // the NSIS build stays untouched.
  toolsets: {
    ...(pkg.build.toolsets || {}),
    winCodeSign: '1.1.0',
  },
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
    // Always write the four supported languages into the manifest, even
    // if package.json was changed by accident. The check above
    // prevents the two lists from drifting apart silently.
    languages: [...APPX_LANGUAGES],
  },
}

// The Store build does not publish through electron-builder. The publish
// configuration inherited from the NSIS build is unnecessary here and is not
// accepted as a valid schema by the electron-builder JS API.
delete config.publish

async function run() {
  if (checkOnly) {
    await validateConfiguration(config, { isEnabled: false, add() {} })
    console.log('Store-Konfiguration OK.')
    console.log(`  identityName: ${identityName}`)
    console.log(`  publisher: ${publisher}`)
    console.log(`  publisherDisplayName: ${publisherDisplayName}`)
    console.log(`  displayName: ${displayName}`)
    console.log(`  applicationId: ${applicationId}`)
    console.log(`  languages: ${config.appx.languages.join(', ')}`)
    console.log(`  capabilities: ${(config.appx.capabilities || []).join(', ')}`)
    console.log(`  winCodeSign: ${config.toolsets.winCodeSign}`)
    if (placeholder) console.log('  Note: placeholder identity (test build).')
    return
  }

  // The Store re-signs the package on submission. A local certificate
  // would only write a wrong publisher into the manifest.
  process.env.CSC_IDENTITY_AUTO_DISCOVERY = 'false'

  console.log(`Building AppX for ${identityName} with ${APPX_LANGUAGES.join(', ')} …`)
  await build({
    targets: Platform.WINDOWS.createTarget('appx', Arch.x64),
    config,
    // The Store build is uploaded exclusively as a workflow artifact;
    // electron-builder must not publish by itself.
    publish: 'never',
  })
  console.log('AppX fertig. Die Datei liegt unter windows/dist/.')
  console.log('Verify the manifest (Windows): powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-appx.ps1')
}

run().catch(error => {
  console.error(checkOnly ? 'Store configuration invalid:' : 'AppX-Build fehlgeschlagen:', error)
  process.exit(1)
})
