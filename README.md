# Toolbox

Eine kleine Sammlung von Alltagswerkzeugen als SwiftUI-App für iPhone, iPad, Mac und Vision Pro – inklusive Home-Screen-Widget und Siri-Kurzbefehlen. Dieselben sechs Werkzeuge gibt es als Desktop-App für Windows, mit Abgleich im lokalen WLAN über Mac, iPhone und PC hinweg.

## Download

### macOS

Die fertige Mac-App gibt es als DMG direkt von GitHub:

[**Toolbox.dmg herunterladen**](https://github.com/NHoart/Toolbox/releases/latest/download/Toolbox.dmg)

Alle Versionen stehen auf der [Releases-Seite](https://github.com/NHoart/Toolbox/releases). Nach dem Download die DMG öffnen, `Toolbox` in den Ordner **Programme** ziehen und die App per Rechtsklick → **Öffnen** starten. Die DMG ist nicht mit einem Apple-Developer-Zertifikat signiert und nicht notarisiert, deshalb blockiert macOS den allerersten Start.

Die Mac-App prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version liegt. Liegt die App in **Programme**, lädt sie die neue DMG, prüft Prüfsumme und Signatur und ersetzt sich selbst; aus Xcode oder von der DMG gestartet bietet sie stattdessen den Download an. Manuell geht das über **Toolbox → Nach Updates suchen…** oder den Button in den Einstellungen; abschalten lässt sich die automatische Prüfung dort ebenfalls.

### iPhone und iPad

Für iPhone und iPad gibt es kein fertiges IPA im Release und keinen App-Store-Download – die iOS-App wird mit Xcode aus dem Quellcode direkt aufs Gerät gebaut. Nötig sind ein Mac mit Xcode 27.2 oder neuer und ein iPhone oder iPad mit iOS/iPadOS 27.2 oder neuer.

1. Repository klonen und die eigene Team-ID in `Config/Local.xcconfig` hinterlegen – den Befehl nennt [Bauen und Starten](#bauen-und-starten), die Team-ID steht in Xcode unter **Settings → Accounts** hinter dem angemeldeten Apple-Account. Für die App Group unten braucht es ein kostenpflichtiges Developer-Team.
2. `Toolbox.xcodeproj` öffnen, das Schema `Toolbox` wählen und als Ziel das per Kabel oder WLAN verbundene iPhone bzw. iPad auswählen.
3. Am Gerät den Entwicklermodus einschalten: **Einstellungen → Datenschutz & Sicherheit → Entwicklermodus**, das iPhone neu starten und den Modus nach dem Entsperren bestätigen. Ohne ihn startet die App nicht.
4. **Run** (⌘R) drücken. Beim ersten Start fragt iOS nach der Freigabe für **Lokales Netzwerk** – erlauben, sonst findet der Abgleich im WLAN keine anderen Geräte.
5. Meldet iOS, dass der Entwickler nicht verifiziert ist, unter **Einstellungen → Allgemein → VPN & Geräteverwaltung** den Eintrag **Apple Development: …** öffnen und **Vertrauen** wählen.

Für Widget und die gemeinsamen Daten von App und Widget muss in beiden Targets unter **Signing & Capabilities** die App Group `group.com.noahsapps.Wassertracker` aktiv sein; fehlt sie, bricht der Debug-Build beim ersten Zugriff auf den Wassertracker ab. Mit einem kostenlosen Apple-Account läuft die installierte App außerdem nur sieben Tage, danach ist in Xcode erneut **Run** nötig. Eine neue Version kommt nicht automatisch aufs Gerät: `git pull` und erneut aus Xcode installieren.

### Windows

Die Windows-App gibt es als Installer direkt von GitHub:

[**Toolbox-Setup.exe herunterladen**](https://github.com/NHoart/Toolbox/releases/latest/download/Toolbox-Setup.exe)

Windows 10/11 (64 Bit). Nach dem Download den Installer ausführen; die Installation läuft ohne Administratorrechte im Benutzerprofil. Der Installer ist nicht signiert, deshalb kann SmartScreen beim ersten Start warnen – über **Weitere Informationen → Trotzdem ausführen** startet die App trotzdem.

Die Microsoft-Store-Fassung ist eine zusätzliche Installationsart und ersetzt den Installer nicht. Sobald sie veröffentlicht ist, steht der Store-Link in den Release-Notes neuer Releases; für das bereits veröffentlichte 3.3.1 wird er einmal manuell ergänzt. Einrichtung und Einreichung sind unter [`windows/store`](windows/store/README.md) beschrieben.

Die Windows-App prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version liegt. Ist sie installiert, lädt sie den neuen Installer, prüft die im Release hinterlegte SHA-512-Prüfsumme und installiert das Update im Hintergrund; danach startet sie neu. Manuell geht das über **Einstellungen → Updates**; abschalten lässt sich die automatische Prüfung dort ebenfalls. Die Microsoft-Store-Fassung aktualisiert sich über den Store; die GitHub-Update-Prüfung ist dort deaktiviert.

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
npm run dist:store # AppX für den Microsoft Store (Windows/Parallels)
```

Der Installer wird regulär im Workflow auf `windows-latest` gebaut. `npm run dist` funktioniert auch auf einem Mac, sofern die Windows-Build-Werkzeuge von electron-builder verfügbar sind. `npm run dist:store` baut die Store-Fassung als AppX; die Identität steht in `windows/store/store.config.json`, und der NSIS-Installer bleibt davon unberührt. Details: [`windows/store/README.md`](windows/store/README.md).

### Sync zwischen Swift und Windows testen

Der Interop-Test kompiliert den echten Apple-Sync-Code als headless CLI und verbindet zwei unabhängige Prozesse (Mac und iPhone) mit dem echten Windows-`SyncService` aus `windows/src/sync.js` als Relay und Store:

```bash
bash scripts/build-sync-harness.sh
node scripts/test-swift-windows-interop.js
```

Der Test prüft, dass Änderungen von jedem Peer zu den anderen gelangen, verspätete alte Stände verworfen werden und am Ende alle Snapshot-Felder übereinstimmen. Das Wire-Format stammt direkt aus dem echten Swift-`LocalSync`; es gibt keine handgeschriebenen Fixtures. In CI läuft der Test unter `.github/workflows/sync-interop.yml` auf `macos-latest`.

Der iOS-Build des App-Targets lässt sich mit folgendem Befehl prüfen:

```bash
xcodebuild -quiet -project Toolbox.xcodeproj -scheme Toolbox -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath build/xcode-ios \
  CODE_SIGNING_ALLOWED=NO build
```

### DMG lokal bauen

```bash
./scripts/build-dmg.sh
```

Das Skript baut die macOS-App (`Release`, Apple Silicon), signiert sie ad-hoc und legt das fertige Image unter `dist/Toolbox.dmg` ab.

### Release veröffentlichen

`git tag v1.2.0 && git push origin v1.2.0` erzeugt ein Release `v1.2.0` mit DMG und Installer. Alternativ über **Actions → „macOS DMG“ → Run workflow** ein Release `v<Version>` aus dem aktuellen Stand bauen; der Windows-Workflow wird dabei automatisch mit angestoßen.

Die Release-Notes (`.github/macos-release-notes.md` und `.github/windows-release-notes.md`) beginnen mit einer Tabelle der Installationswege. Der jeweilige Workflow ersetzt die Platzhalter `{{REPO}}`, `{{TAG}}` und `{{STORE_ROW}}`; `{{STORE_ROW}}` wird aus der Repository-Variable `STORE_URL` gesetzt und entfällt ohne URL. Vor einem Release `MARKETING_VERSION` (und `CURRENT_PROJECT_VERSION`) im Projekt sowie `version` in `windows/package.json` erhöhen – der Update-Check und die Release-Tags vergleichen diese Versionen.

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
├── src/updater.js        Tägliche Update-Prüfung und Installation
├── renderer/             Oberfläche (HTML/CSS/JS)
├── store/                Store-Identität und Einreichungs-Anleitung
└── test/                 Protokoll-, Speicher- und Sync-Tests

swift-sync-harness/       Headless-CLI für den echten Swift-Sync
scripts/                  Build-Skripte und Swift↔Windows-Interop-Test
```

## Datenspeicherung

Es gibt keinen eigenen Server. Alle Daten bleiben lokal; auf Wunsch gleicht die App sie direkt im lokalen WLAN mit den anderen Geräten ab (`LocalSync`). Wassertracker und Widget teilen sich `UserDefaults` über eine App Group:

- Tagesmenge und Verlauf (max. 400 Tage) für den Wassertracker
- Glas-/Flaschengröße und Tagesziel
- Zählerstand, Auto-Zählrate und gespeicherte Zählerstände (im Standard-`UserDefaults`)

Die Windows-App speichert denselben Stand in `%APPDATA%\Toolbox\data.json`. Bei der Microsoft-Store-Fassung liegt der userData-Pfad im paketierten AppData-Bereich; beim ersten Start wird eine vorhandene Datei aus `%APPDATA%\Toolbox\data.json` automatisch übernommen.

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

Trage in den Einstellungen unter **Lokales Netzwerk** auf allen Geräten denselben Namen ein. Nur Geräte mit diesem Namen verbinden sich und gleichen sich ab; Groß-/Kleinschreibung und überzählige Leerzeichen spielen keine Rolle. Ohne Namen läuft kein Abgleich. In den Einstellungen zeigen alle Fassungen außerdem den Status und die verbundenen Geräte; „Jetzt suchen“ startet die Suche neu. Der Abgleich ist für das lokale Netz gedacht und nicht verschlüsselt – es werden keine Daten an Dritte gesendet.

Umsetzung: `Toolbox/LocalSync.swift` (Apple) und `windows/src/sync.js` (Windows). Beide verwenden dasselbe Zeilen-JSON-Format mit Swift-Referenzzeitstempeln.

## Datenschutz

Toolbox speichert alle Daten lokal und gleicht sie nur im lokalen WLAN ab.
Details: [`PRIVACY.md`](PRIVACY.md).

## Lizenz

Toolbox ist **kein Open-Source-Projekt**. Der Quellcode ist öffentlich einsehbar, die Rechte bleiben aber beim Autor: alle Rechte vorbehalten.

- **Erlaubt** ist: den Code auf GitHub ansehen und dort forken, Änderungen als Pull Request vorschlagen, die App unentgeltlich nutzen.
- **Nicht erlaubt** ist: den Code oder Teile davon kopieren, verändern und weitergeben, in eigene Apps oder Produkte einbauen oder eigene Fassungen der App veröffentlichen.

Der vollständige Text steht in [`LICENSE`](LICENSE), die Regeln für Beiträge in [`CONTRIBUTING.md`](CONTRIBUTING.md). Änderungen werden ausschließlich nach Review durch den Maintainer übernommen.
