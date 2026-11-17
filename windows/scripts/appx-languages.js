'use strict'

// This list is the authoritative source for the Store build. The build
// overwrites appx.languages from package.json with it; a test makes sure
// that the two lists do not drift apart.
const APPX_LANGUAGES = Object.freeze([
  'de-DE',
  'en-US',
  'es-ES',
  'fr-FR',
])

module.exports = { APPX_LANGUAGES }
