## Downloads

| Plattform | Installation |
| --- | --- |
| **macOS** 27.2 oder neuer (Apple Silicon) | [Toolbox.dmg](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox.dmg) |
| **Windows** 10/11, 64 Bit | [Toolbox-Setup.exe](https://github.com/{{REPO}}/releases/download/{{TAG}}/Toolbox-Setup.exe) |
| **Windows** 10/11, 64 Bit (winget) | `winget install --id NHoart.Toolbox -e` |

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

### Neu in 3.3.0

- **Gemeinsamer Name für den WLAN-Sync:** Im Abschnitt **Lokales Netzwerk**
  der Einstellungen gibt es jetzt oben ein Namensfeld. Ohne Namen läuft kein
  Abgleich; der Status zeigt „Name fehlt“ und „Jetzt suchen“ ist deaktiviert.
- **Nur passende Geräte verbinden sich:** Das Gerät sucht wie bisher im WLAN,
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

Die Xcode-Builds für macOS und iOS liefen mit Xcode 27.2 fehlerfrei durch. Die
Windows-Tests (32) und der Headless-Sync-Smoke-Test sind grün; der
Swift↔Windows-Interop-Test bestätigt den Abgleich mit Mac, iPhone und Windows
sowie, dass ein Gerät mit anderem Namen weder Peer wird noch Daten erhält. Ein
echter WLAN-Test zwischen physischen Geräten und die native Windows-Oberfläche
konnten auf dem Mac nicht geprüft werden.

### Update von einer älteren Version

Versionen **vor 2.0.3** (zum Beispiel 1.3.0 oder 2.0.2) können dieses Update
noch nicht automatisch installieren – der eingebaute Updater bleibt nach dem
Herunterladen hängen. Bitte die DMG in diesem Fall einmal manuell nach den
Schritten oben installieren. Ab 2.0.3 genügt ein Klick auf
„Installieren und neu starten“, danach startet sich die App selbst neu.

### Voraussetzungen

- macOS 27.2 oder neuer (Apple Silicon)
