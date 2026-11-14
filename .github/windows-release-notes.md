## Downloads

| Plattform | Datei |
| --- | --- |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |

Dieselben Dateien hängen unten unter **Assets** am Release.

## Toolbox für Windows

Windows 10/11, 64 Bit. `Toolbox-Setup.exe` oben herunterladen, ausführen und den Anweisungen folgen – die Installation läuft ohne Administratorrechte im Benutzerprofil.

Da der Installer nicht signiert ist, zeigt Windows SmartScreen beim ersten Start möglicherweise eine Warnung. Über **Weitere Informationen → Trotzdem ausführen** lässt sich die App starten.

### Neu in 3.2.0

- **Automatische Updates:** Toolbox prüft beim Start höchstens einmal pro Tag,
  ob auf GitHub eine neuere Version liegt. Ist eine verfügbar, zeigt sie die
  Release-Notes und installiert das Update nach Bestätigung mit
  Fortschrittsanzeige; danach startet sie neu.
- **Einstellungen:** Unter **Einstellungen → Updates** lässt sich die
  automatische Prüfung abschalten und eine Suche manuell anstoßen.
- **Geprüfte Downloads:** Vor der Installation kontrolliert der Updater die
  im Release hinterlegte SHA-512-Prüfsumme.
- **Apple-Apps unverändert:** macOS, iOS und das Widget entsprechen 3.1.1.

### Windows: Update von 3.1.x

Windows-Versionen vor 3.2.0 enthalten den Updater noch nicht. Einmalig
`Toolbox-Setup.exe` oben herunterladen, Toolbox schließen und den Installer über
die bestehende Installation laufen lassen – Deinstallieren ist nicht nötig, die
Daten bleiben erhalten. Ab 3.2.0 übernimmt das Auto-Update.

### Geprüfter Release-Stand

Die Update-Logik ist durch 29 Windows-Tests abgedeckt, davon fünf neue für den Updater. Der Installer-Build erzeugt `latest.yml`, die Blockmap und `app-update.yml`; `electron-updater` liegt im gepackten `app.asar`. Ein echtes Update von 3.1.1 auf 3.2.0 sowie die native Windows-Oberfläche müssen nach dem Release auf einem Windows-Rechner geprüft werden.

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
