# Datenschutzerklärung

Stand: 14. November 2026

Toolbox ist eine lokale App für Wasser-, Zähler- und Alltagswerkzeuge. Es gibt
kein Benutzerkonto und keinen Server des Anbieters.

## Verantwortlicher

Noah Hartmann
Kontakt: https://github.com/NHoart/Toolbox/issues

## Lokale Daten

Toolbox speichert auf dem Gerät:

- Trinkmenge, Tagesziel und Verlauf
- Zählerstände, gespeicherte Zähler und Einstellungen
- den selbst vergebenen Sync-Namen und den Gerätenamen

Diese Daten werden nicht an den Anbieter übertragen.

## Abgleich im lokalen WLAN

Wenn der Abgleich eingeschaltet ist, kündigt Toolbox den Gerätenamen und den
Sync-Namen über Bonjour/mDNS im lokalen Netzwerk an. Geräte mit demselben
Sync-Namen verbinden sich direkt über TCP und tauschen die Wasser- und
Zählerstände aus. Die Verbindung ist nicht zusätzlich verschlüsselt; sie
verlässt das lokale Netzwerk nicht. Es gibt keinen Cloud-Dienst und keine
Anmeldung.

## Updates

Die EXE-Fassung fragt höchstens einmal pro Tag die GitHub-Release-Seite ab.
Dabei wird die öffentliche Release-Seite geladen; der Anbieter erhält daraus
keine App-Daten. Die Microsoft-Store-Fassung wird über den Microsoft Store
aktualisiert; die GitHub-Update-Prüfung ist dort deaktiviert.

## Microsoft Store

Die Microsoft-Store-Fassung wird über Microsoft bereitgestellt und
aktualisiert. Microsoft verarbeitet dabei Daten gemäß der
Microsoft-Datenschutzerklärung. Die App selbst sendet keine Telemetrie-,
Analyse- oder Werbedaten.

## Löschen

Lokale Daten lassen sich durch Deinstallieren der App und Löschen des
AppData-Ordners entfernen. Bei der Store-Fassung können die App-Daten
zusätzlich über die Windows-Einstellungen zurückgesetzt werden.

## Änderungen

Diese Erklärung wird bei Änderungen der Datenverarbeitung aktualisiert. Es gilt
die hier veröffentlichte Fassung.
