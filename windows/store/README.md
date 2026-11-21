# Microsoft Store

The Store version is an **additional** way to install the app. DMG and EXE stay
unchanged; the Store version uses the same sync engine and the same local data.

## Status

**Published:** Toolbox 3.6.0 is certified and has been available in the
Microsoft Store since 18 November 2026.

- Store page: <https://apps.microsoft.com/detail/9P4FPTHZHVJD>
- Package: `Toolbox-3.6.0.appx`, version `3.6.0.0`, x64
- First submission (`1152921505702409983`) certified 3.4.0 on 17 Nov 2026
- 3.6.0 certified and published on 18 Nov 2026
- Partner Center: “In Microsoft Store”, available for Windows 10/11 Desktop

Newer GitHub releases do not automatically reach the Store; every Store version
needs its own submission (section 6). 3.5.0 and 3.6.1 were deliberately not
submitted.

**Submission 3 (in certification):** `Toolbox-3.7.2.appx`
(version `3.7.2.0`, x64, SHA256
`d70d8ba6cec176f7f105b0949c0e025d22b9f670e960ba8bb8cecca16d0a5583`) was built
from commit `dca01d1` by workflow run `44573892233` on 19 Nov 2026 and contains
the Settings change. Submission 3 (`1152921505702451589`) was cancelled and
re-submitted on 19 Nov 2026 with this package. It was rejected on 20 Nov 2026
(policy 10.1.1.3) and resubmitted on 21 Nov 2026 with the Windows-rendered
screenshots; it is now in certification. The four “What's new” texts and the
updated certification notes are stored in the submission.

## One-time setup

### 1. Reserve the developer account and name

1. Create an **individual account** at <https://storedeveloper.microsoft.com>.
   It is free but requires identity verification with an ID and a selfie.
2. Reserve the product name in Partner Center under **Apps and games → New
   product** – **Toolbox for Windows** is reserved for this product. If a name is
   taken, pick a unique one; the display name in the package stays
   “Toolbox for Windows”.
3. Copy these values under **Package/Identity**:
   - `Package/Identity/Name` → `identityName`
   - `Package/Identity/Publisher` → `publisher`

### 2. Enter the Store identity

`windows/store/store.config.json` is already filled in for this product:

```json
{
  "identityName": "NHoartApps.ToolboxforWindows",
  "publisher": "CN=4C6F0CE5-5A19-4199-945D-0218158D3762",
  "publisherDisplayName": "NHoartApps",
  "applicationId": "Toolbox",
  "displayName": "Toolbox for Windows",
  "storeId": "9P4FPTHZHVJD"
}
```

`identityName` and `publisher` must match the Partner Center values **exactly**.
The Store re-signs the package later; a certificate of your own is not needed.

The values are already set for this product:

| Field | Value |
| --- | --- |
| `identityName` | `NHoartApps.ToolboxforWindows` |
| `publisher` | `CN=4C6F0CE5-5A19-4199-945D-0218158D3762` |
| `publisherDisplayName` | `NHoartApps` |
| `displayName` | `Toolbox for Windows` |
| Store ID | `9P4FPTHZHVJD` |

### 3. Build the AppX

The **Microsoft Store (AppX)** workflow builds the package on `windows-latest`.
It runs on every `v*` tag push and manually via **Actions → Microsoft Store
(AppX) → Run workflow**. The Store build pins `toolsets.winCodeSign` to `1.1.0`
(Windows Kits 10.0.26100.0); the old `winCodeSign-2.6.0` toolchain is no longer
reliable for AppX on current Windows runners. It also removes the GitHub
`publish` configuration from the NSIS build; publishing happens exclusively
through the workflow. On failure the workflow writes the last lines of the build
log into the job summary.

- The Store build **always** writes `en-US`, `de-DE`, `es-ES` and `fr-FR` into
  the AppX manifest, with `en-US` first: the first entry is the package's
  default language and the fallback Windows uses when none of the user's
  languages is supported. The central list lives in
  `windows/scripts/appx-languages.js`; `windows/package.json` and the build must
  contain exactly these four languages, otherwise the build aborts.
