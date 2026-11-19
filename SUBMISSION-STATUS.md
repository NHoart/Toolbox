# Toolbox – Microsoft Store submission status

As of: **17 November 2026**

## Summary

**Toolbox 3.4.0 is certified and has been published in the Microsoft Store since
17 November 2026.** The Store page is live and publicly reachable:

<https://apps.microsoft.com/detail/9P4FPTHZHVJD>

The submission is complete; no steps remain open in Partner Center. The GitHub
release 3.5.0 from 16 November 2026 was deliberately **not** submitted to the
Store – the Store version remains 3.4.0 for now.

## Partner Center

| Field | Value |
| --- | --- |
| Product ID | `9P4FPTHZHVJD` |
| Submission ID | `1152921505702409983` |
| Product name | Toolbox for Windows |
| Status | **In Microsoft Store** (published) |
| Store page | live |
| Package | `Toolbox-3.4.0.appx` – certified and live |
| Package version | `3.4.0.0`, x64 |
| Device family | Windows 10/11 Desktop, at least `10.0.17763.0` |
| Submission last changed | 17 November 2026 |
| Publication | immediately after certification – done |
| Age ratings | USK 0, PEGI 3, ESRB Everyone, IARC 3+, Microsoft Store 3+ |

The Partner Center overview reports “In Microsoft Store” and “Your product is
currently available in the Microsoft Store”. The submission detail page no
longer shows a running certification.

## AppX build

- Workflow: **Microsoft Store (AppX)**
- Tag: `v3.4.0`
- Run: `43838714443` – **success**
- File: `Toolbox-3.4.0.appx` (156.1 MB)
- Manifest: identity `NHoartApps.ToolboxforWindows`, version `3.4.0.0`, `x64`,
  languages `de-DE`, `en-US`, `es-ES`, `fr-FR`

Run `43826611772` on the since-deleted `codex/store-appx-languages` branch
belongs to the earlier 3.3.2 draft and is historical only.

## Store listings

| Language | Language ID | Status | Screenshots |
| --- | --- | --- | --- |
| German (Germany) | `14` | Live | 5 (1 duplicate) |
| English (United States) | `4` | Live | 5 (1 duplicate) |
| Spanish (Spain) | `15` | Live | 5 (1 duplicate) |
| French (France) | `19` | Live | 5 (1 duplicate) |

The Microsoft Store picks the listing that matches the user's language and
region and falls back to English when no listing matches.

## App localization

`windows/renderer/i18n.js`

- Languages: **German, English, Spanish, French**
- System language via `navigator.languages` / `navigator.language`, using the
  first supported entry in the user's preference list
- Manual language choice in Settings; stored in `localStorage`
- Fallback: **English**
- Static and dynamic texts, toasts, dialogs and error messages
- Date, number and currency formatting per locale, including the region
  (`en-GB` keeps British formatting)
- Runtime-checked with Electron for `fr`, `en`, `es`, `de-AT` and the fallback
  for unsupported languages such as `it`

The Apple apps use the same language set: the String Catalogs in
`Toolbox/Localizable.xcstrings` and `ToolboxWidget/Localizable.xcstrings`
contain German, Spanish and French, the development language is English and
`CFBundleDevelopmentRegion` is `en`, so any unsupported system language resolves
to English.

## Screenshots

Six PNGs each (2464 × 1648) per language under
`windows/store/screenshots/<language>/`:

| Store language | Folder | Motifs |
| --- | --- | --- |
| German (Germany) | `de/` | Today, history, units, counter, download time, power usage |
| English (USA) | `en/` | Same motifs, English interface |
| Spanish (Spain) | `es/` | Same motifs, Spanish interface |
| French (France) | `fr/` | Same motifs, French interface |

The live listing still shows five screenshots, with “Units” repeated in slots 1
and 2 and no screenshot for today or history. The recaptured six-tab set was
uploaded for all four languages to Submission 3, which was submitted for
certification on 19 November 2026 and replaces the live set once certification
completes.

## Remaining steps

1. Set `STORE_URL` as a repository variable
   (Settings → Secrets and variables → Actions → Variables) to
   `https://apps.microsoft.com/detail/9P4FPTHZHVJD` – **still open**. The release
   notes then include the Store row automatically.
2. Future Store versions need their own submission; the procedure is described in
   [`windows/store/README.md`](windows/store/README.md).
3. 3.5.0 was not submitted and remains a pure GitHub release (DMG and EXE).
4. Submission 3 is in certification since 19 November 2026. It contains the
   six-tab screenshot set for all four languages (today first); the live listing
   keeps the old set with the duplicated “Units” screenshot until certification
   completes and the update publishes automatically.

## History

| Date | Event |
| --- | --- |
| 16 Nov 2026 | `Toolbox-3.4.0.appx` validated in Partner Center, 3.3.2 removed |
| 16 Nov 2026 | Submission sent for certification |
| 17 Nov 2026 | Certification passed, app published in the Microsoft Store |

## Checks performed

- Partner Center overview (17 Nov 2026): **In Microsoft Store**, product available
- Partner Center packages: `Toolbox-3.4.0.appx`, `v3.4.0.0`, x64, Windows.Desktop
- Store page: publicly reachable, title, publisher, category and USK checked
- GitHub Actions run `43838714443`: **success**
- `npm test`: **42/42 passed**
- `npm run dist:store -- --check`: **Store configuration OK**
- Manifest inside the AppX: **four languages, identity and version OK**
- Submission: **complete and published**
