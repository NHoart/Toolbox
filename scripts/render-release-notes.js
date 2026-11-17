#!/usr/bin/env node
'use strict'

// Both release workflows use this script. It renders the single combined body
// from the shared header, the macOS part, the Windows part and the shared
// footer. That way either workflow may finish first without losing the notes of
// the other platform.

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
  console.error(`Error: ${message}`)
  process.exit(1)
}

function usage() {
  console.log('Usage: render-release-notes.js --repo <owner/name> --tag <tag> --out <file> [--store-url <url>]')
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
      fail(`Unknown argument: ${argument}`)
    }
    const value = argv[index + 1]
    if (value === undefined || value.startsWith('--')) {
      fail(`${argument} requires a value`)
    }
    index += 1
    if (argument === '--repo') result.repo = value
    else if (argument === '--tag') result.tag = value
    else if (argument === '--out') result.out = value
    else if (argument === '--store-url') result.storeUrl = value
    else fail(`Unknown option: ${argument}`)
  }

  if (!result.repo) fail('--repo is missing')
  if (!result.tag) fail('--tag is missing')
  if (!result.out) fail('--out is missing')
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(result.repo)) {
    fail(`--repo is invalid: ${result.repo}`)
  }
  if (!/^[A-Za-z0-9_.-]+$/.test(result.tag)) {
    fail(`--tag is invalid: ${result.tag}`)
  }
  if (result.storeUrl && (!/^https?:\/\/[^\s]+$/.test(result.storeUrl) || /[\r\n]/.test(result.storeUrl))) {
    fail('--store-url is invalid')
  }
  return result
}

const args = parseArgs(process.argv.slice(2))
const storeRow = args.storeUrl
  ? `| **Microsoft Store** (Windows 10/11) | [Toolbox for Windows in the Microsoft Store](${args.storeUrl}) |`
  : ''

const body = sections
  .map(file => {
    const filename = path.join(root, file)
    if (!fs.existsSync(filename)) fail(`Release notes file is missing: ${file}`)
    return fs.readFileSync(filename, 'utf8').trim()
  })
  .join('\n\n')
  .replaceAll('{{REPO}}', args.repo)
  .replaceAll('{{TAG}}', args.tag)
  .replaceAll('{{STORE_ROW}}', storeRow)
  .replace(/\n{3,}/g, '\n\n')
  .trim()

const leftover = body.match(/\{\{[A-Z_]+\}\}/g)
if (leftover) fail(`Unreplaced placeholders: ${[...new Set(leftover)].join(', ')}`)
for (const heading of ['## Toolbox for macOS', '## Toolbox for Windows']) {
  if (!body.includes(heading)) fail(`Release notes do not contain the section "${heading}"`)
}

fs.writeFileSync(args.out, `${body}\n`, 'utf8')
