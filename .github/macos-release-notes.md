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

### New in 3.7.0

- **Current language at a glance:** the macOS settings now show which language
  Toolbox is currently using, right next to the button that opens the macOS
  Language & Region settings.
- **Uses Apple's per-app language setting:** there is no separate in-app
  override; choosing a language for Toolbox under **Applications** in System
  Settings applies on the next launch.
- **Fully localized:** the new card is translated into German, Spanish and
  French, with English as the fallback.

### Updating from an older version

Versions **before 2.0.3** (for example 1.3.0 or 2.0.2) cannot install this
update automatically – the built-in updater stalls after the download. In that
case install the DMG manually once following the steps above. From 2.0.3 on, one
click on “Install and Restart” is enough, and the app restarts itself.

### Requirements

- macOS 27.2 or newer (Apple Silicon)
