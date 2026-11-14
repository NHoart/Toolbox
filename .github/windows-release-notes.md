## Downloads

| Plattform | Installation |
| --- | --- |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **Windows** 10/11, 64 Bit (winget) | `winget install --id NHoart.Toolbox -e` |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |

Dieselben Dateien hängen unten unter **Assets** am Release.

## Toolbox für Windows

Windows 10/11, 64 Bit. `Toolbox-Setup.exe` oben herunterladen, ausführen und den Anweisungen folgen – die Installation läuft ohne Administratorrechte im Benutzerprofil.

Da der Installer nicht signiert ist, zeigt Windows SmartScreen beim ersten Start möglicherweise eine Warnung. Über **Weitere Informationen → Trotzdem ausführen** lässt sich die App starten. Wer den Browser-Download vermeiden will, installiert stattdessen per winget (siehe Tabelle oben).

### Neu in 3.3.0

- **Name für den WLAN-Sync:** Im Abschnitt **Lokales Netzwerk** der
  Einstellungen gibt es jetzt oben ein Namensfeld. Ohne Namen läuft kein
  Abgleich; der Status zeigt „Name fehlt“ und „Jetzt suchen“ ist deaktiviert.
- **Nur gleiche Namen verbinden sich:** Toolbox sucht wie bisher im WLAN,
  verbindet sich aber nur mit Geräten, die denselben Namen eingetragen haben.
  Groß-/Kleinschreibung und überzählige Leerzeichen spielen keine Rolle.
- **Mehrere Geräte:** Alle Geräte mit demselben Namen bilden weiterhin eine
  Gruppe; Änderungen werden auch über ein drittes Gerät weitergegeben.
- **Apple und Windows gemeinsam:** Namensfeld und Namensprüfung sind in macOS,
  iOS und der Windows-App enthalten.

### Windows: Update von 3.1.x

Windows-Versionen vor 3.2.0 enthalten den Updater noch nicht. Einmalig
`Toolbox-Setup.exe` oben herunterladen, Toolbox schließen und den Installer über
die bestehende Installation laufen lassen – Deinstallieren ist nicht nötig, die
Daten bleiben erhalten. Da der Installer nicht signiert ist, kann der Defender
SmartScreen warnen – über **Weitere Informationen → Trotzdem ausführen** lässt
er sich starten. Ab 3.2.0 übernimmt das Auto-Update; 3.3.0 wird dort automatisch
angeboten.

### Geprüfter Release-Stand

Die Windows-Tests (32) und der Headless-Sync-Smoke-Test sind grün. Der
Swift↔Windows-Interop-Test bestätigt den Abgleich mit Mac, iPhone und Windows
sowie, dass ein Gerät mit anderem Namen weder Peer wird noch Daten erhält. Die
Xcode-Builds für macOS und iOS liefen fehlerfrei durch. Ein echter WLAN-Test
zwischen physischen Geräten, ein Update-Lauf und die native Windows-Oberfläche
müssen nach dem Release auf den Zielgeräten geprüft werden.

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
