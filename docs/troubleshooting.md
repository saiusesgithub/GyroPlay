# GyroPlay Troubleshooting

## Android Cannot Connect

- Confirm the phone and PC are on the same local network.
- Use the PC's IPv4 address shown in the WinUI desktop app.
- Confirm Windows Firewall allows inbound UDP port `5005`.
- If QR pairing fails, refresh the pairing code and scan again before the token expires.
- Avoid guest Wi-Fi networks that isolate devices from each other.

## Desktop Shows Engine Stopped

- Click `Start Engine` in the desktop app.
- If the packaged engine is missing during development, build it from `engine/python` with `.\build-engine.ps1`.
- Check the desktop log panel for engine startup errors.

## Virtual Controller Is Missing

- Open `joy.cpl` and look for `Controller (XBOX 360 For Windows)`.
- Install or repair ViGEmBus.
- Restart the GyroPlay engine after installing ViGEmBus.
- Run the installer as administrator so the driver and firewall rule can be configured.

## Steering Feels Wrong

- Hold the phone in landscape orientation like a steering wheel.
- Tap `Calibrate` while holding the neutral steering position.
- Use `Invert steering` if left and right are reversed.
- Open settings and adjust dead zone, max tilt, sensitivity, and smoothing.

## Pedals or Buttons Stick

- Release the touch control and wait for the engine safety timeout.
- Disconnect and reconnect from the Android app.
- Backgrounding the mobile app should reset all controls to neutral.

## Installer Build Fails

- Install Inno Setup 6.
- Confirm `installer/dependencies/ViGEmBus_1.22.0_x64_x86_arm64.exe` exists.
- Confirm `engine/python/.venv/Scripts/python.exe` exists and has `pyinstaller` installed.
- Run from the repository root:

```powershell
.\installer\build-installer.ps1
```

