## Installationswege

| Weg | Installation |
| --- | --- |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **winget** (Windows 10/11) | `winget install --id NHoart.Toolbox -e` |

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

### Neu in 3.3.1

- **Direkter Abgleich zwischen Apple-Geräten wiederhergestellt:** In 3.3.0
  lieferte der Bonjour-Browser auf Mac und iPhone keine TXT-Daten, sodass der
  Namensfilter alle Peers verworfen hat. Die Apple-Geräte nahmen zwar
  Verbindungen an, suchten aber selbst keine Geräte mehr. 3.3.1 nutzt den
  passenden Browser-Descriptor und behebt das.
- **Alle Geräte zeigen die direkten Peers:** Mit drei Geräten im selben Namen
  zeigt jedes Gerät „Verbunden mit 2 Geräten“ statt nur der Windows-PC.
- **Windows ohne funktionale Änderung:** Die Windows-App entspricht 3.3.0; der
  Fix betrifft nur den Apple-Bonjour-Browser.

### Windows: Update von 3.1.x

Windows-Versionen vor 3.2.0 enthalten den Updater noch nicht. Einmalig
`Toolbox-Setup.exe` oben herunterladen, Toolbox schließen und den Installer über
die bestehende Installation laufen lassen – Deinstallieren ist nicht nötig, die
Daten bleiben erhalten. Da der Installer nicht signiert ist, kann der Defender
SmartScreen warnen – über **Weitere Informationen → Trotzdem ausführen** lässt
er sich starten. Ab 3.2.0 übernimmt das Auto-Update; 3.3.1 wird dort automatisch
angeboten.

### Geprüfter Release-Stand

Die Xcode-Builds für macOS und iOS (3.3.1) liefen mit Xcode 27.2 fehlerfrei
durch. Die Windows-Tests (32) und der Headless-Sync-Smoke-Test sind grün; der
Swift↔Windows-Interop-Test bestätigt den Abgleich mit Mac, iPhone und Windows
sowie die Namensfilterung. Zusätzlich wurde der direkte Apple-Verbindungsaufbau
headless mit zwei Instanzen geprüft. Ein Test auf physischen Geräten mit 3.3.1,
ein echter WLAN-Test und die native Windows-Oberfläche stehen noch aus.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
