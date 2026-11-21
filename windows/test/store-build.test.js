'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { APPX_LANGUAGES } = require('../scripts/appx-languages')

const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'))
const rendererDir = path.join(__dirname, '..', 'renderer')

test('AppX build declares the four Store languages', () => {
  assert.deepEqual(APPX_LANGUAGES, ['en-US', 'de-DE', 'es-ES', 'fr-FR'])
  assert.deepEqual(pkg.build.appx.languages, [...APPX_LANGUAGES])
})

test('English is the default AppX language', () => {
  // Windows uses the first manifest entry as the default language and falls
  // back to it when the user's languages are not supported. This must be
  // English, never German.
  assert.equal(APPX_LANGUAGES[0], 'en-US')
  assert.equal(pkg.build.appx.languages[0], 'en-US')
})

test('AppX language list contains no duplicates', () => {
  assert.equal(new Set(APPX_LANGUAGES).size, APPX_LANGUAGES.length)
})

test('the Store build removes the Updates section from Settings', () => {
  const html = fs.readFileSync(path.join(rendererDir, 'index.html'), 'utf8')
  const css = fs.readFileSync(path.join(rendererDir, 'styles.css'), 'utf8')
  const app = fs.readFileSync(path.join(rendererDir, 'app.js'), 'utf8')

  // The card exists for the regular build only; no leftover hooks from the
  // former Store hint remain.
  assert.match(html, /<div class="card inset" id="updateCard" hidden>/)
  assert.doesNotMatch(html, /id="(autoUpdateRow|checkUpdateRow|updateHint|updateStoreHint)"/)

  // A hidden card must not be overridden by card layout rules. No class-based
  // display rule may win against the hidden attribute, and the ID rule keeps
  // the Updates card off screen.
  assert.match(css, /\[hidden\]\s*\{\s*display:\s*none\s*!important;?\s*\}/)
  assert.match(css, /#updateCard\[hidden\]\s*\{\s*display:\s*none\s*!important;?\s*\}/)

  const importantDisplayRules = css.match(/[^{}]+\{[^}]*display:\s*[^;}]*!important[^}]*\}/g) || []
  for (const rule of importantDisplayRules) {
    assert.doesNotMatch(rule, /\.card\b/)
  }

  // In the Store build the card is removed from the DOM, not merely hidden;
  // the regular build unhides the card once the update state is known.
  assert.match(app, /const card = \$\('updateCard'\)/)
  assert.match(app, /if \(updateState\.storeManaged\) \{\s*if \(card\) card\.remove\(\)\s*return\s*\}/)
  assert.match(app, /if \(card\) card\.hidden = false/)
})

test('Store-only update copy is gone from every translation', () => {
  const i18n = require('../renderer/i18n.js')
  const removed = [
    'Updates über den Microsoft Store',
    'Updates werden über den Microsoft Store verwaltet. Der Store hält Toolbox automatisch aktuell; die GitHub-Update-Prüfung ist in dieser Fassung aus.',
  ]

  for (const [language, dictionary] of Object.entries(i18n.dictionaries)) {
    for (const key of removed) {
      assert.equal(dictionary[key], undefined, `${language} still translates ${key}`)
    }
  }
})
