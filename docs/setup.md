# GyroPlay Setup Guide

This guide covers the normal Android and Windows installation flow for GyroPlay v0.1.0.

Official releases are published at:

https://github.com/saiusesgithub/GyroPlay/releases

## Requirements

- Android ARM64 phone.
- Windows 10 or Windows 11 x64 PC.
- Phone and PC on the same Wi-Fi network or phone hotspot.
- Administrator permission on Windows for driver and firewall setup.

End users do not need Python, Flutter, Visual Studio, or the .NET SDK.

## Android Installation

1. Open the latest GyroPlay release.
2. Download the ARM64 APK.
3. If Android blocks installation, allow installs from the browser or file manager you used to open the APK.
4. Install GyroPlay.
5. Open the app and leave it on the Home or Pair Device page.

The current public APK is ARM64-only.

## Windows Installation

1. Download `GyroPlaySetup.exe` from the latest release.
2. Run the installer.
3. Approve the administrator prompt.
4. Allow setup to install or repair ViGEmBus if needed.
5. Allow setup to create the inbound Windows Firewall rule for UDP port `5005`.
6. Launch GyroPlay Desktop when setup finishes.

The installer places the desktop app and packaged engine under the standard Windows Program Files location. Runtime settings, logs, and pairing state are stored under the current user's LocalAppData.

## Pairing

1. Open GyroPlay Desktop.
2. Click **Start Engine**.
3. Confirm the desktop Home page shows a QR code.
4. Open the Android app.
5. Tap **Pair a PC** or open the **Pair Device** tab.
6. Tap **Scan QR Code**.
7. Scan the QR code shown in GyroPlay Desktop.
8. Wait for the phone to show **Connected**.

If QR pairing fails, refresh the pairing code in the desktop app and scan again.

## Manual Pairing

Manual pairing is available as a fallback.

1. In GyroPlay Desktop, note the local IPv4 address and manual pairing token.
2. In the Android app, open **Pair Device**.
3. Enter the PC IPv4 address and pairing token.
4. Tap **Connect**.

Use the IPv4 shown by GyroPlay Desktop. Some PCs have multiple network adapters, and Windows may show more than one address.

## Calibration

1. Open the controller screen on the phone.
2. Hold the phone in landscape orientation like a steering wheel.
3. Keep the phone centered.
4. Tap **Calibrate**.
5. Confirm the calibration prompt.

Calibrate again if your neutral steering position changes.

## Testing the Virtual Controller

Use Windows Game Controllers to confirm the virtual Xbox controller is visible.

1. Press `Win + R`.
2. Run:

```text
joy.cpl
```

3. Look for `Controller (XBOX 360 For Windows)`.
4. Open **Properties**.
5. Move the phone and press controls.
6. Confirm the joystick, triggers, and buttons react.

If the controller is missing, use **Setup & Diagnostics** in GyroPlay Desktop to repair the driver.

## Assetto Corsa Setup

1. Start GyroPlay Desktop and the engine.
2. Pair the phone.
3. Confirm the controller appears in `joy.cpl`.
4. Launch Assetto Corsa.
5. Open controller settings.
6. Bind steering, throttle, brake, gear up, gear down, and handbrake as needed.
7. Use the built-in **Assetto Corsa** profile as the starting point.
8. Adjust dead zone, max tilt angle, sensitivity, and smoothing from the Android Settings page.

Some games require manual remapping even when Windows detects the controller correctly.

## Firewall Notes

GyroPlay uses inbound UDP port `5005` on the PC.

The installer and desktop diagnostics can create or repair the GyroPlay-owned firewall rule:

- Name: `GyroPlay UDP 5005`
- Direction: inbound
- Protocol: UDP
- Port: `5005`

Do not expose UDP port `5005` to the public internet.

## Driver Notes

GyroPlay uses `vgamepad`, which depends on ViGEmBus for virtual Xbox controller output.

ViGEmBus is installed only when missing or repaired when unavailable. It is not automatically removed during GyroPlay uninstall because other applications may depend on it.

## Uninstall

1. Open Windows Settings.
2. Go to **Apps**.
3. Uninstall GyroPlay.
4. The uninstaller removes app files, shortcuts, and the GyroPlay firewall rule.
5. User data under LocalAppData is preserved unless you explicitly choose to remove it.

ViGEmBus is not removed by default.
