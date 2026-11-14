# Toolbox

Eine kleine Sammlung von Alltagswerkzeugen als SwiftUI-App für iPhone, iPad, Mac und Vision Pro – inklusive Home-Screen-Widget und Siri-Kurzbefehlen. Dieselben sechs Werkzeuge gibt es als Desktop-App für Windows, mit Abgleich im lokalen WLAN über Mac, iPhone und PC hinweg.

## Download

### macOS

Die fertige Mac-App gibt es als DMG direkt von GitHub:

[**Toolbox.dmg herunterladen**](https://github.com/NHoart/Toolbox/releases/latest/download/Toolbox.dmg)

Alle Versionen stehen auf der [Releases-Seite](https://github.com/NHoart/Toolbox/releases). Nach dem Download die DMG öffnen, `Toolbox` in den Ordner **Programme** ziehen und die App per Rechtsklick → **Öffnen** starten. Die DMG ist nicht mit einem Apple-Developer-Zertifikat signiert und nicht notarisiert, deshalb blockiert macOS den allerersten Start.

Die Mac-App prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version liegt. Liegt die App in **Programme**, lädt sie die neue DMG, prüft Prüfsumme und Signatur und ersetzt sich selbst; aus Xcode oder von der DMG gestartet bietet sie stattdessen den Download an. Manuell geht das über **Toolbox → Nach Updates suchen…** oder den Button in den Einstellungen; abschalten lässt sich die automatische Prüfung dort ebenfalls.

### Windows

Die Windows-App gibt es als Installer direkt von GitHub:

[**Toolbox-Setup.exe herunterladen**](https://github.com/NHoart/Toolbox/releases/latest/download/Toolbox-Setup.exe)

Windows 10/11 (64 Bit). Nach dem Download den Installer ausführen; die Installation läuft ohne Administratorrechte im Benutzerprofil. Der Installer ist nicht signiert, deshalb kann SmartScreen beim ersten Start warnen – über **Weitere Informationen → Trotzdem ausführen** startet die App trotzdem.

Die wichtigsten Schritte für Installation und Drei-Geräte-Abgleich stehen in der [Checkliste](#checkliste-erster-start-und-drei-geräte-sync).

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

Die Windows-App enthält dieselben sechs Werkzeuge. Widget und Siri-Kurzbefehle gibt es nur in der Apple-Fassung.

### Widget

Das Widget zeigt den Tagesfortschritt als Ring (klein und mittel). In der mittleren Größe lassen sich Glas und Flasche direkt per Knopfdruck eintragen, ohne die App zu öffnen. Die Timeline aktualisiert sich spätestens alle 30 Minuten und um Mitternacht, damit der Tageszähler zurückspringt.

### Siri & Kurzbefehle

Der Kurzbefehl „Wasser eintragen“ kennt Gläser und Flaschen (einzeln, doppelt oder dreifach) und antwortet mit dem aktuellen Stand, zum Beispiel:

> „Hey Siri, ich habe zwei Gläser getrunken in Toolbox“

Die Größe von Glas und Flasche stammt dabei aus den Einstellungen der App.

## Voraussetzungen

### Apple-App

- Xcode mit iOS-/iPadOS-SDK 27.2 oder neuer (Projektformat `project.xcproj`)
- Deployment-Target: iOS/iPadOS 27.2, macOS und visionOS
- Ein eigenes Apple-Developer-Team für das Signieren

### Windows-App

- Windows 10/11 (64 Bit)
- Node.js 22 oder neuer und npm (nur zum Bauen und Starten aus dem Quellcode)

## Bauen und Starten

1. Repository klonen und `Toolbox.xcodeproj` in Xcode öffnen.
2. Die persönliche Team-ID hinterlegen – sie ist absichtlich **nicht** im Repo:
   ```bash
   printf 'DEVELOPMENT_TEAM = XXXXXXXXXX\n' > Config/Local.xcconfig
   ```
   `Config/Shared.xcconfig` bindet die Datei per `#include?` ein, ein frischer Clone baut also auch ohne sie (dann ohne automatisches Signieren).
3. Das Schema `Toolbox` auswählen und auf einem Gerät, Simulator oder „My Mac (Designed for iPad)“ starten.

### Windows-App bauen und starten

```bash
cd windows
npm ci
npm start          # App lokal starten
npm test           # Protokoll-, Speicher- und Sync-Tests inkl. Drei-Client-Kette
npm run smoke:sync # Headless-Smoke-Test des Sync-Clients
npm run dist       # Installer unter windows/dist/Toolbox-Setup.exe
```

Der Installer wird regulär im Workflow auf `windows-latest` gebaut. `npm run dist` funktioniert auch auf einem Mac, sofern die Windows-Build-Werkzeuge von electron-builder verfügbar sind.

### Echten Drei-Geräte-Sync testen

Der Interop-Test kompiliert den echten Apple-Sync-Code (`Toolbox/LocalSync.swift`, `WaterStore` und `CounterStore`) als headless CLI. Zwei unabhängige Prozesse – A=Mac und B=iPhone, jeweils mit eigener Defaults-Suite – verbinden sich gleichzeitig mit dem echten Windows-`SyncService` aus `windows/src/sync.js`, der als Relay und Store dient:

```bash
bash scripts/build-sync-harness.sh
node scripts/test-swift-windows-interop.js
```

Der Test prüft: A legt v1 an, Windows und B erhalten sie; A ändert auf v2, Windows und B erhalten sie, ohne dass B selbst schreibt; Windows ändert auf 850 ml/Zähler 2, beide Swift-Clients erhalten den Stand. Danach wird die echte, zuvor von A erzeugte v2-Wire-Zeile verspätet an Windows und B geschickt und muss dort verworfen werden. Am Ende werden alle Snapshot-Felder verglichen, inklusive Verlauf, `recentAdds`, Tag, Größen und einem gespeicherten Zählerstand. Das Wire-Format wird direkt vom echten Swift-`LocalSync` erzeugt und vom echten Windows-Client gelesen – es gibt keine handgeschriebenen Fixtures. Haptik und Ton sind im Harness No-Ops; die Listener laufen ohne Bonjour, damit keine echten Geräte im Netzwerk angezogen werden. In CI läuft der Drei-Peer-Test unter `.github/workflows/sync-interop.yml` auf `macos-latest`. Der iOS-Build nutzt den `xcode-27`-Runner (Xcode 27.2), weil `macos-latest` derzeit Xcode 26.6 und damit das neue `project.xcproj`-Format nicht lesen kann.

Der iOS-Build des App-Targets lässt sich mit folgendem Befehl prüfen:

```bash
xcodebuild -quiet -project Toolbox.xcodeproj -scheme Toolbox -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build/xcode-ios \
  CODE_SIGNING_ALLOWED=NO build
```

### Release-Nachweis der Drei-Geräte-Kette (3.1.0)

Der Test `scripts/test-release-sync-chain.js` prüft die Kette mit den veröffentlichten Artefakten statt mit Development-Builds:

- **macOS 3.1.0** aus `Toolbox.dmg`
- **iOS 3.1.0** aus dem Tag `v3.1.0`, für den Simulator gebaut (ein IPA ist nicht Teil des Releases)
- **Windows 3.1.0** aus `Toolbox-Setup.exe`; der echte `ToolboxStore` und `SyncService` aus dem extrahierten `app.asar` laufen als Node-Peer

Der Windows-Client läuft dabei als Prozess, weil Electron nicht nativ auf macOS läuft. Geprüft wird der veröffentlichte Store- und Sync-Code aus dem Installer, nicht die Windows-Oberfläche.

```bash
bash scripts/prepare-release-sync-test.sh
node scripts/test-release-sync-chain.js
```

Das Vorbereitungsskript lädt fehlende Release-Dateien von GitHub, mountet die DMG, entpackt den Installer und baut die iOS-App aus dem Tag. Der Test prüft Mac→iPhone, anschließend iPhone→Windows ohne Mac, drei gleichzeitige Peers mit Updates von jedem Gerät sowie einen verspäteten alten Mac-Stand, der nicht gewinnen darf. Verlauf, Mengen, Größen und gespeicherte Zählerstände werden mitverglichen.

Weiterhin nur auf echter Hardware prüfbar bleiben die native Windows-Oberfläche und Installation, SmartScreen/Firewall, die iOS-Freigabe „Lokales Netzwerk“ sowie echtes Bonjour/WLAN zwischen physischen Geräten.

### DMG lokal bauen

```bash
./scripts/build-dmg.sh
```

Das Skript baut die macOS-App (`Release`, Apple Silicon), signiert sie ad-hoc und legt das fertige Image unter `dist/Toolbox.dmg` ab.

### Release veröffentlichen

Der Workflow `.github/workflows/macos-dmg.yml` baut die DMG automatisch und hängt sie an ein GitHub-Release:

- **Tag pushen**: `git tag v1.2.0 && git push origin v1.2.0` → Release `v1.2.0` mit `Toolbox.dmg`
- **Actions → „macOS DMG“ → Run workflow** → Release `v<Version>` mit dem aktuellen Stand, erreichbar über den Download-Link oben

Der Workflow `.github/workflows/windows-exe.yml` baut zusätzlich `Toolbox-Setup.exe` auf `windows-latest`, führt die Tests aus und hängt den Installer an denselben Release. Ein Tag-Build erzeugt also beide Downloads; ein manueller Lauf von „macOS DMG“ stößt den Windows-Workflow für denselben Release automatisch mit an. Beide Workflows prüfen nach dem Upload automatisch, dass `Toolbox.dmg` und `Toolbox-Setup.exe` am Release hängen; fehlt ein Asset, schlägt der Lauf fehl.

Vor einem Release `MARKETING_VERSION` (und `CURRENT_PROJECT_VERSION`) im Projekt sowie `version` in `windows/package.json` erhöhen – der Update-Check und die Release-Tags vergleichen diese Versionen.

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
windows/                  Windows-App (Electron, JavaScript)
├── main.js               Hauptprozess, Fenster und IPC
├── preload.js            Brücke zwischen Prozess und Oberfläche
├── src/protocol.js       Apple-kompatibles Sync-Format (JSON + Zeitstempel)
├── src/store.js          Lokale Daten in %APPDATA%\Toolbox\data.json
├── src/sync.js           Bonjour + TCP, Mehrgeräte-Abgleich
├── renderer/             Oberfläche (HTML/CSS/JS)
└── test/                 Protokoll-, Speicher- und Sync-Tests

swift-sync-harness/       Headless-CLI für den echten Swift-Sync
scripts/                  Build-Skripte und Swift↔Windows-Interop-Test
```

## Datenspeicherung

Es gibt keinen eigenen Server. Alle Daten bleiben lokal; auf Wunsch gleicht die App sie direkt im lokalen WLAN mit den anderen Geräten ab (`LocalSync`). Wassertracker und Widget teilen sich `UserDefaults` über eine App Group:

- Tagesmenge und Verlauf (max. 400 Tage) für den Wassertracker
- Glas-/Flaschengröße und Tagesziel
- Zählerstand, Auto-Zählrate und gespeicherte Zählerstände (im Standard-`UserDefaults`)

Die App Group muss für App- und Widget-Target im Signing aktiviert sein, sonst erreicht das Widget die Daten nicht. Die Windows-App speichert denselben Stand in `%APPDATA%\Toolbox\data.json`.

### Sync im lokalen WLAN (Mac, iPhone, Windows)

Alle Fassungen sprechen dasselbe Protokoll: Jedes Gerät bietet den Bonjour-Dienst `_toolboxsync._tcp` an und sucht gleichzeitig danach. Beim Verbindungsaufbau schicken beide Seiten ihren vollständigen Stand samt Zeitstempel; pro Bereich (Wasser und Zähler) gewinnt der zuletzt geänderte Stand. Übernommene Stände werden sofort an alle offenen Verbindungen weitergegeben – auch an Geräte, die mit dem Ursprung nicht direkt verbunden sind.

Damit funktioniert auch die Kette über ein drittes Gerät:

1. **Mac ↔ iPhone**: Das iPhone übernimmt den aktuellen Mac-Stand.
2. **Später iPhone ↔ Windows-PC**: Der Windows-PC bekommt denselben Stand – obwohl er mit dem Mac nie direkt verbunden war.

Es gibt kein Gerätelimit: Mac, iPhone und Windows-PC können gleichzeitig verbunden sein. Der Abgleich läuft automatisch, solange Toolbox auf den Geräten geöffnet ist und alle im selben WLAN sind.

Damit der Abgleich klappt:

- gleiches WLAN, ohne Client-Isolation (Gäste-WLANs blockieren sich oft gegenseitig)
- Toolbox auf allen Geräten geöffnet
- iPhone/iPad: lokales Netzwerk erlauben (`NSLocalNetworkUsageDescription` und `NSBonjourServices` in `Toolbox/Info.plist`)
- Mac: Netzwerk-Client/-Server in den Entitlements (bereits gesetzt: `com.apple.security.network.client`/`server`)
- Windows: beim ersten Start die Firewall-Freigabe für **Private Netzwerke** erteilen; das Netzwerkprofil muss „Privat“ sein
- Windows kann kein AWDL/Peer-to-Peer; ein gemeinsamer Router bzw. ein WLAN ist nötig
- Die Geräte sollten ihre Uhrzeit automatisch synchronisieren (Standard bei macOS, iOS und Windows), weil der Abgleich Zeitstempel vergleicht

In den Einstellungen zeigen alle Fassungen den Status und die verbundenen Geräte; „Jetzt suchen“ startet die Suche neu. Der Abgleich ist für das lokale Netz gedacht und nicht verschlüsselt – es werden keine Daten an Dritte gesendet.

Umsetzung: `Toolbox/LocalSync.swift` (Apple) und `windows/src/sync.js` (Windows). Beide verwenden dasselbe Zeilen-JSON-Format mit Swift-Referenzzeitstempeln.

## Checkliste: Erster Start und Drei-Geräte-Sync

**Windows installieren**
- [ ] `Toolbox-Setup.exe` aus `windows/dist` oder dem GitHub-Release starten.
- [ ] SmartScreen gegebenenfalls über **Weitere Informationen → Trotzdem ausführen** bestätigen.
- [ ] Beim ersten Start die Firewall-Freigabe für **Private Netzwerke** erlauben; das WLAN muss als „Privat“ eingestuft sein.
- [ ] Toolbox öffnen und in den Einstellungen prüfen, dass „Sync im WLAN“ an ist.

**Mac, iPhone und Windows verbinden**
- [ ] Alle Geräte müssen im selben WLAN sein; Client-Isolation im Router ausschalten.
- [ ] Toolbox auf allen Geräten öffnen; auf dem iPhone/iPad **Lokales Netzwerk** erlauben.
- [ ] Auf allen Geräten **Jetzt suchen** wählen; die anderen Geräte werden als verbunden angezeigt.
- [ ] Mac → iPhone: Wasser oder Zähler auf dem Mac ändern und den Stand auf dem iPhone prüfen.
- [ ] Später iPhone → Windows: Toolbox auf dem PC öffnen/verbinden; der PC übernimmt den aktuellen Stand automatisch.
- [ ] Drei Geräte gleichzeitig: Eine Änderung auf einem Gerät erscheint auf den beiden anderen.

**Wenn nichts ankommt**
- [ ] „Jetzt suchen“ erneut ausführen und Firewall sowie Netzwerkprofil prüfen.
- [ ] Uhrzeit auf allen Geräten automatisch synchronisieren lassen.
- [ ] Toolbox auf allen Geräten neu starten und die aktuelle Fassung installieren.

## Version

Aktuell `3.1.0` (`MARKETING_VERSION` im Projekt).

## Lizenz

Toolbox ist **kein Open-Source-Projekt**. Der Quellcode ist öffentlich einsehbar, die Rechte bleiben aber beim Autor: alle Rechte vorbehalten.

- **Erlaubt** ist: den Code auf GitHub ansehen und dort forken, Änderungen als Pull Request vorschlagen, die App unentgeltlich nutzen.
- **Nicht erlaubt** ist: den Code oder Teile davon kopieren, verändern und weitergeben, in eigene Apps oder Produkte einbauen oder eigene Fassungen der App veröffentlichen.

Der vollständige Text steht in [`LICENSE`](LICENSE), die Regeln für Beiträge in [`CONTRIBUTING.md`](CONTRIBUTING.md). Änderungen werden ausschließlich nach Review durch den Maintainer übernommen.
