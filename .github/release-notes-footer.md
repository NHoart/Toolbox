## Geprüfter Release-Stand

3.5.0 ist ein Wartungsrelease ohne Änderungen an den App-Funktionen. Die
Windows-Tests (35) und der Headless-Sync-Smoke-Test laufen mit diesem Release;
die Xcode-Builds für macOS und iOS werden über die GitHub-Actions-Workflows
erstellt. Der geprüfte Stand von 3.4.0 bleibt gültig; ein Test auf physischen
Geräten, ein echter WLAN-Test, ein Update-Lauf und die native Windows-Oberfläche
stehen weiterhin aus.

## Checkliste: Erster Start und Drei-Geräte-Sync

**Windows installieren**

- [ ] `Toolbox-Setup.exe` aus dem GitHub-Release starten.
- [ ] Blockt der Defender SmartScreen den Start, im Warnfenster auf **Weitere
  Informationen** und danach auf **Trotzdem ausführen** klicken – die App wird
  trotz der Block-Meldung gestartet.
- [ ] Beim ersten Start die Firewall-Freigabe für **Private Netzwerke** erlauben;
  das WLAN muss als „Privat“ eingestuft sein.
- [ ] Toolbox öffnen, unter **Einstellungen → Lokales Netzwerk** denselben Namen
  wie auf den anderen Geräten eintragen und prüfen, dass „Sync im WLAN“ an ist.

**Mac, iPhone und Windows verbinden**

- [ ] Alle Geräte müssen im selben WLAN sein; Client-Isolation im Router
  ausschalten.
- [ ] Toolbox auf allen Geräten öffnen; auf dem iPhone/iPad **Lokales Netzwerk**
  erlauben.
- [ ] Auf allen Geräten unter **Einstellungen → Lokales Netzwerk** denselben
  Namen eintragen.
- [ ] Auf allen Geräten **Jetzt suchen** wählen; die anderen Geräte werden als
  verbunden angezeigt.
- [ ] Mac → iPhone: Wasser oder Zähler auf dem Mac ändern und den Stand auf dem
  iPhone prüfen.
- [ ] Später iPhone → Windows: Toolbox auf dem PC öffnen/verbinden; der PC
  übernimmt den aktuellen Stand automatisch.
- [ ] Drei Geräte gleichzeitig: Eine Änderung auf einem Gerät erscheint auf den
  beiden anderen.

**Wenn nichts ankommt**

- [ ] „Jetzt suchen“ erneut ausführen und Firewall sowie Netzwerkprofil prüfen.
- [ ] Uhrzeit auf allen Geräten automatisch synchronisieren lassen.
- [ ] Toolbox auf allen Geräten neu starten und die aktuelle Fassung
  installieren.

## Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
- Windows 10/11, 64 Bit
