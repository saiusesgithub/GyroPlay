# GyroPlay Troubleshooting

Use this guide when pairing, controller output, installer setup, or APK installation does not behave as expected.

## No ACK Received

**Symptom:** The Android app says it did not receive an ACK from the desktop.

**Likely causes:**

- The engine is not running.
- The phone and PC are not on the same network.
- Windows Firewall is blocking UDP port `5005`.
- The pairing token expired.

**Fixes:**

1. Open GyroPlay Desktop and click **Start Engine**.
2. Refresh the pairing code.
3. Scan the QR code again.
4. Confirm both devices are on the same Wi-Fi or hotspot.
5. Open **Setup & Diagnostics** and run **Repair Firewall**.

## QR Code Scans but Phone Does Not Connect

**Symptom:** The QR scanner closes, but the app stays disconnected or returns to pairing.

**Likely causes:**

- The QR code expired.
- The desktop engine was stopped after the QR code was generated.
- The PC IP in the QR code is not reachable from the phone.

**Fixes:**

1. Refresh the QR code in GyroPlay Desktop.
2. Start the engine.
3. Scan again.
4. If the PC has multiple network adapters, try manual pairing with the IPv4 address for the active Wi-Fi or hotspot adapter.

## Wrong IP Shown

**Symptom:** GyroPlay Desktop shows an IP address that the phone cannot reach.

**Likely causes:**

- The PC has Ethernet, Wi-Fi, VPN, virtual adapters, or hotspot interfaces.
- The phone is connected to a different network.

**Fixes:**

1. Disable VPN temporarily.
2. Confirm the PC and phone are on the same network.
3. Use `ipconfig` on Windows to find the active adapter IPv4 address.
4. Enter that address manually in the Android app.

## Firewall Blocking UDP 5005

**Symptom:** Pairing fails even though the engine is running and the IP is correct.

**Likely causes:**

- The inbound firewall rule is missing, disabled, or configured for the wrong port.

**Fixes:**

1. Open GyroPlay Desktop.
2. Go to **Setup & Diagnostics**.
3. Check **Firewall status**.
4. Click **Repair Firewall** and approve the administrator prompt.

## ViGEmBus Missing or Unavailable

**Symptom:** The engine starts, but no virtual controller appears in Windows.

**Likely causes:**

- ViGEmBus is not installed.
- ViGEmBus is installed but unavailable.
- A restart is required after driver installation.

**Fixes:**

1. Open **Setup & Diagnostics**.
2. Check **Driver status**.
3. Click **Repair Driver** if needed.
4. Restart Windows if setup reports that a restart is required.

## Virtual Controller Not Visible in joy.cpl

**Symptom:** `joy.cpl` does not show `Controller (XBOX 360 For Windows)`.

**Fixes:**

1. Start GyroPlay Desktop.
2. Start the engine.
3. Repair ViGEmBus from diagnostics.
4. Restart the engine.
5. Reopen `joy.cpl`.

## Engine Fails to Start

**Symptom:** GyroPlay Desktop shows the engine as stopped or failed.

**Likely causes:**

- The packaged engine executable is missing.
- ViGEmBus is unavailable.
- Another engine process is already running.

**Fixes:**

1. Use the latest Windows installer.
2. Open **Setup & Diagnostics** and check **Engine executable**.
3. Run **Repair Setup**.
4. If the issue persists, open the log folder from diagnostics and include logs in a GitHub issue.

## Steering Does Not React Until Large Tilt

**Symptom:** Small steering movements do not affect the game.

**Likely causes:**

- Dead zone is too high.
- Max tilt angle is too high.
- The game has its own steering dead zone.

**Fixes:**

1. Calibrate the phone while centered.
2. Lower the GyroPlay dead zone.
3. Use the built-in Assetto Corsa profile as a baseline.
4. Check the game's controller dead-zone settings.

## Controls Stay Pressed

**Symptom:** Throttle, brake, handbrake, or gear controls stay active.

**Likely causes:**

- The app was interrupted during touch input.
- The connection dropped while a control was pressed.

**Fixes:**

1. Lift your finger from all controls.
2. Exit the controller screen.
3. Disconnect and reconnect.
4. The engine safety timeout should also reset inputs if packets stop.

## Phone and PC Not on Same Network

**Symptom:** Pairing never completes.

**Fixes:**

1. Connect both devices to the same Wi-Fi network.
2. Avoid guest networks that isolate devices.
3. Try using the phone hotspot and connect the PC to it.

## Installer Restart Required

**Symptom:** Setup completes but says Windows should restart.

**Fix:**

Restart Windows before launching GyroPlay. Driver setup may not be available until after reboot.

## Windows SmartScreen Warning

**Symptom:** Windows warns that the installer is from an unknown publisher.

**Cause:**

GyroPlay v0.1.0 is not code-signed yet.

**Fix:**

Download only from the official releases page:

https://github.com/saiusesgithub/GyroPlay/releases

Then choose **More info** and **Run anyway** if you trust the release.

## APK Installation Blocked

**Symptom:** Android blocks the APK.

**Fixes:**

1. Download the APK from the official GitHub Release.
2. Allow installation from unknown sources for your browser or file manager.
3. Install again.

## Verify Release Checksums

Each release includes SHA256 checksum files.

On Windows:

```powershell
Get-FileHash -Algorithm SHA256 .\GyroPlaySetup.exe
```

Compare the hash with `GyroPlaySetup.exe.sha256` from the release.

For Android, compare the APK hash with `GyroPlay-Android-arm64.apk.sha256`.

## Still Stuck?

Open an issue:

https://github.com/saiusesgithub/GyroPlay/issues

Include:

- Android version.
- Windows version.
- Whether `joy.cpl` shows the controller.
- Desktop diagnostics status.
- A short description of your network setup.
- Logs with pairing tokens removed.
