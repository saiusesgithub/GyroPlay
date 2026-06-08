# GyroPlay Flutter App

This is the Android proof-of-concept mobile app for GyroPlay.

It sends steering values to the Python controller engine over UDP. The app uses Dart's built-in `RawDatagramSocket` for networking and `sensors_plus` for phone-tilt steering.

## Setup

1. Install Flutter and Android Studio.
2. Start an Android emulator or connect an Android phone with USB debugging enabled.
3. Open PowerShell from the repository root.
4. Install Flutter dependencies:

```powershell
cd mobile\flutter_app
flutter pub get
```

## Run

Start the Python engine on the PC first:

```powershell
cd engine\python
python main.py
```

Then run the Flutter app:

```powershell
cd mobile\flutter_app
flutter run
```

## Test Tilt Steering

1. Put the phone and PC on the same network.
2. Enter the PC IPv4 address in the app.
3. Tap `Connect`.
4. Hold the phone in landscape orientation like a steering wheel.
5. Tap `Calibrate`.
6. Rotate the phone left and right like a steering wheel.
7. Watch the Python engine console and `joy.cpl` for changing `left_x` values.

The app calibrates the current roll angle as neutral. Steering is based on the current roll angle minus that calibrated neutral angle.

About 45 degrees of left/right roll maps to full steering. A 3 degree center dead zone and smoothing are applied to reduce shake. Visible angle updates are capped so the number is readable.

If steering moves in the wrong direction for your device orientation, enable `Invert steering`.

## Manual Slider Mode

Use the `Tilt steering` / `Manual slider` toggle to switch modes.

Manual slider mode keeps the previous debug slider available. Moving the slider sends the same UDP packet format:

```json
{
  "type": "gamepad_update",
  "left_x": 0.5
}
```

Tap `Disconnect` to send `left_x = 0.0`, close the UDP socket, and reset steering to center.
