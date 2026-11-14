## Toolbox für Windows

Windows 10/11, 64 Bit. `Toolbox-Setup.exe` herunterladen, ausführen und den Anweisungen folgen – die Installation läuft ohne Administratorrechte im Benutzerprofil.

Da der Installer nicht signiert ist, zeigt Windows SmartScreen beim ersten Start möglicherweise eine Warnung. Über **Weitere Informationen → Trotzdem ausführen** lässt sich die App starten.

### Neu in 3.1.0

- **Drei-Geräte-Sync:** Zwei getrennte Apple-Clients (Mac und iPhone) und
  der Windows-PC laufen als drei gleichzeitige Peers. Der Windows-PC übernimmt
  den von Mac/iPhone erzeugten Stand und gibt ihn an beide Apple-Clients zurück.
- **Keine Datenverluste:** Der neuere Stand gewinnt; ein verspäteter älterer
  Stand wird am Windows-PC und am iPhone verworfen. Verlauf, Mengen, Größen
  und gespeicherte Zählerstände bleiben erhalten.
- **iOS:** Das iOS-App-Target kompiliert wieder.
- **Windows:** Installer und Sync-Tests bleiben grün.

### Sync mit Mac und iPhone

Die Windows-App nutzt denselben Abgleich im lokalen WLAN wie die Apple-App. Mac, iPhone und Windows-PC können gleichzeitig verbunden sein; Änderungen werden auch über ein drittes Gerät weitergegeben, das gerade als Brücke dient.

Es gibt keinen Server und kein Konto; die Daten bleiben auf den Geräten.

## Checkliste: Erster Start und Drei-Geräte-Sync

**Windows installieren**
- [ ] `Toolbox-Setup.exe` aus dem GitHub-Release starten.
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