- After the build, `windows/scripts/verify-appx.ps1` checks the finished
  package: identity, package version, `x64`, **exactly** the four languages and
  `en-US` as the first (default) entry. Any deviation fails the workflow before
  an artifact is uploaded.
- The run stores the artifact **Toolbox-appx**, containing
  `Toolbox-<version>.appx` and `SHA256SUMS.txt`.
- Before the real identity is entered, **Test build with placeholder identity**
  can verify the packaging. That package **cannot** be submitted to the Store and
  is called **Toolbox-appx-test**.
- Check locally: `cd windows && npm run dist:store -- --check` (also shows the
  four languages).
- Build locally: `npm run dist:store` (requires Windows or Parallels), then run
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-appx.ps1`.

The existing `windows-exe.yml` workflow is unchanged. The Store version is
**not** published as a GitHub release asset.

### 4. Upload the AppX to Partner Center

Current state (19 Nov 2026): Submission 3 (`1152921505702451589`) was cancelled
while in certification and re-submitted the same day with
`Toolbox-3.7.2.appx` (version `3.7.2.0`, checksum above). It is now in
certification; the Store continues to serve 3.6.0 until it passes. The steps
below describe the flow of a submission and apply unchanged to later versions.

1. **Start the workflow:** **Actions → Microsoft Store (AppX) → Run workflow**.
   For a release a `v<version>` tag is enough; the workflow then runs
   automatically. Wait until the run is green and the **Verify AppX manifest**
   step has confirmed the four languages.
2. **Download the artifact:** Open the run and download **Toolbox-appx** under
   **Artifacts**. Unpack it. Do **not** use the `Toolbox-appx-test` artifact from
   a test build.
3. **Verify the file:** On Windows, compare the checksum:

   ```powershell
   Get-FileHash (Get-ChildItem .\Toolbox-*.appx).FullName -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```

   Only the downloaded AppX should be in the folder. Both SHA256 values must
   match. Optionally verify the manifest again (in the repository under
   `windows`):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-appx.ps1 -Path (Get-ChildItem .\Toolbox-*.appx).FullName
   ```

4. **Open Partner Center:** **Apps and games → Toolbox for Windows →
   Submission → Packages**.
5. **Replace the old package:** If a package of an earlier version is still in
   the submission, remove it through the package actions and wait until it is no
   longer listed.
6. **Upload the new package:** Choose **Upload package** and select
   `Toolbox-<version>.appx`. Do **not** upload a certificate; the Store signs
   the package on submission. Wait until the status reads **Validated**.
7. **Check the languages:** Under **Languages supported in packages**,
   **German, English, Spanish and French** must be listed. If one is missing, do
   not submit: check the artifact and the workflow log and start the build
   again.
8. **Save the submission:** The remaining details stay unchanged. Only continue
   with section 5 once the package is validated and the four languages are shown.

### 5. Review and submit the remaining submission details

The first submission cannot be created through the API and must be done
manually:

1. **Properties**: category **Productivity**, system requirement
   **Windows 10 (1809) or newer, 64-bit**.
