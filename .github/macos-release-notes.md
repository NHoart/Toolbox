## Toolbox for macOS

Download `Toolbox.dmg` above.

### Installation

1. Open `Toolbox.dmg` and drag `Toolbox` into the **Applications** folder.
2. Launch the app once. Because it is not signed with an Apple Developer
   certificate and not notarized, macOS blocks the first launch:
   - **Right-click** (or Control-click) `Toolbox` → **Open** → choose **Open**
     again in the dialog, or
   - **System Settings → Privacy & Security** → click **Open Anyway** below
     “Toolbox was blocked”, or
   - in Terminal: `xattr -dr com.apple.quarantine /Applications/Toolbox.app`

### New in 3.7.5

- **No more unexpected counter resets when syncing:** the counter value and the
  automatic count speed now carry separate change times. Changing only the speed
  on one device therefore no longer makes its older count look newer, so it can
  no longer overwrite a newer count from another device during the next sync.
- **Widget and Siri entries reach the other devices immediately:** water logged
  from the widget or via Siri while the app is running is now forwarded to the
  running app and synced right away instead of waiting for the next change.
- **Auto count keeps running on a speed update:** when only the automatic speed
  arrives from another device, a running auto count continues at the new speed.
  A newer counter value from another device still stops it.
- **No other functional changes on macOS:** the tools, water tracker, widget and
  Siri shortcuts behave as in 3.7.4.

### New in 3.7.4

- **No more unexpected water amounts when syncing:** amounts and sizes (glass,
  bottle, daily goal) now carry separate change times. Changing a size on one
  device therefore no longer makes its older water level look newer, so it can
  no longer overwrite amounts logged on another device during the next sync.
- **Undo stays with its day:** the water tracker only syncs the undo history of
  the current day; yesterday's entries can no longer appear in today's undo
  list.
- **No other functional changes on macOS:** the tools, widget and Siri shortcuts
  behave as in 3.7.2.

### New in 3.7.2

- **The real app icon in the sidebar:** the header now shows the Toolbox app
  icon instead of the old water-drop badge, so it matches the icon in the Dock,
  the Finder and the app switcher.
- **No other functional changes on macOS:** the tools, sync and widget behave
  exactly as in 3.7.1.

### New in 3.7.1

- **Widget labels fixed:** the two buttons in the water widget now show
  “Glass” and “Bottle” again instead of a raw debug string, so the medium
  widget is readable at a glance.
- **Localized labels:** the buttons follow the app language – “Glas” and
  “Flasche” in German, “Vaso” and “Botella” in Spanish, “Verre” and
  “Bouteille” in French – and fall back to English for unsupported languages.

### Updating from an older version

Versions **before 2.0.3** (for example 1.3.0 or 2.0.2) cannot install this
update automatically – the built-in updater stalls after the download. In that
case install the DMG manually once following the steps above. From 2.0.3 on, one
click on “Install and Restart” is enough, and the app restarts itself.

### Requirements

- macOS 27.2 or newer (Apple Silicon)
