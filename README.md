# Toolbox

Eine kleine Sammlung von Alltagswerkzeugen als SwiftUI-App für iPhone, iPad, Mac und Vision Pro – inklusive Home-Screen-Widget und Siri-Kurzbefehlen.

## Download (macOS)

Die fertige Mac-App gibt es als DMG direkt von GitHub:

[**Toolbox.dmg herunterladen**](https://github.com/NHoart/Toolbox/releases/latest/download/Toolbox.dmg)

Alle Versionen stehen auf der [Releases-Seite](https://github.com/NHoart/Toolbox/releases). Nach dem Download die DMG öffnen, `Toolbox` in den Ordner **Programme** ziehen und die App per Rechtsklick → **Öffnen** starten. Die DMG ist nicht mit einem Apple-Developer-Zertifikat signiert und nicht notarisiert, deshalb blockiert macOS den allerersten Start.

Die App prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version liegt. Liegt die App in **Programme**, lädt sie die neue DMG, prüft Prüfsumme und Signatur und ersetzt sich selbst; aus Xcode oder von der DMG gestartet bietet sie stattdessen den Download an. Manuell geht das über **Toolbox → Nach Updates suchen…** oder den Button in den Einstellungen; abschalten lässt sich die automatische Prüfung dort ebenfalls.

## Funktionen

Die App ist in Tabs aufgeteilt:

| Tab | Beschreibung |
| --- | --- |
| **Heute** | Wassertracker: Fortschrittsring, Schnellwahl für Glas und Flasche, frei wählbare Menge (1–10.000 ml) sowie „Rückgängig“ für den letzten Eintrag. |
| **Verlauf** | Diagramm der letzten 30 Tage (Charts) mit eingezeichnetem Tagesziel, Durchschnitt, Anzahl erreichter Ziele und bestem Tag. |
| **Einheiten** | Umrechnung zwischen MB/GB und Mbit/MB. |
| **Zähler** | Manueller Zähler mit Plus/Minus, Undo, Reset, Auto-Zählmodus (1–100 Schritte pro Sekunde), Haptik- und Ton-Feedback sowie benannten, gespeicherten Zählerständen in einer Seitenleiste. |
| **Downloadzeit** | Geschätzte Downloaddauer aus Dateigröße und Geschwindigkeit (Mbit/s oder MB/s). |
| **Stromverbrauch** | Energieverbrauch aus Leistung × Nutzungsdauer, optional mit Kostenberechnung zum eigenen kWh-Preis. |

### Widget

Das Widget zeigt den Tagesfortschritt als Ring (klein und mittel). In der mittleren Größe lassen sich Glas und Flasche direkt per Knopfdruck eintragen, ohne die App zu öffnen. Die Timeline aktualisiert sich spätestens alle 30 Minuten und um Mitternacht, damit der Tageszähler zurückspringt.

### Siri & Kurzbefehle

Der Kurzbefehl „Wasser eintragen“ kennt Gläser und Flaschen (einzeln, doppelt oder dreifach) und antwortet mit dem aktuellen Stand, zum Beispiel:

> „Hey Siri, ich habe zwei Gläser getrunken in Toolbox“

Die Größe von Glas und Flasche stammt dabei aus den Einstellungen der App.

## Voraussetzungen

- Xcode mit iOS-/iPadOS-SDK 27.2 oder neuer (Projektformat `project.xcproj`)
- Deployment-Target: iOS/iPadOS 27.2, macOS und visionOS
- Ein eigenes Apple-Developer-Team für das Signieren

## Bauen und Starten

1. Repository klonen und `Toolbox.xcodeproj` in Xcode öffnen.
2. Die persönliche Team-ID hinterlegen – sie ist absichtlich **nicht** im Repo:
   ```bash
   printf 'DEVELOPMENT_TEAM = XXXXXXXXXX\n' > Config/Local.xcconfig
   ```
   `Config/Shared.xcconfig` bindet die Datei per `#include?` ein, ein frischer Clone baut also auch ohne sie (dann ohne automatisches Signieren).
3. Das Schema `Toolbox` auswählen und auf einem Gerät, Simulator oder „My Mac (Designed for iPad)“ starten.

### DMG lokal bauen

```bash
./scripts/build-dmg.sh
```

Das Skript baut die macOS-App (`Release`, Apple Silicon), signiert sie ad-hoc und legt das fertige Image unter `dist/Toolbox.dmg` ab.

### Release veröffentlichen

Der Workflow `.github/workflows/macos-dmg.yml` baut die DMG automatisch und hängt sie an ein GitHub-Release:

- **Tag pushen**: `git tag v1.2.0 && git push origin v1.2.0` → Release `v1.2.0` mit `Toolbox.dmg`
- **Actions → „macOS DMG“ → Run workflow** → Release `v<Version>` mit dem aktuellen Stand, erreichbar über den Download-Link oben

Vor einem Release `MARKETING_VERSION` (und `CURRENT_PROJECT_VERSION`) im Projekt erhöhen – der Update-Check vergleicht diese Version mit dem Release-Tag.

## Projektstruktur

```
Toolbox/                  App-Target (SwiftUI)
├── MyApp.swift           App-Einstieg
├── ContentView.swift     TabView mit allen Werkzeugen
├── Water/                Wassertracker: Heute, Verlauf, Einstellungen, Siri-Intents
├── WaterStore.swift      Persistenz über die App Group (in App *und* Widget)
├── LocalSync.swift       Abgleich im lokalen WLAN über Bonjour
├── Info.plist            Lokale-Netzwerk-Nutzung + Bonjour-Dienst
└── SmartCalc/            Umrechner, Downloadzeit, Stromverbrauch, Zähler

ToolboxWidget/            WidgetKit-Extension (Wassertracker-Widget)
Config/                   Shared.xcconfig + lokale, nicht versionierte Local.xcconfig
```

## Datenspeicherung

Es gibt keinen eigenen Server. Alle Daten liegen lokal in `UserDefaults`; auf Wunsch gleicht die App sie direkt im lokalen WLAN mit dem anderen Gerät ab (`LocalSync`). Wassertracker und Widget teilen sich `UserDefaults` über eine App Group:

- Tagesmenge und Verlauf (max. 400 Tage) für den Wassertracker
- Glas-/Flaschengröße und Tagesziel
- Zählerstand, Auto-Zählrate und gespeicherte Zählerstände (im Standard-`UserDefaults`)

Die App Group muss für App- und Widget-Target im Signing aktiviert sein, sonst erreicht das Widget die Daten nicht.

### Sync im lokalen WLAN

`LocalSync.swift` braucht weder Konto noch Developer-Account: Jedes Gerät bietet den Bonjour-Dienst `_toolboxsync._tcp` an und sucht gleichzeitig danach. Beim Verbindungsaufbau schicken beide Seiten ihren Stand samt Zeitstempel; pro Bereich gewinnt der zuletzt geänderte Stand, danach werden Änderungen an alle offenen Verbindungen verteilt. Der Abgleich läuft automatisch, solange die App auf beiden Geräten geöffnet ist und beide im selben WLAN sind (Peer-to-Peer/AWDL ist aktiviert).

Dafür nötig:

- `NSLocalNetworkUsageDescription` und `NSBonjourServices` in `Toolbox/Info.plist` (iOS fragt beim ersten Start nach der Freigabe)
- `com.apple.security.network.client` und `com.apple.security.network.server` in `Toolbox/Toolbox.entitlements` (Mac-App ist sandboxed)
- Freigabe in den Einstellungen des Wassertrackers unter „Lokales Netzwerk“, inklusive Status und „Jetzt suchen“

## Version

Aktuell `2.0.0` (`MARKETING_VERSION` im Projekt).

## Lizenz

Für dieses Repository ist noch keine Lizenz hinterlegt. Bis dahin gilt: alle Rechte vorbehalten.
