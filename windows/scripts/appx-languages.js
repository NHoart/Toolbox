'use strict'

// Diese Liste ist die verbindliche Quelle für den Store-Build. Der Build
// überschreibt damit die appx.languages aus package.json; ein Test stellt
// sicher, dass beide Listen nicht auseinanderlaufen.
const APPX_LANGUAGES = Object.freeze([
  'de-DE',
  'en-US',
  'es-ES',
  'fr-FR',
])

module.exports = { APPX_LANGUAGES }
