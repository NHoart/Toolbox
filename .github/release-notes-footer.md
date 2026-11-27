## Verified release state

3.7.5 fixes the counter sync: the count and the automatic count speed now carry
separate change times, so changing only the speed on one device can no longer
overwrite a newer count from another device. It also forwards water logged from
the widget or via Siri to the running app, so those entries reach the other
devices immediately. The Windows test suite (52 tests) and the headless
Swift↔Windows interop test run with this release; the Xcode
builds for macOS and iOS are produced by the GitHub Actions workflows, and
`scripts/test-apple-localization.sh` verifies on the built bundles that every
app and widget catalog key resolves in German, Spanish and French and falls back
to English for unsupported languages. A test on physical devices, a real Wi-Fi
test, an update run and the native Windows interface are still outstanding.

## Checklist: first launch and three-device sync

**Install Windows**

- [ ] Start `Toolbox-Setup.exe` from the GitHub release.
- [ ] If Defender SmartScreen blocks the launch, click **More info** and then
  **Run anyway** in the warning window – the app starts despite the block.
- [ ] On first launch, allow the firewall permission for **Private networks**;
  the Wi-Fi network must be classified as “Private”.
- [ ] Open Toolbox, enter the same name as on the other devices under
  **Settings → Local network** and check that “Sync over Wi-Fi” is on.

**Connect Mac, iPhone and Windows**

- [ ] All devices must be on the same Wi-Fi network; disable client isolation in
  the router.
- [ ] Open Toolbox on all devices; allow **Local network** on the iPhone/iPad.
- [ ] Enter the same name on all devices under **Settings → Local network**.
- [ ] Choose **Search now** on all devices; the other devices are shown as
  connected.
- [ ] Mac → iPhone: change water or counter on the Mac and check the value on the
  iPhone.
- [ ] Later iPhone → Windows: open/connect Toolbox on the PC; the PC adopts the
  current state automatically.
- [ ] Three devices at once: a change on one device appears on the other two.

**If nothing arrives**

- [ ] Run “Search now” again and check the firewall and network profile.
- [ ] Let the time be synchronized automatically on all devices.
- [ ] Restart Toolbox on all devices and install the current version.

## Requirements

- macOS 27.2 or newer (Apple Silicon)
- Windows 10/11, 64-bit