2. **Age rating**: no content harmful to minors (3+).
3. **Pricing**: free.
4. **Store listing**: values from [Submission: texts and details](#submission-texts-and-details).
5. **Privacy policy**: <https://github.com/NHoart/Toolbox/blob/main/PRIVACY.md>
6. **Support**: <https://github.com/NHoart/Toolbox/issues>
7. **Submit for certification** and wait for the certification.

After publication, store the Store URL
`https://apps.microsoft.com/detail/<StoreId>` as the repository variable
**`STORE_URL`** (Settings → Secrets and variables → Actions → Variables). The
release notes of new releases then automatically add a Store row to the
installation table. Without `STORE_URL` the row stays empty.

### 6. Later updates

1. Bump `version` in `windows/package.json` and push a `v<version>` tag.
2. The Store workflow builds the new `.appx` and checks the four languages.
3. Download the artifact, compare the checksum and upload the `.appx` to Partner
   Center as a new submission (steps from section 4).
4. The Store updates installed apps; `electron-updater` is disabled in the Store
   version.

The submission with the Settings change (no Updates section in the Store build)
uses `Toolbox-3.7.2.appx` from run `44573892233` (commit `dca01d1`), uploaded to
Submission 3 on 19 Nov 2026. The existing `v3.7.1` artifact was built before
that change and must not be reused for it.

Later automation can use the Microsoft Store Developer CLI with an Entra ID app.
That requires seller ID, tenant ID, client ID and client secret; these
credentials do not belong in the repository.

## Sync and data

- The package declares `runFullTrust` and `privateNetworkClientServer`.
  Bonjour/mDNS and TCP work as in the EXE version.
- On first launch of the Store version, an existing
  `%APPDATA%\Toolbox\data.json` is copied into the packaged AppData area if no
  file exists there yet. The EXE installation stays untouched. Close the EXE
  beforehand so the most recent state is taken over.
- Test on a real Windows PC: start the Store app, allow access for **Private
  networks**, enter the same sync name as on Mac/iPhone and sync with all three
  variants.
- The Store version needs no internet connection for syncing. The Windows network
  profile must be “Private”.

## Submission: texts and details

All values for the first submission, in the order of Partner Center. The AppX
declares `de-DE`, `en-US`, `es-ES` and `fr-FR`; the app interface follows the
Windows language and falls back to **English** for other languages. In Settings
the language can additionally be set manually to German, English, Spanish or
French; **System language** keeps following Windows. The Store listings also
exist in English (United States), Spanish (Spain) and French (France). Product
ID: `9P4FPTHZHVJD`.

> **Important:** `Toolbox-3.6.0.appx` was certified with the four languages and
> has been published in the Store since 18 Nov 2026; it contains the manual
> language choice. 3.3.2 was removed from the submission. The build runs on
> Windows or through the **Microsoft Store (AppX)** workflow; it is not possible
> on macOS.

### Store listing (de-DE)

The German listing stays in German on purpose; it is the localized Store entry.

**Product name:** `Toolbox for Windows` (reserved) · **Display name in the
package:** `Toolbox for Windows`. Listing and package names are therefore
identical.

**Short description (under 270 characters):**

> Wassertracker, Zähler, Einheitenrechner und Alltagswerkzeuge – mit Abgleich
> im lokalen WLAN zwischen Windows, Mac und iPhone.

**Description:**

> Toolbox bündelt sechs Alltagswerkzeuge in einer App – ohne Konto, ohne Cloud
> und ohne Server.
>
> • Wassertracker: Tagesziel, Fortschrittsring, Schnellwahl für Glas und
> Flasche sowie Verlauf der letzten 30 Tage
> • Zähler: Plus/Minus, Undo, Reset, Auto-Zählmodus und benannte, gespeicherte
> Zählerstände
> • Einheiten: Umrechnung zwischen MB/GB und Mbit/MB
> • Downloadzeit: geschätzte Dauer aus Dateigröße und Geschwindigkeit
> • Stromverbrauch: Energie aus Leistung und Nutzungsdauer, optional mit
> Kosten zum eigenen kWh-Preis
> • Lokaler Abgleich: Windows, Mac und iPhone tauschen Wasser- und
> Zählerstände direkt im WLAN aus
>
> Alle Daten bleiben auf den Geräten. Es gibt kein Benutzerkonto, keine
> Anmeldung, keine Telemetrie und keine Werbung. Der Abgleich läuft nur im
> lokalen Netzwerk und ist nicht zusätzlich verschlüsselt; dafür auf allen
> Geräten denselben Sync-Namen eintragen.
>
> Die Windows-Fassung läuft unter Windows 10 (Version 1809) oder neuer, 64 Bit.
> Updates kommen über den Microsoft Store.

**Product features (max. 20, 200 characters each):**

1. Wassertracker mit Tagesziel, Fortschrittsring und Verlauf der letzten 30 Tage
2. Schnellwahl für Glas und Flasche sowie frei wählbare Menge von 1 bis 10.000 ml
3. Zähler mit Plus/Minus, Undo, Reset, Auto-Zählmodus und gespeicherten Zählerständen
4. Einheitenrechner für MB/GB und Mbit/MB
5. Downloadzeit-Rechner aus Dateigröße und Geschwindigkeit
6. Stromverbrauchsrechner mit optionaler Kostenberechnung zum eigenen kWh-Preis
7. Abgleich im lokalen WLAN zwischen Windows, Mac und iPhone – ohne Konto und ohne Cloud
8. Alle Daten bleiben lokal: keine Telemetrie, keine Werbung

**Keywords (max. 7, 40 characters each, 21 words total):**

`Wassertracker` · `Wasser trinken` · `Zähler` · `Einheitenrechner` ·
`Downloadzeit berechnen` · `Stromverbrauch berechnen` · `WLAN Sync`

**Copyright:** © 2026 Noah Hartmann  
**Developed by:** Noah Hartmann  
**Support:** <https://github.com/NHoart/Toolbox/issues>  
**Website:** <https://github.com/NHoart/Toolbox>  
**Privacy policy:** <https://github.com/NHoart/Toolbox/blob/main/PRIVACY.md>  
**Additional license terms:** Proprietary – all rights reserved. The source code
is publicly readable; use and redistribution are governed by the LICENSE in the
repository: <https://github.com/NHoart/Toolbox/blob/main/LICENSE>  
**Store logo:** `windows/store/StoreListingIcon.png` (300 × 300, 1:1)  
**Screenshots:** six PNGs each (2464 × 1648) uploaded per language in the Store
listing. The files live under `windows/store/screenshots/<language>/`
(`de`, `en`, `es`, `fr`); motifs in tab order: today (water tracker), history,
units, counter, download time and power usage.  
**What's new in this version:** empty for the first submission. For the next
submission, which removes the Updates section from the Store build, use:

- de-DE: `Die Einstellungen zeigen in der Store-Fassung keinen Update-Bereich mehr; Updates kommen automatisch über den Microsoft Store.`
- en-US: `The Store version no longer shows an Updates section in Settings; updates are delivered automatically by the Microsoft Store.`
- es-ES: `La versión de Store ya no muestra una sección de actualizaciones en Ajustes; las actualizaciones llegan automáticamente a través de Microsoft Store.`
- fr-FR: `La version Store n'affiche plus de section Mises à jour dans les paramètres ; les mises à jour sont fournies automatiquement par le Microsoft Store.`

### Additional Store listings (en-US, es-ES, fr-FR)

The **English (United States)**, **Spanish (Spain)** and **French (France)**
listings are complete and each has six language-specific screenshots.
Descriptions, short descriptions, eight features each, seven keywords each as
well as copyright, license and developer details are translated. The earlier
notes about a German-only interface were removed once the app was localized to
de/en/es/fr.

The screenshots show the interface in the respective Store language. The images
were produced with the localized app; the German listing still uses the German
screenshots.

The set from 19 November 2026 was rejected in certification on 20 November 2026
(policy **10.1.1.3, Inaccurate Representation**): it had been captured from the
Mac app and showed macOS window controls. The screenshots are now rendered from
the Windows interface, including the Windows title bar and the app logo, at
2464 × 1648. Regenerate them from `windows` with:

```bash
node_modules/.bin/electron scripts/capture-store-screenshots.js
```

The script renders the six tabs in German, English, Spanish and French and
writes them to `windows/store/screenshots/<language>/`. Upload the new set for
all four languages; the live listing keeps the older set until the corrected
submission passes certification.

The **package languages** in `windows/package.json` are `de-DE`, `en-US`,
`es-ES` and `fr-FR`. The AppX `Toolbox-3.6.0.appx` validated in Partner Center
contains these four languages and adds the manual language choice.

### Pricing and availability

| Field | Value |
| --- | --- |
| Price | Free |
| Free trial | No |
| In-app purchases | No |
| Markets | All markets where the Microsoft Store is available |
| Device family | Windows 10/11 (Desktop), x64 |
| Publication | Immediately after certification – published on 17 Nov 2026 |
| Sale prices/offers | None |

### Properties

**Category:** Productivity (no subcategory)

**System requirements:**

| Field | Value |
| --- | --- |
| Operating system | Windows 10, version 1809 (build 17763) or newer |
| Architecture | x64 |
| Memory | 4 GB (recommended) |
| DirectX | Not required |
| Graphics | Not required |
| Free disk space | about 400 MB (recommended) |

**Additional system requirements (max. 11, 200 characters each):**

- For syncing over the local Wi-Fi network: the same network with the “Private”
  profile, permission for private networks in the Windows firewall and the same
  sync name on all devices.
- An internet connection is only needed for updates from the Microsoft Store;
  all tools and the sync work offline.

**Capability justifications (if requested in Partner Center):**

- `runFullTrust`: Toolbox is an Electron desktop app that runs as a fully
  trusted Win32 application outside the UWP sandbox. The capability is required
  to run the interface, the local storage under `%APPDATA%\Toolbox` and the
  device sync.
- `privateNetworkClientServer`: The optional sync uses Bonjour/mDNS and TCP on
  the local network to exchange water and counter values between Windows, Mac
  and iPhone. No data is transmitted to the internet; without a sync name the
  sync is inactive.

**Age rating (IARC):** questionnaire answered completely with “No” and saved.
Result: USK 0 (“Approved without age restriction”), PEGI 3, ESRB Everyone,
IARC 3+, Microsoft Store 3+. The IARC terms of use were accepted.

### Submission options

- **Device family:** Windows 10/11, x64 (no Xbox version)
- **Discoverability:** show in search results and when browsing the Store, not
  only via direct link
- **Publication:** immediately after successful certification
- **Justification for `runFullTrust` (max. 500 characters):**

> Toolbox is an Electron-based MSIX desktop app. runFullTrust is required to
> launch the packaged desktop executable and its bundled Chromium/Node.js
> runtime; without it the app cannot start. The app stores data locally and
> uses privateNetworkClientServer only for optional LAN sync between the
> user's own devices. It installs no services, drivers, or background
> components, requires no admin rights, and does not bypass Store policies.

- **Notes for certification:**

> Toolbox is an Electron desktop app (Win32, x64) without sign-in and without a
> cloud. The Store build has no Updates section in Settings; the Microsoft Store
> delivers all updates and the app does not check GitHub. On first launch
> Windows may ask for the firewall permission for private networks; it is only
> needed for the optional device sync via Bonjour/mDNS and TCP and can be
> declined without restricting the other features. The sync is inactive without
> a sync name. One device is enough to review the app; syncing requires two
> devices on the same Wi-Fi network with an identical sync name. No data is sent
> to third parties and no telemetry is collected.

### Before submitting

- [x] Upload the original five screenshots per language
- [x] Answer the IARC questionnaire completely and save the age ratings
- [x] Fill in pricing and availability, properties, Store listing and submission options
- [x] Upload and validate AppX 3.3.2 (`Toolbox-3.3.2.appx`)
- [x] Remove 3.3.2 from the submission; 3.4.0 remains the only package
- [x] Complete the additional en-US and es-ES Store listings
- [x] Build the app localization de/en/es/fr into the renderer
- [x] Complete the additional fr-FR Store listing
- [x] Store build declares and verifies `de-DE`, `en-US`, `es-ES`, `fr-FR`
- [x] Replace the screenshots per language with captures of the localized UI
- [x] Build the new AppX 3.4.0 with de/en/es/fr
- [x] Upload and validate `Toolbox-3.4.0.appx` in Partner Center
- [x] Submit on 16 Nov 2026, certified and published on 17 Nov 2026
- [x] Build, validate and publish `Toolbox-3.6.0.appx` on 18 Nov 2026
- [ ] Set `STORE_URL` as a repository variable
      (`https://apps.microsoft.com/detail/9P4FPTHZHVJD`) – still open
- [x] Replace the Store screenshots in Partner Center with the six-tab set
      (Submission 3, 19 Nov 2026, all four languages)
- [x] Build `Toolbox-3.7.2.appx` from commit `dca01d1` with the Settings
      change (run `44573892233`, checksum verified)
- [x] Cancel Submission 3 and re-submit it with `Toolbox-3.7.2.appx`
      (19 Nov 2026)
- [x] Enter the "What's new" texts above in the four Store listings
- [x] Update the certification notes with the removed Updates section
- [x] Submit Submission 3 for certification (rejected 20 Nov 2026, 10.1.1.3)
- [x] Re-render the six screenshots per language from the Windows interface
      (21 Nov 2026, `scripts/capture-store-screenshots.js`)
- [x] Upload the Windows-rendered screenshots for all four languages and
      resubmit (21 Nov 2026, Submission 3 with `Toolbox-3.7.2.appx`)
