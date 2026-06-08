# GyroPlay Python Controller Engine

This is the first proof-of-concept controller engine for GyroPlay.

It creates a virtual Xbox 360 controller with `vgamepad` and listens for UDP JSON packets that update the left joystick X-axis. The left joystick Y-axis stays centered.

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

The engine listens on `0.0.0.0:5005`. Test packets are sent to `127.0.0.1:5005` in this format:

```json
{
  "type": "gamepad_update",
  "left_x": 0.5
}
```

`left_x` is clamped between `-1.0` and `1.0`.

If the engine does not receive a valid packet for 500 milliseconds, it returns the left joystick to center.

Stop either script with `Ctrl+C`.

On shutdown, the engine centers both joysticks, releases all buttons, releases both triggers, sends one final neutral controller state, and closes the UDP socket.
