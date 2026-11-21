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
