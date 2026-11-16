## Installationswege

| Weg | Installation |
| --- | --- |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **winget** (Windows 10/11) | `winget install --id NHoart.Toolbox -e` |
{{STORE_ROW}}

Dieselben Dateien hängen unten unter **Assets** am Release.

## Toolbox für Windows

Windows 10/11, 64 Bit. `Toolbox-Setup.exe` oben herunterladen, ausführen und den Anweisungen folgen – die Installation läuft ohne Administratorrechte im Benutzerprofil.

Da der Installer nicht signiert ist, zeigt Windows SmartScreen beim ersten Start möglicherweise eine Warnung. Über **Weitere Informationen → Trotzdem ausführen** lässt sich die App starten. Wer den Browser-Download vermeiden will, installiert stattdessen per winget (siehe Tabelle oben).

### Neu in 3.4.0

- **Sprache direkt in der App wählen:** In den Einstellungen lässt sich die
  Oberfläche auf Deutsch, Englisch, Spanisch oder Französisch stellen.
  **Systemsprache** folgt weiterhin Windows; die Auswahl bleibt nach einem
  Neustart erhalten.
- **Sofort angewendet:** Nach dem Wechsel lädt die App die Oberfläche mit der
  neuen Sprache neu.

### Windows: Update von 3.1.x

Windows-Versionen vor 3.2.0 enthalten den Updater noch nicht. Einmalig
`Toolbox-Setup.exe` oben herunterladen, Toolbox schließen und den Installer über
die bestehende Installation laufen lassen – Deinstallieren ist nicht nötig, die
Daten bleiben erhalten. Da der Installer nicht signiert ist, kann der Defender
SmartScreen warnen – über **Weitere Informationen → Trotzdem ausführen** lässt
er sich starten. Ab 3.2.0 übernimmt das Auto-Update; 3.4.0 wird dort automatisch
angeboten.

### Geprüfter Release-Stand

Die Windows-Tests (35) und der Headless-Sync-Smoke-Test sind grün. Der
Swift↔Windows-Interop-Test bestätigt den Abgleich mit Mac, iPhone und Windows
sowie die Namensfilterung. Die Xcode-Builds für macOS und iOS (3.4.0) liefen
fehlerfrei durch; der direkte Apple-Verbindungsaufbau wurde headless mit zwei
Instanzen geprüft. Ein Test auf physischen Geräten mit 3.4.0, ein echter
WLAN-Test, ein Update-Lauf und die native Windows-Oberfläche stehen noch aus.

### Sync mit Mac und iPhone

Die Windows-App nutzt denselben Abgleich im lokalen WLAN wie die Apple-App. Trage auf allen Geräten in den Einstellungen unter **Lokales Netzwerk** denselben Namen ein; ohne Namen ist der Abgleich aus. Nur Geräte mit diesem Namen verbinden sich. Mac, iPhone und Windows-PC können gleichzeitig verbunden sein; Änderungen werden auch über ein drittes Gerät weitergegeben, das gerade als Brücke dient.

Es gibt keinen Server und kein Konto; die Daten bleiben auf den Geräten.

## Checkliste: Erster Start und Drei-Geräte-Sync

**Windows installieren**
- [ ] `Toolbox-Setup.exe` aus dem GitHub-Release starten.
- [ ] Blockt der Defender SmartScreen den Start, im Warnfenster auf **Weitere Informationen** und danach auf **Trotzdem ausführen** klicken – die App wird trotz der Block-Meldung gestartet.
- [ ] Beim ersten Start die Firewall-Freigabe für **Private Netzwerke** erlauben; das WLAN muss als „Privat“ eingestuft sein.
- [ ] Toolbox öffnen, unter **Einstellungen → Lokales Netzwerk** denselben Namen wie auf den anderen Geräten eintragen und prüfen, dass „Sync im WLAN“ an ist.

**Mac, iPhone und Windows verbinden**
- [ ] Alle Geräte müssen im selben WLAN sein; Client-Isolation im Router ausschalten.
- [ ] Toolbox auf allen Geräten öffnen; auf dem iPhone/iPad **Lokales Netzwerk** erlauben.
- [ ] Auf allen Geräten unter **Einstellungen → Lokales Netzwerk** denselben Namen eintragen.
- [ ] Auf allen Geräten **Jetzt suchen** wählen; die anderen Geräte werden als verbunden angezeigt.
- [ ] Mac → iPhone: Wasser oder Zähler auf dem Mac ändern und den Stand auf dem iPhone prüfen.
- [ ] Später iPhone → Windows: Toolbox auf dem PC öffnen/verbinden; der PC übernimmt den aktuellen Stand automatisch.
- [ ] Drei Geräte gleichzeitig: Eine Änderung auf einem Gerät erscheint auf den beiden anderen.

**Wenn nichts ankommt**
- [ ] „Jetzt suchen“ erneut ausführen und Firewall sowie Netzwerkprofil prüfen.
- [ ] Uhrzeit auf allen Geräten automatisch synchronisieren lassen.
- [ ] Toolbox auf allen Geräten neu starten und die aktuelle Fassung installieren.
