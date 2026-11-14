## Downloads

| Plattform | Datei |
| --- | --- |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |

Dieselben Dateien hängen unten unter **Assets** am Release.

## Toolbox für Windows

Windows 10/11, 64 Bit. `Toolbox-Setup.exe` oben herunterladen, ausführen und den Anweisungen folgen – die Installation läuft ohne Administratorrechte im Benutzerprofil.

Da der Installer nicht signiert ist, zeigt Windows SmartScreen beim ersten Start möglicherweise eine Warnung. Über **Weitere Informationen → Trotzdem ausführen** lässt sich die App starten.

### Neu in 3.1.1

- **Downloads direkt oben:** Die Release-Notes beginnen mit einer Tabelle, die
  `Toolbox-Setup.exe` und `Toolbox.dmg` direkt verlinkt.
- **Release-Notes-Vorlagen:** Beide Workflows setzen vor dem Anlegen des
  Releases die Platzhalter `{{REPO}}` und `{{TAG}}` ein, damit die
  Download-Links auf das richtige Repository und Release zeigen.
- **Keine Änderungen an der App:** Installer und Sync-Tests bleiben wie in
  3.1.0 grün.

### Geprüfter Release-Stand

3.1.1 enthält keine Änderungen am App-Code; geprüft bleibt damit der Stand aus 3.1.0: macOS 3.1.0 aus `Toolbox.dmg`, iOS 3.1.0 aus dem Tag `v3.1.0` im Simulator und Windows 3.1.0 aus `Toolbox-Setup.exe`. Der Windows-Client lief dabei als echter Store-/Sync-Peer aus dem extrahierten `app.asar`. Mac→iPhone, anschließend iPhone→Windows ohne Mac sowie drei gleichzeitige Peers inklusive eines verspäteten alten Mac-Stands laufen grün (`scripts/test-release-sync-chain.js`).

Nur auf echter Hardware geprüft werden können die native Windows-Oberfläche und Installation, SmartScreen/Firewall sowie echtes Bonjour/WLAN zwischen physischen Geräten.

### Sync mit Mac und iPhone

Die Windows-App nutzt denselben Abgleich im lokalen WLAN wie die Apple-App. Mac, iPhone und Windows-PC können gleichzeitig verbunden sein; Änderungen werden auch über ein drittes Gerät weitergegeben, das gerade als Brücke dient.

Es gibt keinen Server und kein Konto; die Daten bleiben auf den Geräten.

## Checkliste: Erster Start und Drei-Geräte-Sync

**Windows installieren**
- [ ] `Toolbox-Setup.exe` aus dem GitHub-Release starten.
- [ ] Blockt der Defender SmartScreen den Start, im Warnfenster auf **Weitere Informationen** und danach auf **Trotzdem ausführen** klicken – die App wird trotz der Block-Meldung gestartet.
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
