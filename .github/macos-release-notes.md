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

### Neu in 3.1.1

- **Downloads direkt oben:** Die Release-Notes beginnen mit einer Tabelle, die
  `Toolbox.dmg` und `Toolbox-Setup.exe` direkt verlinkt.
- **Release-Notes-Vorlagen:** Beide Workflows setzen vor dem Anlegen des
  Releases die Platzhalter `{{REPO}}` und `{{TAG}}` ein, damit die
  Download-Links auf das richtige Repository und Release zeigen.
- **Keine Änderungen an der App:** Der Code entspricht 3.1.0; alle Funktionen
  und Tests bleiben unverändert.

### Geprüfter Release-Stand

3.1.1 enthält keine Änderungen am App-Code; geprüft bleibt damit der Stand aus 3.1.0: macOS 3.1.0 aus `Toolbox.dmg`, iOS 3.1.0 aus dem Tag `v3.1.0` im Simulator und Windows 3.1.0 aus `Toolbox-Setup.exe` liefen als Kette. Mac→iPhone, anschließend iPhone→Windows ohne Mac sowie drei gleichzeitige Peers inklusive eines verspäteten alten Mac-Stands laufen grün (`scripts/test-release-sync-chain.js`).

Nur auf echter Hardware geprüft werden können die native Windows-Oberfläche, SmartScreen/Firewall und echtes Bonjour/WLAN zwischen physischen Geräten.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
