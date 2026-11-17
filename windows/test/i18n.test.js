'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')

const i18n = require('../renderer/i18n.js')

test('Region wird auf die Sprachbasis abgebildet', () => {
  assert.deepEqual(i18n.chooseLocale({ preferred: ['de-AT'] }), {
    language: 'de',
    localeTag: 'de-AT',
  })
  assert.deepEqual(i18n.chooseLocale({ preferred: ['en-GB'] }), {
    language: 'en',
    localeTag: 'en-GB',
  })
  assert.deepEqual(i18n.chooseLocale({ preferred: ['es-419'] }), {
    language: 'es',
    localeTag: 'es-419',
  })
})

test('Unbekannte Sprachen fallen auf Englisch zurück', () => {
  assert.deepEqual(i18n.chooseLocale({ preferred: ['it-IT'] }), {
    language: 'en',
    localeTag: 'en-US',
  })
  assert.deepEqual(i18n.chooseLocale({ preferred: [] }), {
    language: 'en',
    localeTag: 'en-US',
  })
  assert.deepEqual(i18n.chooseLocale(), {
    language: 'en',
    localeTag: 'en-US',
  })
})

test('Die erste unterstützte Systemsprache gewinnt', () => {
  assert.deepEqual(i18n.chooseLocale({ preferred: ['it-IT', 'de-DE', 'en-US'] }), {
    language: 'de',
    localeTag: 'de-DE',
  })
  assert.deepEqual(i18n.chooseLocale({ preferred: ['ja-JP', 'fr-CA'] }), {
    language: 'fr',
    localeTag: 'fr-CA',
  })
})

test('Manuelle Wahl und erzwungene Sprache schlagen die Systemsprache', () => {
  assert.deepEqual(i18n.chooseLocale({ stored: 'fr', preferred: ['de-DE'] }), {
    language: 'fr',
    localeTag: 'fr-FR',
  })
  assert.deepEqual(i18n.chooseLocale({ forced: 'es-ES', stored: 'de', preferred: ['de-DE'] }), {
    language: 'es',
    localeTag: 'es-ES',
  })
})

test('Ungültige Region-Tags brechen die Auswahl nicht', () => {
  assert.deepEqual(i18n.chooseLocale({ preferred: ['en-US-x-!!!'] }), {
    language: 'en',
    localeTag: 'en-US',
  })
})

test('Alle Übersetzungen decken dieselben Schlüssel ab', () => {
  const languages = ['en', 'es', 'fr']
  const reference = Object.keys(i18n.dictionaries.en).sort()

  assert.equal(i18n.defaultLanguage, 'en')
  assert.ok(reference.length > 100)
  for (const language of languages) {
    assert.deepEqual(Object.keys(i18n.dictionaries[language]).sort(), reference)
  }
})

test('Englisch ist vollständig übersetzt', () => {
  assert.equal(i18n.translateFor('en', 'Heute'), 'Today')
  assert.equal(i18n.translateFor('en', 'Einstellungen'), 'Settings')
  assert.equal(i18n.translateFor('de', 'Heute'), 'Heute')
})
