'use strict'

// This list is the authoritative source for the Store build. The build
// overwrites appx.languages from package.json with it; a test makes sure
// that the two lists do not drift apart.
//
// The first entry is the package's default language. Windows falls back to
// it when the user's languages match none of the entries, so English must
// stay first.
const APPX_LANGUAGES = Object.freeze([
  'en-US',
  'de-DE',
  'es-ES',
  'fr-FR',
])

module.exports = { APPX_LANGUAGES }
