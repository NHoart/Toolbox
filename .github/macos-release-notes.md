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

### Neu in 3.1.0

- **Drei-Geräte-Sync mit echtem Swift-Code:** Zwei getrennte Apple-Clients
  (Mac und iPhone) und der echte Windows-Client laufen als drei gleichzeitige
  Peers. Der Windows-PC übernimmt den von Mac/iPhone erzeugten Stand und gibt
  ihn an beide Apple-Clients zurück.
- **Keine Datenverluste:** Der jeweils neuere Stand gewinnt. Ein verspäteter
  älterer Stand wird sowohl am Windows-PC als auch am iPhone verworfen;
  Verlauf, Mengen, Größen und gespeicherte Zählerstände bleiben erhalten.
- **iOS:** Das iOS-App-Target kompiliert wieder; die macOS-only Update-Routine
  ist jetzt korrekt gegen iOS abgegrenzt.
- **Tests:** 24 Windows-Tests, der Headless-Sync-Smoke-Test und der
  Drei-Peer-Interop laufen in CI.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
