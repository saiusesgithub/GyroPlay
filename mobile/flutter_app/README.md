# GyroPlay Flutter App

This is the Android proof-of-concept mobile app for GyroPlay.

It sends racing controller state to the Python controller engine over UDP. The app uses Dart's built-in `RawDatagramSocket` for networking and `sensors_plus` for phone-tilt steering.

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
4. The controller screen runs in landscape orientation.
5. Hold the phone like a steering wheel.
6. Tap `Calibrate`.
7. Rotate the phone left and right like a steering wheel.
8. Watch the Python engine console and `joy.cpl` for changing controller state.

About 45 degrees of left/right roll maps to full steering. A 3 degree center dead zone and smoothing are applied to reduce shake. Visible angle updates are capped so the number is readable.

If steering moves in the wrong direction for your device orientation, enable `Invert steering`.

## Pedals And Buttons

The app has two large touch pedals:

- `Throttle`
- `Brake`

Touch or drag higher on a pedal to increase its value from `0.0` to `1.0`. Releasing the pedal resets it to `0.0`.

The app also has press-and-hold buttons:

- `Gear up`
- `Gear down`
- `Handbrake`

Releasing or canceling a touch releases the button state.

## Manual Slider Mode

Use the `Tilt` / `Manual` toggle to switch modes.

Manual mode keeps the debug steering slider available. Pedals and buttons continue to work in both modes.

## UDP Packet

The app sends the complete controller state about 60 times per second while connected:

```json
{
  "version": 1,
  "type": "gamepad_update",
  "left_x": 0.0,
  "throttle": 0.0,
  "brake": 0.0,
  "gear_up": false,
  "gear_down": false,
  "handbrake": false
}
```

Tap `Disconnect` to send a neutral state, close the UDP socket, and reset all controls.
