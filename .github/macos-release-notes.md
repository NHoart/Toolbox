## Downloads

| Plattform | Datei |
| --- | --- |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |

Dieselben Dateien hängen unten unter **Assets** am Release.

## Toolbox für macOS

Lade oben `Toolbox.dmg` herunter.

### Installation

1. `Toolbox.dmg` öffnen und `Toolbox` in den Ordner **Programme** ziehen.
2. Die App einmal starten. Da sie nicht mit einem Apple-Developer-Zertifikat
   signiert und nicht notarisiert ist, blockiert macOS den ersten Start:
   - **Rechtsklick** (oder Control-Klick) auf `Toolbox` → **Öffnen** → im
     Dialog erneut **Öffnen** wählen, oder
   - **Systemeinstellungen → Datenschutz & Sicherheit** → unten bei
     „Toolbox wurde blockiert“ auf **Dennoch öffnen** klicken, oder
   - im Terminal: `xattr -dr com.apple.quarantine /Applications/Toolbox.app`

### Neu in 3.2.0

- **Auto-Update für Windows:** Die Windows-App prüft beim Start höchstens
  einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht, zeigt die
  Release-Notes und installiert das Update nach Bestätigung mit
  Fortschrittsanzeige; danach startet sie neu. Abschalten lässt sich die
  Prüfung in den Einstellungen.
- **Release-Assets für den Updater:** Der Windows-Workflow veröffentlicht
  zusätzlich `latest.yml` und die Blockmap, damit sich die Windows-App selbst
  aktualisieren kann.
- **Apple-Apps unverändert:** macOS, iOS und das Widget entsprechen 3.1.1.

### Windows: Update von 3.1.x

Windows-Versionen vor 3.2.0 enthalten den Updater noch nicht. Einmalig
`Toolbox-Setup.exe` oben herunterladen, Toolbox schließen und den Installer über
die bestehende Installation laufen lassen – Deinstallieren ist nicht nötig, die
Daten bleiben erhalten. Da der Installer nicht signiert ist, kann der Defender
SmartScreen warnen – über **Weitere Informationen → Trotzdem ausführen** lässt
er sich starten. Ab 3.2.0 übernimmt das Auto-Update.

### Geprüfter Release-Stand

3.2.0 ändert nur die Windows-App und den Release-Workflow. Der Xcode-Build für macOS lief mit Xcode 27.2 fehlerfrei durch; die Windows-Tests (29, davon fünf neue für den Updater) und der Installer-Build samt `latest.yml` und `app-update.yml` sind grün. Ein echter Update-Lauf auf einem Windows-Rechner sowie die native Windows-Oberfläche konnten auf dem Mac nicht geprüft werden.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
