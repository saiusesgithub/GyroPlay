# GyroPlay Python Controller Engine

This is the first proof-of-concept controller engine for GyroPlay.

It creates a virtual Xbox 360 controller with `vgamepad`, keeps the left joystick Y-axis centered, and smoothly moves the left joystick X-axis from center to full right, full right to full left, and full left back to center.

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

```powershell
python main.py
```

The script prints progress as it moves the virtual controller's left joystick. Stop it with `Ctrl+C`.

On shutdown, it centers both joysticks, releases all buttons, releases both triggers, and sends one final neutral controller state.
