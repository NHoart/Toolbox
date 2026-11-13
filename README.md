# Toolbox

Eine kleine Sammlung von Alltagswerkzeugen als SwiftUI-App für iPhone, iPad, Mac und Vision Pro – inklusive Home-Screen-Widget und Siri-Kurzbefehlen.

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

## Projektstruktur

```
Toolbox/                  App-Target (SwiftUI)
├── MyApp.swift           App-Einstieg
├── ContentView.swift     TabView mit allen Werkzeugen
├── Water/                Wassertracker: Heute, Verlauf, Einstellungen, Siri-Intents
├── WaterStore.swift      Persistenz über die App Group (in App *und* Widget)
└── SmartCalc/            Umrechner, Downloadzeit, Stromverbrauch, Zähler

ToolboxWidget/            WidgetKit-Extension (Wassertracker-Widget)
Config/                   Shared.xcconfig + lokale, nicht versionierte Local.xcconfig
```

## Datenspeicherung

Alle Daten bleiben lokal auf dem Gerät – es gibt keinen Server und keine Netzwerkanfragen. Wassertracker und Widget teilen sich `UserDefaults` über die App Group `group.com.noahsapps.Wassertracker`:

- Tagesmenge und Verlauf (max. 400 Tage) für den Wassertracker
- Glas-/Flaschengröße und Tagesziel
- Zählerstand, Auto-Zählrate und gespeicherte Zählerstände (im Standard-`UserDefaults`)

Die App Group muss für App- und Widget-Target im Signing aktiviert sein, sonst erreicht das Widget die Daten nicht.

## Version

Aktuell `1.0` (`MARKETING_VERSION` im Projekt).

## Lizenz

Für dieses Repository ist noch keine Lizenz hinterlegt. Bis dahin gilt: alle Rechte vorbehalten.
