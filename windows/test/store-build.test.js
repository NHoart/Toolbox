'use strict'

const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { APPX_LANGUAGES } = require('../scripts/appx-languages')

const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'), 'utf8'))

test('AppX build declares the four Store languages', () => {
  assert.deepEqual(APPX_LANGUAGES, ['de-DE', 'en-US', 'es-ES', 'fr-FR'])
  assert.deepEqual(pkg.build.appx.languages, [...APPX_LANGUAGES])
})

test('AppX language list contains no duplicates', () => {
  assert.equal(new Set(APPX_LANGUAGES).size, APPX_LANGUAGES.length)
})
