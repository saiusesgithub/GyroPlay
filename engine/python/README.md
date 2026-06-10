# GyroPlay Python Controller Engine

This is the first proof-of-concept controller engine for GyroPlay.

It creates a virtual Xbox 360 controller with `vgamepad` and listens for UDP JSON packets from the mobile app. The engine performs a basic token-based hello/ack pairing flow, validates `session_id`, and maps racing controls to the virtual controller.

## Windows Setup

1. Install Python 3.10 or newer.
2. Install ViGEmBus for virtual controller support:
   - https://github.com/ViGEm/ViGEmBus/releases
3. Open PowerShell in this directory:

```powershell
cd engine\python
```

4. Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

5. Install dependencies:

```powershell
python -m pip install -r requirements.txt
```

## Run

Start the UDP controller engine:

```powershell
python main.py
```

In another PowerShell window, activate the same virtual environment and run the test sender:

```powershell
cd engine\python
.\.venv\Scripts\Activate.ps1
python test_sender.py
```

The test sender repeatedly sends smooth steering values from center to right, right to left, and left back to center.

The engine listens on `0.0.0.0:5005`. The desktop app writes the active short-lived pairing token to `pairing.json`. Clients first send:

```json
{
  "version": 1,
  "type": "hello",
  "device_name": "Android Phone",
  "pairing_token": "A1B2C3D4"
}
```

The engine replies with:

```json
{
  "version": 1,
  "type": "hello_ack",
  "session_id": "9f7b1b7f0cf7470dbb2dd2f0a58a6f1d"
}
```

Gamepad packets then include that `session_id`:

```json
{
  "version": 1,
  "type": "gamepad_update",
  "session_id": "9f7b1b7f0cf7470dbb2dd2f0a58a6f1d",
  "left_x": 0.5,
  "throttle": 0.0,
  "brake": 0.0,
  "gear_up": false,
  "gear_down": false,
  "handbrake": false
}
```

`left_x` is clamped between `-1.0` and `1.0`. `throttle` and `brake` are clamped between `0.0` and `1.0`.

If the engine does not receive a valid heartbeat or input packet for 3 seconds, it marks the phone disconnected, centers steering, releases both triggers, and releases all buttons.

Stop either script with `Ctrl+C`.

On shutdown, the engine centers both joysticks, releases all buttons, releases both triggers, sends one final neutral controller state, and closes the UDP socket.
