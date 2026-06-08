# GyroPlay Flutter App

This is the first Android proof-of-concept mobile app for GyroPlay.

It sends steering values to the Python controller engine over UDP. The app uses Dart's built-in `RawDatagramSocket` and sends JSON packets to UDP port `5005`.

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

## Test

1. Find the PC's IPv4 address on the same network as the phone or emulator.
2. Enter that IPv4 address in the app.
3. Tap `Connect`.
4. Move the steering slider.
5. Watch the Python engine console for received `left_x` values.

The app sends packets in this format:

```json
{
  "type": "gamepad_update",
  "left_x": 0.5
}
```

Tap `Disconnect` to send `left_x = 0.0`, close the UDP socket, and reset the slider to center.
