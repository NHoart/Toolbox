#!/usr/bin/env node
"use strict";

// Erzeugt das winget-Manifest-Set passend zum gebauten Installer. Version kommt
// aus windows/package.json, die SHA256 aus der tatsächlich gebauten Datei.

const { createHash } = require("node:crypto");
const { createReadStream, existsSync, mkdirSync, readFileSync, statSync, writeFileSync } = require("node:fs");
const path = require("node:path");

const WINDOWS_DIR = path.join(__dirname, "..");
const INSTALLER = path.join(WINDOWS_DIR, "dist", "Toolbox-Setup.exe");
const OUTPUT_ROOT = path.join(WINDOWS_DIR, "dist", "winget", "manifests", "n", "NHoart", "Toolbox");

const PACKAGE_IDENTIFIER = "NHoart.Toolbox";
const MANIFEST_VERSION = "1.28.0";

function fail(message) {
  console.error(`winget: ${message}`);
  process.exit(1);
}

async function sha256(file) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(file)) {
    hash.update(chunk);
  }
  return hash.digest("hex").toUpperCase();
}

async function main() {
  const pkg = JSON.parse(readFileSync(path.join(WINDOWS_DIR, "package.json"), "utf8"));
  const version = pkg.version;

  if (!/^\d+\.\d+\.\d+$/.test(version || "")) {
    fail(`Ungültige Version in windows/package.json: ${version}`);
  }
  if (!existsSync(INSTALLER)) {
    fail(`Installer fehlt: ${INSTALLER} – zuerst "npm run dist" ausführen.`);
  }

  const digest = await sha256(INSTALLER);
  const tag =
    process.env.GITHUB_REF_TYPE === "tag" && process.env.GITHUB_REF_NAME
      ? process.env.GITHUB_REF_NAME
      : `v${version}`;
  const releaseDate = new Date().toISOString().slice(0, 10);
  const installerUrl = `https://github.com/NHoart/Toolbox/releases/download/${tag}/Toolbox-Setup.exe`;
  const outputDir = path.join(OUTPUT_ROOT, version);

  const header = (type) =>
    `# yaml-language-server: $schema=https://aka.ms/winget-manifest.${type}.${MANIFEST_VERSION}.schema.json`;

  const versionManifest = `${header("version")}

PackageIdentifier: ${PACKAGE_IDENTIFIER}
PackageVersion: ${version}
DefaultLocale: de-DE
ManifestType: version
ManifestVersion: ${MANIFEST_VERSION}
`;

  const installerManifest = `${header("installer")}

PackageIdentifier: ${PACKAGE_IDENTIFIER}
PackageVersion: ${version}
Platform:
  - Windows.Desktop
MinimumOSVersion: 10.0.17763.0
InstallerType: nullsoft
Scope: user
InstallModes:
  - interactive
  - silent
UpgradeBehavior: install
ReleaseDate: ${releaseDate}
Installers:
  - Architecture: x64
    InstallerUrl: ${installerUrl}
    InstallerSha256: ${digest}
ManifestType: installer
ManifestVersion: ${MANIFEST_VERSION}
`;

  const localeManifest = `${header("defaultLocale")}

PackageIdentifier: ${PACKAGE_IDENTIFIER}
PackageVersion: ${version}
PackageLocale: de-DE
Publisher: Noah Hartmann
PublisherUrl: https://github.com/NHoart
PublisherSupportUrl: https://github.com/NHoart/Toolbox/issues
PackageName: Toolbox
PackageUrl: https://github.com/NHoart/Toolbox
License: Proprietär
LicenseUrl: https://github.com/NHoart/Toolbox/blob/main/LICENSE
Copyright: © ${new Date().getUTCFullYear()} Noah Hartmann
ShortDescription: Sechs Alltagswerkzeuge für Windows – Wassertracker, Einheiten, Zähler, Downloadzeit, Stromverbrauch und WLAN-Abgleich.
Description: >-
  Toolbox bündelt sechs Alltagswerkzeuge in einer App: einen Wassertracker mit
  Verlauf, Umrechner für Einheiten und Downloadzeiten, einen Zähler sowie einen
  Stromverbrauchsrechner. Alle Daten bleiben lokal und lassen sich im eigenen
  WLAN mit Mac und iPhone abgleichen.
Tags:
  - wasser
  - tracker
  - umrechner
  - zaehler
  - downloadzeit
  - stromverbrauch
  - sync
ReleaseNotesUrl: https://github.com/NHoart/Toolbox/releases/tag/${tag}
ManifestType: defaultLocale
ManifestVersion: ${MANIFEST_VERSION}
`;

  mkdirSync(outputDir, { recursive: true });
  writeFileSync(path.join(outputDir, `${PACKAGE_IDENTIFIER}.yaml`), versionManifest);
  writeFileSync(path.join(outputDir, `${PACKAGE_IDENTIFIER}.installer.yaml`), installerManifest);
  writeFileSync(path.join(outputDir, `${PACKAGE_IDENTIFIER}.locale.de-DE.yaml`), localeManifest);

  console.log(`winget-Manifeste für ${version} geschrieben: ${outputDir}`);
  console.log(`Tag ${tag}, Installer ${statSync(INSTALLER).size} Bytes, SHA256 ${digest}`);
}

main().catch((error) => {
  fail(error.stack || String(error));
});
