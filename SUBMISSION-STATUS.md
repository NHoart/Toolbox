# Toolbox – Status der Microsoft-Store-Einreichung

Stand: **16. November 2026**

## Kurzfassung

Die neue Store-Fassung **Toolbox 3.3.2** wurde auf Windows gebaut, geprüft und
im Partner Center hochgeladen. Das Paket ist **Validated**; das alte
`Toolbox-3.3.1.appx` wurde aus dem Entwurf entfernt.

Die App-Oberfläche ist für **Deutsch, Englisch, Spanisch und Französisch**
lokalisiert. Das AppX deklariert alle vier Sprachen. Es wurde **nichts zur
Zertifizierung übermittelt**.

## Partner Center

| Feld | Wert |
| --- | --- |
| Produkt-ID | `9P4FPTHZHVJD` |
| Submission-ID | `1152921505702409983` |
| Produktname | Toolbox for Windows |
| Paket | `Toolbox-3.3.2.appx` – **Validated** |
| Paketversion | `3.3.2.0`, x64 |
| Altes Paket | `Toolbox-3.3.1.appx` entfernt |
| Preise und Verfügbarkeit | Vollständig |
| Eigenschaften | Vollständig |
| Altersfreigaben | Vollständig / Complete |
| Pakete | Vollständig |
| Store-Einträge | Vollständig |
| Übermittlungsoptionen | Vollständig |
| Submit-Button | aktiv |
| Einreichung abgesendet | **Nein** |

Altersfreigaben: USK 0, PEGI 3, ESRB Everyone, IARC 3+, Microsoft Store 3+.
Veröffentlichung ist auf „sofort nach erfolgreicher Zertifizierung“ gesetzt.

## AppX-Build

- Workflow: **Microsoft Store (AppX)**
- Branch: `codex/store-appx-languages`
- Commit: `dbfd8fe`
- Lauf: `43826611772` – **success**
- Artefakt: **Toolbox-appx**
- Datei: `Toolbox-3.3.2.appx` (156 MB)
- SHA256:
  `6ddb71227788240ccc59a2f85e1125a1bfb37e6a9350ae3bb76c27b1d979fc8d`

Manifestprüfung im Workflow und lokal:

```text
Identity:  NHoartApps.ToolboxforWindows
Version:   3.3.2.0
Architektur: x64
Sprachen:  de-DE, en-US, es-ES, fr-FR
```

Der Store-Build verwendet `toolsets.winCodeSign: 1.1.0` und entfernt die
GitHub-Publish-Konfiguration aus dem NSIS-Build. Die zentrale Sprachliste steht
in `windows/scripts/appx-languages.js`; der Workflow prüft das erzeugte
Manifest mit `windows/scripts/verify-appx.ps1` und erzeugt `SHA256SUMS.txt`.

## Store-Einträge

| Sprache | Sprach-ID | Status | Screenshots |
| --- | --- | --- | --- |
| Deutsch (Deutschland) | `14` | Abgeschlossen | 5 |
| Englisch (Vereinigte Staaten) | `4` | Abgeschlossen | 5 |
| Spanisch (Spanien) | `15` | Abgeschlossen | 5 |
| Französisch (Frankreich) | `19` | Abgeschlossen | 5 |

Der französische Eintrag enthält eine vollständige Beschreibung, 8 Features,
7 Keywords sowie Copyright-, Lizenz- und Entwicklerangaben.

## App-Lokalisierung

Neu: `windows/renderer/i18n.js`

- Sprachen: **Deutsch, Englisch, Spanisch, Französisch**
- Systemsprache über `navigator.language` / `navigator.languages`
- manuelle Sprachwahl in den Einstellungen; gespeichert in `localStorage`
- Fallback: **Deutsch**
- statische und dynamische Texte, Toasts, Dialoge und Fehlermeldungen
- Datums-, Zahlen- und Währungsformatierung je Locale
- Laufzeit geprüft mit Electron für `fr`, `en`, `es` und Fallback `it`

## Screenshots

Je fünf PNGs (2464 × 1648) pro Sprache unter
`windows/store/screenshots/<sprache>/`:

| Store-Sprache | Ordner | Motive |
| --- | --- | --- |
| Deutsch (Deutschland) | `de/` | Verlauf, Einheiten, Zähler, Downloadzeit, Stromverbrauch |
| Englisch (USA) | `en/` | englische Oberfläche |
| Spanisch (Spanien) | `es/` | spanische Oberfläche |
| Französisch (Frankreich) | `fr/` | französische Oberfläche |

Die englischen, spanischen und französischen Aufnahmen wurden mit der
lokalisierten App erzeugt und im Partner Center hochgeladen. Der deutsche
Eintrag behält die deutschen Bilder.

## Verbleibende Schritte

1. **Zur Zertifizierung übermitteln** – dieser Schritt wurde bewusst nicht
   ausgeführt.
2. Die Änderungen sind auf `main` (`dbfd8fe`) gemergt und gepusht; der
   Store-Workflow baut dort standardmäßig die vier Sprachen. Die
   Screenshot-Dateien liegen lokal unter `windows/store/screenshots/`.

## Ausgeführte Prüfungen

- GitHub-Actions-Lauf `43826611772`: **success**
- `npm test`: **35/35 bestanden**
- `npm run dist:store -- --check`: **Store-Konfiguration OK**
- Manifest im heruntergeladenen AppX: **vier Sprachen, Identität und Version OK**
- SHA256 des Artefakts: **stimmt mit `SHA256SUMS.txt` überein**
- Partner-Center-Übersicht: **6 × Vollständig, 0 × Unvollständig**
- Partner-Center-Paket: **Toolbox-3.3.2.appx Validated**
- Partner-Center-Screenshots: **je 5 für en-US, es-ES und fr-FR ersetzt und gespeichert**
- Screenshot-Auflösung: **2464 × 1648, PNG**
- Einreichung: **nicht abgesendet**
