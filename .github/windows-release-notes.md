## Toolbox for Windows

Windows 10/11, 64-bit. Download `Toolbox-Setup.exe` above, run it and follow the
instructions – the installation runs in the user profile without administrator
rights.

Because the installer is not signed, Windows SmartScreen may show a warning on
the first launch. **More info → Run anyway** starts the app.

### New in 3.7.5

- **No more unexpected counter resets when syncing:** the counter value and the
  automatic count speed now carry separate change times. Changing only the speed
  on the Windows PC therefore no longer makes its older count look newer, so it
  can no longer overwrite a newer count from the Mac or iPhone during the next
  sync – and the other way round.
- **Water from the Apple widget or Siri arrives immediately:** while the updated
  iPhone, iPad or Mac app is running, entries made in its widget or via Siri are
  now passed on to the Windows PC right away instead of waiting for another
  change.
- **No other functional changes on Windows:** the tools, water tracker, installer
  update check and Wi-Fi sync behave as in 3.7.4.

### New in 3.7.4

- **No more unexpected water amounts when syncing:** amounts and sizes (glass,
  bottle, daily goal) now carry separate change times. Changing a size on the
  Windows PC therefore no longer makes its older water level look newer, so it
  can no longer overwrite amounts logged on the Mac or iPhone during the next
  sync – and the other way round.
- **Undo stays with its day:** the water tracker only syncs the undo history of
  the current day.
- **No other functional changes on Windows:** the tools, the installer update
  check and the Wi-Fi sync behave as in 3.7.3.

### New in 3.7.2

- **Updated brand header:** the title bar now shows the Toolbox app icon at the
  same size as the macOS sidebar, together with the app name and the localized
  subtitle (“Everyday tools”, “Alltagswerkzeuge”, “Herramientas diarias”,
  “Outils du quotidien”).
- **Microsoft Store version:** Settings no longer contain an Updates section.
  The Microsoft Store keeps Toolbox up to date automatically.
- **Installer version:** no functional change; the GitHub update check remains
  in Settings, and the tools and the Wi-Fi sync work exactly as before.

### New in 3.7.1

- **No functional changes on Windows:** the app is identical to 3.7.0 and keeps
  the system language support with English fallback. This release only fixes
  the labels in the Apple water widget.

### Windows: updating from 3.1.x

Windows versions before 3.2.0 do not contain the updater yet. Once, download
`Toolbox-Setup.exe` above, close Toolbox and run the installer over the existing
installation – uninstalling is not necessary, the data is preserved. Because the
installer is not signed, Defender SmartScreen may warn – **More info → Run
anyway** starts it. From 3.2.0 on the auto-update takes over; 3.7.2 is offered
automatically there.

### Sync with Mac and iPhone

The Windows app uses the same sync over the local Wi-Fi network as the Apple app.
Enter the same name on all devices in Settings under **Local network**; without a
name the sync is off. Only devices with this name connect. Mac, iPhone and
Windows PC can be connected at the same time; changes are also passed on through
a third device that acts as a bridge.

There is no server and no account; the data stays on the devices.
