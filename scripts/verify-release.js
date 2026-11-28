#!/usr/bin/env node
'use strict'

// Verifies the artifacts of a Toolbox release tag. The AppX is a workflow
// artifact, not a release asset, so the script finds the matching Store run.

const { spawnSync } = require('child_process')
const crypto = require('crypto')
const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const storeWorkflow = 'windows-store.yml'
const storeArtifact = 'Toolbox-appx'

function fail(message) {
  throw new Error(message)
}

function usage() {
  console.log(`Usage: node scripts/verify-release.js <tag>

Downloads the release assets and the Microsoft Store AppX for a tag, verifies
the DMG, the EXE checksum from latest.yml, the AppX checksum and the AppX
manifest, and prints a compact summary.

Run on macOS. Requires gh (authenticated), unzip and hdiutil.`)
}

function parseTag(argv) {
  if (argv.length === 1 && (argv[0] === '--help' || argv[0] === '-h')) {
    usage()
    process.exit(0)
  }
  if (argv.length !== 1) {
    usage()
    fail('Pass exactly one release tag.')
  }

  const tag = argv[0].startsWith('v') ? argv[0] : `v${argv[0]}`
  if (!/^v\d+\.\d+\.\d+$/.test(tag)) {
    usage()
    fail(`Tag is invalid: ${argv[0]}`)
  }
  return tag
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
    ...options
  })

  if (result.error) {
    if (result.error.code === 'ENOENT') fail(`Required command not found: ${command}`)
    fail(`${command} failed: ${result.error.message}`)
  }
  if (result.status !== 0) {
    const output = (result.stderr || result.stdout || '').trim()
    const detail = output.split(/\r?\n/).slice(-5).join('\n')
    fail(`${command} ${args.join(' ')} failed${detail ? `:\n${detail}` : ''}`)
  }
  return result
}

function ghJson(args) {
  const output = run('gh', args).stdout
  try {
    return JSON.parse(output)
  } catch (error) {
    fail(`gh returned invalid JSON: ${error.message}`)
  }
}

function hashFile(filename, algorithm, encoding = 'hex') {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash(algorithm)
    fs.createReadStream(filename)
      .on('data', chunk => hash.update(chunk))
      .on('error', reject)
      .on('end', () => resolve(hash.digest(encoding)))
  })
}

function parseAttributes(tag) {
  const attributes = {}
  for (const match of tag.matchAll(/([A-Za-z_][\w:.-]*)="([^"]*)"/g)) {
    attributes[match[1]] = match[2]
  }
  return attributes
}

function checkManifest(filename, packageJson, storeConfig, version) {
  const xml = run('unzip', ['-p', filename, 'AppxManifest.xml']).stdout.replace(/\s+/g, ' ')
  const identityTag = xml.match(/<Identity\b[^>]*>/i)
  if (!identityTag) fail('Identity is missing from AppxManifest.xml.')
  const identity = parseAttributes(identityTag[0])

  const languages = [...xml.matchAll(/<(?:[A-Za-z0-9]+:)?Resource\b[^>]*\bLanguage="([^"]+)"/gi)]
    .map(match => match[1])
  const expectedLanguages = packageJson.build?.appx?.languages || []
  if (!expectedLanguages.length) fail('windows/package.json has no build.appx.languages.')

  if (identity.Name !== storeConfig.identityName) {
    fail(`Identity.Name is ${identity.Name}, expected ${storeConfig.identityName}.`)
  }
  if (identity.Publisher !== storeConfig.publisher) {
    fail(`Identity.Publisher is ${identity.Publisher}, expected ${storeConfig.publisher}.`)
  }
  if (identity.ProcessorArchitecture !== 'x64') {
    fail(`ProcessorArchitecture is ${identity.ProcessorArchitecture}, expected x64.`)
  }
  if (!identity.Version?.startsWith(`${version}.`)) {
    fail(`Package version ${identity.Version} does not match ${version}.`)
  }
  if (
    languages[0] !== 'en-US' ||
    languages.length !== expectedLanguages.length ||
    !expectedLanguages.every(language => languages.includes(language))
  ) {
    fail(`Languages are ${languages.join(', ') || 'none'}, expected ${expectedLanguages.join(', ')} with en-US first.`)
  }

  return `${identity.Version}, ${identity.ProcessorArchitecture}, ${languages.join(', ')}`
}

function latestYmlValue(text, key) {
  const match = text.match(new RegExp(`^${key}:\\s*(\\S+)\\s*$`, 'm'))
  if (!match) fail(`latest.yml has no ${key}.`)
  return match[1]
}

