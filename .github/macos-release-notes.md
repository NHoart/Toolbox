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

### New in 3.6.0

- **System language with English fallback:** the Mac app follows the system
  language and shows English whenever the system language is not available.
  German, English, Spanish and French are fully translated.
- **Number and date formats per region:** dates, numbers and prices follow the
  region of the system language, so `en-GB` uses British formatting while the
  interface stays English.
- **Localized network permission:** the prompt for the local network is shown in
  the system language as well.

### Updating from an older version

Versions **before 2.0.3** (for example 1.3.0 or 2.0.2) cannot install this
update automatically – the built-in updater stalls after the download. In that
case install the DMG manually once following the steps above. From 2.0.3 on, one
click on “Install and Restart” is enough, and the app restarts itself.

### Requirements

- macOS 27.2 or newer (Apple Silicon)
