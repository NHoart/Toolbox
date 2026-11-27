# Toolbox – Microsoft Store submission status

As of: **27 November 2026**

## Summary

**Toolbox 3.7.2 is certified and published in the Microsoft Store since
21 November 2026.** The Store page is live and publicly reachable:

<https://apps.microsoft.com/detail/9P4FPTHZHVJD>

3.7.2 was built from commit `dca01d1`, before the brand header change. Its title
bar therefore still shows the old header, while the live screenshots already show
the new one.

**Submission 4 is in certification:** `Toolbox-3.7.3.appx` (version `3.7.3.0`,
x64, SHA256
`4fb97cb4368328304efdc7d0e4ea7921632cbba0d8612250ce96dc0b0db6c756`) was built
from commit `ab5c0f5` by workflow run `44847964079` on 21 November 2026. It adds
the brand header and keeps the Store Settings without an Updates section, so the
app will match the screenshots. Submission 4 (`1152921505702465324`) was
submitted for certification on 21 November 2026.

**3.7.4 supersedes 3.7.3:** the water-sync fix in 3.7.4 also applies to the
Store version. Once the `v3.7.4` tag has built `Toolbox-3.7.4.appx` (version
`3.7.4.0`), submit it as the next submission; until then Submission 4 (3.7.3)
remains the newest submitted package and may still pass certification first.

## Partner Center

| Field | Value |
| --- | --- |
| Product ID | `9P4FPTHZHVJD` |
| Submission ID | `1152921505702465324` (Submission 4) |
| Product name | Toolbox for Windows |
| Status | **Update in certification** |
| Store page | live (3.7.2) |
| Package | `Toolbox-3.7.3.appx` – validated |
| Package version | `3.7.3.0`, x64 |
| Device family | Windows 10/11 Desktop, at least `10.0.17763.0` |
| Submission last changed | 21 November 2026 |
| Publication | immediately after certification |
| Age ratings | USK 0, PEGI 3, ESRB Everyone, IARC 3+, Microsoft Store 3+ |

## AppX build

- Workflow: **Microsoft Store (AppX)**
- Ref: `main` at commit `ab5c0f5`
- Run: `44847964079` – **success**
- File: `Toolbox-3.7.3.appx` (156.1 MB)
- SHA256: `4fb97cb4368328304efdc7d0e4ea7921632cbba0d8612250ce96dc0b0db6c756`
- Manifest: identity `NHoartApps.ToolboxforWindows`, version `3.7.3.0`, `x64`,
  languages `en-US`, `de-DE`, `es-ES`, `fr-FR` (`en-US` first)
- Includes the new brand header (`brand-tagline`) and the Store build’s removed
  Updates section

The 3.7.2 package from run `44573892233` (commit `dca01d1`) predates the brand
header and is historical. The `v3.7.1` artifact predates the Settings change and
must not be reused.

## Store listings

| Language | Language ID | Status | Screenshots |
| --- | --- | --- | --- |
| German (Germany) | `14` | Complete | 6 |
| English (United States) | `4` | Complete | 6 |
| Spanish (Spain) | `15` | Complete | 6 |
| French (France) | `19` | Complete | 6 |

All four listings are localized and use the six Windows-rendered screenshots
(2464 × 1648) under `windows/store/screenshots/<language>/`. The “What’s new”
texts for 3.7.3 mention the new brand header and the unchanged Store update
behaviour (no Updates section in Settings).

The screenshot set from 19 November 2026 was rejected in certification on
20 November 2026 (policy **10.1.1.3, Inaccurate Representation**) because it had
been captured from the Mac app and showed macOS window controls. The current set
is rendered from the Windows interface, including the Windows title bar and the
app logo.

## Remaining steps

1. Set `STORE_URL` as a repository variable
   (Settings → Secrets and variables → Actions → Variables) to
   `https://apps.microsoft.com/detail/9P4FPTHZHVJD` – **still open**. The release
   notes then include the Store row automatically.
2. Wait for Submission 4 (3.7.3) to pass certification; the Store publishes it
   automatically and replaces the live 3.7.2.
3. Submit `Toolbox-3.7.4.appx` (version `3.7.4.0`) as the next submission once
   the `v3.7.4` build has finished; it contains the water-sync fix.
4. Future Store versions need their own submission; the procedure is described in
   [`windows/store/README.md`](windows/store/README.md).

## History

| Date | Event |
| --- | --- |
| 16 Nov 2026 | `Toolbox-3.4.0.appx` validated and submitted |
| 17 Nov 2026 | 3.4.0 certified and published |
| 18 Nov 2026 | 3.6.0 certified and published |
| 19 Nov 2026 | Submission 3 resubmitted with `Toolbox-3.7.2.appx` |
| 20 Nov 2026 | Submission 3 rejected under 10.1.1.3 (macOS screenshots) |
| 21 Nov 2026 | Windows-rendered screenshots uploaded; Submission 3 passed certification and 3.7.2 published |
| 21 Nov 2026 | `Toolbox-3.7.3.appx` built from `ab5c0f5`; Submission 4 submitted for certification |
| 27 Nov 2026 | 3.7.4 fixes the water sync (separate timestamps for amounts and sizes); AppX build and Submission 5 pending |

## Checks performed

- GitHub Actions run `44847964079`: **success**
- `npm test`: **45/45 passed**
- AppX SHA256 matches `SHA256SUMS.txt`
- Manifest checked: identity, version `3.7.3.0`, `x64`, four languages, `en-US`
  first
- AppX contents checked: `brand-tagline` present and `updateCard` hidden
- Partner Center: package **Validated**, languages supported in packages
  **Updated**
- Store listings: all four languages complete, six screenshots each, 3.7.3
  “What’s new” texts saved
- Submission 4: **Update in certification**
