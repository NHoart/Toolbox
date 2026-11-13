## Toolbox für macOS

Lade unten unter **Assets** die Datei `Toolbox.dmg` herunter.

### Installation

1. `Toolbox.dmg` öffnen und `Toolbox` in den Ordner **Programme** ziehen.
2. Die App einmal starten. Da sie nicht mit einem Apple-Developer-Zertifikat
   signiert und nicht notarisiert ist, blockiert macOS den ersten Start:
   - **Rechtsklick** (oder Control-Klick) auf `Toolbox` → **Öffnen** → im
     Dialog erneut **Öffnen** wählen, oder
   - **Systemeinstellungen → Datenschutz & Sicherheit** → unten bei
     „Toolbox wurde blockiert“ auf **Dennoch öffnen** klicken, oder
   - im Terminal: `xattr -dr com.apple.quarantine /Applications/Toolbox.app`

### Neu in 3.0.0

- Toolbox für Mac, iPhone und Windows: alle sechs Werkzeuge und der lokale
  WLAN-Abgleich in einer gemeinsamen Version.
- Mac, iPhone und Windows-PC können gleichzeitig verbunden sein. Änderungen
  werden auch über ein drittes Gerät weitergegeben, sodass die Kette
  Mac → iPhone → Windows den aktuellen Stand übernimmt.
- Beide Release-Workflows prüfen automatisch, dass DMG und Windows-Installer
  gemeinsam am Release hängen.
- Die Checkliste für Installation und Drei-Geräte-Sync steht im README und in
  den Windows-Release-Notes.
- Der Fortschrittsring zeigt den Prozentwert ohne zusätzliches Prozentzeichen.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
