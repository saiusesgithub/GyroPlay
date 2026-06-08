# GyroPlay UDP Protocol

GyroPlay uses UDP JSON packets from the mobile app to the PC engine.

Current version: `1`

Default destination:

- Host: PC IPv4 address
- Port: `5005`

## Packet: gamepad_update

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

Fields:

- `version`: Protocol version. Must be `1`.
- `type`: Packet type. Must be `"gamepad_update"`.
- `left_x`: Steering axis. Number from `-1.0` to `1.0`.
  - `-1.0` means full left.
  - `0.0` means centered.
  - `1.0` means full right.
- `throttle`: Throttle pedal. Number from `0.0` to `1.0`.
  - `0.0` means released.
  - `1.0` means fully pressed.
- `brake`: Brake pedal. Number from `0.0` to `1.0`.
  - `0.0` means released.
  - `1.0` means fully pressed.
- `gear_up`: Gear up button state. Boolean.
- `gear_down`: Gear down button state. Boolean.
- `handbrake`: Handbrake button state. Boolean.

Receivers should clamp numeric fields to their valid ranges and reject packets with invalid field types.

## Current PC Mapping

- `left_x`: Xbox 360 left joystick X-axis.
- `throttle`: Xbox 360 right trigger.
- `brake`: Xbox 360 left trigger.
- `gear_up`: Xbox 360 A button.
- `gear_down`: Xbox 360 X button.
- `handbrake`: Xbox 360 B button.

If valid packets stop arriving for 500 milliseconds, the PC engine should return to a neutral controller state.