async function main() {
  const tag = parseTag(process.argv.slice(2))
  if (process.platform !== 'darwin') {
    fail('Run this script on macOS; it verifies the DMG with hdiutil.')
  }
  const version = tag.slice(1)

  const release = ghJson(['release', 'view', tag, '--json', 'isDraft,url'])
  if (release.isDraft) fail(`Release ${tag} is still a draft.`)

  const runs = ghJson([
    'run', 'list',
    '--workflow', storeWorkflow,
    '--branch', tag,
    '--limit', '1',
    '--json', 'databaseId,status,conclusion,url'
  ])
  const appxRun = runs[0]
  if (!appxRun) fail(`No ${storeWorkflow} run found for ${tag}.`)
  if (appxRun.status !== 'completed') fail(`AppX run is ${appxRun.status}: ${appxRun.url}`)
  if (appxRun.conclusion !== 'success') fail(`AppX run finished with ${appxRun.conclusion}: ${appxRun.url}`)

  const targetDir = path.join(root, 'build', 'release-verify', tag)
  const releaseDir = path.join(targetDir, 'release')
  const appxDir = path.join(targetDir, 'appx')
  fs.rmSync(targetDir, { recursive: true, force: true })
  fs.mkdirSync(releaseDir, { recursive: true })
  fs.mkdirSync(appxDir, { recursive: true })

  console.log(`Verifying Toolbox ${version}`)
  console.log(`Release:  ${release.url}`)
  console.log(`AppX run: ${appxRun.url}`)
  console.log(`Files:    ${path.relative(root, targetDir)}`)

  console.log('Downloading release assets...')
  run('gh', ['release', 'download', tag, '--dir', releaseDir], { stdio: 'inherit' })
  console.log(`Downloading ${storeArtifact}...`)
  run('gh', ['run', 'download', String(appxRun.databaseId), '--name', storeArtifact, '--dir', appxDir], {
    stdio: 'inherit'
  })

  const dmg = path.join(releaseDir, 'Toolbox.dmg')
  const exe = path.join(releaseDir, 'Toolbox-Setup.exe')
  const latestYml = path.join(releaseDir, 'latest.yml')
  const appx = path.join(appxDir, `Toolbox-${version}.appx`)
  const checksums = path.join(appxDir, 'SHA256SUMS.txt')
  const missing = [dmg, exe, latestYml, appx, checksums].filter(file => !fs.existsSync(file))
  if (missing.length) {
    fail(`Missing downloaded files: ${missing.map(file => path.relative(targetDir, file)).join(', ')}`)
  }
  console.log(`AppX:     ${path.relative(root, appx)}`)

  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'windows', 'package.json'), 'utf8'))
  const storeConfig = JSON.parse(fs.readFileSync(path.join(root, 'windows', 'store', 'store.config.json'), 'utf8'))
  const latest = fs.readFileSync(latestYml, 'utf8')
  const results = []

  async function record(asset, check, verify) {
    try {
      results.push({ asset, check, status: 'PASS', detail: await verify() })
    } catch (error) {
      results.push({ asset, check, status: 'FAIL', detail: error.message })
    }
  }

  await record('DMG', 'hdiutil verify', () => {
    run('hdiutil', ['verify', dmg])
    return 'valid'
  })

  await record('EXE', 'size / SHA-512', async () => {
    const latestVersion = latestYmlValue(latest, 'version')
    if (latestVersion !== version) fail(`latest.yml says ${latestVersion}, expected ${version}.`)

    const installerPath = latestYmlValue(latest, 'path')
    if (path.basename(installerPath) !== 'Toolbox-Setup.exe') {
      fail(`latest.yml path is ${installerPath}, expected Toolbox-Setup.exe.`)
    }

    const sizeMatch = latest.match(/^\s+size:\s*(\d+)\s*$/m)
    if (!sizeMatch) fail('latest.yml has no size.')
    const size = fs.statSync(exe).size
    if (String(size) !== sizeMatch[1]) fail(`Installer is ${size} bytes, latest.yml says ${sizeMatch[1]}.`)

    const expectedSha512 = latestYmlValue(latest, 'sha512')
    const actualSha512 = await hashFile(exe, 'sha512', 'base64')
    if (actualSha512 !== expectedSha512) fail('SHA-512 does not match latest.yml.')

    return `${size} bytes, SHA-512 matches latest.yml`
  })

  await record('AppX', 'SHA-256', async () => {
    const appxName = path.basename(appx)
    const actual = await hashFile(appx, 'sha256')
    const expected = fs
      .readFileSync(checksums, 'utf8')
      .split(/\r?\n/)
      .map(line => line.trim().split(/\s+/))
      .find(parts => parts[1]?.replace(/^\*/, '') === appxName)?.[0]

    if (!expected || !/^[0-9a-f]{64}$/i.test(expected)) {
      fail(`SHA256SUMS.txt has no valid entry for ${appxName}.`)
    }
    if (actual !== expected.toLowerCase()) fail(`SHA-256 mismatch: ${actual} != ${expected.toLowerCase()}.`)
    return actual
  })

  await record('AppX', 'manifest', () => checkManifest(appx, packageJson, storeConfig, version))

  const checkWidth = Math.max(4, ...results.map(result => result.check.length))
  console.log('')
  console.log(`${'STATUS'.padEnd(7)}${'ASSET'.padEnd(6)}${'CHECK'.padEnd(checkWidth + 2)}DETAIL`)
  for (const result of results) {
    const detail = String(result.detail).replace(/\s*\n\s*/g, ' | ')
    console.log(`${result.status.padEnd(7)}${result.asset.padEnd(6)}${result.check.padEnd(checkWidth + 2)}${detail}`)
  }

  const failed = results.filter(result => result.status === 'FAIL')
  console.log('')
  if (failed.length) {
    console.error(`Result: FAIL (${failed.length} failed, ${results.length - failed.length} passed)`)
    for (const result of failed) {
      console.error(`${result.asset} ${result.check}: ${result.detail}`)
    }
    process.exitCode = 1
  } else {
    console.log(`Result: PASS (${results.length} passed)`)
  }
}

main().catch(error => {
  console.error(`Error: ${error.message}`)
  process.exit(1)
})
