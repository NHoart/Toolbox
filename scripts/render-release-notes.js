#!/usr/bin/env node
'use strict'

// Beide Release-Workflows verwenden dieses Skript. Es rendert den einen
// kombinierten Body aus gemeinsamem Kopf, macOS-Teil, Windows-Teil und
// gemeinsamem Abschluss. Dadurch darf jeder Workflow zuerst fertig werden,
// ohne dass die Notes der anderen Plattform verloren gehen.

const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const sections = [
  '.github/release-notes-header.md',
  '.github/macos-release-notes.md',
  '.github/windows-release-notes.md',
  '.github/release-notes-footer.md'
]

function fail(message) {
  console.error(`Fehler: ${message}`)
  process.exit(1)
}

function usage() {
  console.log('Aufruf: render-release-notes.js --repo <owner/name> --tag <tag> --out <datei> [--store-url <url>]')
}

function parseArgs(argv) {
  const result = {
    repo: process.env.GITHUB_REPOSITORY || '',
    tag: process.env.GITHUB_REF_NAME || '',
    out: '',
    storeUrl: process.env.STORE_URL || ''
  }

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index]
    if (argument === '--help' || argument === '-h') {
      usage()
      process.exit(0)
    }
    if (!argument.startsWith('--')) {
      fail(`Unbekanntes Argument: ${argument}`)
    }
    const value = argv[index + 1]
    if (value === undefined || value.startsWith('--')) {
      fail(`${argument} braucht einen Wert`)
    }
    index += 1
    if (argument === '--repo') result.repo = value
    else if (argument === '--tag') result.tag = value
    else if (argument === '--out') result.out = value
    else if (argument === '--store-url') result.storeUrl = value
    else fail(`Unbekannte Option: ${argument}`)
  }

  if (!result.repo) fail('--repo fehlt')
  if (!result.tag) fail('--tag fehlt')
  if (!result.out) fail('--out fehlt')
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(result.repo)) {
    fail(`--repo ist ungültig: ${result.repo}`)
  }
  if (!/^[A-Za-z0-9_.-]+$/.test(result.tag)) {
    fail(`--tag ist ungültig: ${result.tag}`)
  }
  if (result.storeUrl && (!/^https?:\/\/[^\s]+$/.test(result.storeUrl) || /[\r\n]/.test(result.storeUrl))) {
    fail('--store-url ist ungültig')
  }
  return result
}

const args = parseArgs(process.argv.slice(2))
const storeRow = args.storeUrl
  ? `| **Microsoft Store** (Windows 10/11) | [Toolbox for Windows im Microsoft Store](${args.storeUrl}) |`
  : ''

const body = sections
  .map(file => {
    const filename = path.join(root, file)
    if (!fs.existsSync(filename)) fail(`Release-Notes-Datei fehlt: ${file}`)
    return fs.readFileSync(filename, 'utf8').trim()
  })
  .join('\n\n')
  .replaceAll('{{REPO}}', args.repo)
  .replaceAll('{{TAG}}', args.tag)
  .replaceAll('{{STORE_ROW}}', storeRow)
  .replace(/\n{3,}/g, '\n\n')
  .trim()

const leftover = body.match(/\{\{[A-Z_]+\}\}/g)
if (leftover) fail(`Unersetzte Platzhalter: ${[...new Set(leftover)].join(', ')}`)
for (const heading of ['## Toolbox für macOS', '## Toolbox für Windows']) {
  if (!body.includes(heading)) fail(`Release-Notes enthalten keinen Abschnitt "${heading}"`)
}

fs.writeFileSync(args.out, `${body}\n`, 'utf8')
