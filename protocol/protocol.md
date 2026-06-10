# GyroPlay UDP Protocol

GyroPlay uses UDP JSON packets between the mobile app and the PC engine.

Current version: `1`

Default destination:

- Host: PC IPv4 address
- Port: `5005`

## Pairing Flow

1. Mobile sends `hello`.
2. PC replies with `hello_ack`.
3. Mobile stores the returned `session_id`.
4. Mobile includes `session_id` in every `heartbeat` and `gamepad_update` packet.
5. PC rejects controller packets with a missing or invalid `session_id`.

## Packet: hello

Sent by the mobile app before controller input starts.

```json
{
  "version": 1,
  "type": "hello",
  "device_name": "Android Phone"
}
```

Fields:

- `version`: Protocol version. Must be `1`.
- `type`: Packet type. Must be `"hello"`.
- `device_name`: Human-readable device name. String.

## Packet: hello_ack

Sent by the PC engine in response to `hello`.

```json
{
  "version": 1,
  "type": "hello_ack",
  "session_id": "9f7b1b7f0cf7470dbb2dd2f0a58a6f1d"
}
```

Fields:

- `version`: Protocol version. Must be `1`.
- `type`: Packet type. Must be `"hello_ack"`.
- `session_id`: Generated session identifier. String.

## Packet: heartbeat

Sent by the mobile app every 1 second while connected.

```json
{
  "version": 1,
  "type": "heartbeat",
  "session_id": "9f7b1b7f0cf7470dbb2dd2f0a58a6f1d"
}
```

Fields:

- `version`: Protocol version. Must be `1`.
- `type`: Packet type. Must be `"heartbeat"`.
- `session_id`: Active session identifier from `hello_ack`.

## Packet: gamepad_update

Sent by the mobile app while connected. Current target rate is about 60 packets per second.

```json
{
  "version": 1,
  "type": "gamepad_update",
  "session_id": "9f7b1b7f0cf7470dbb2dd2f0a58a6f1d",
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
- `session_id`: Active session identifier from `hello_ack`.
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

## Timeout Behavior

If no valid `heartbeat` or `gamepad_update` packet is received for 3 seconds, the PC engine marks the phone disconnected and returns to a neutral controller state.

## Current PC Mapping

- `left_x`: Xbox 360 left joystick X-axis.
- `throttle`: Xbox 360 right trigger.
- `brake`: Xbox 360 left trigger.
- `gear_up`: Xbox 360 A button.
- `gear_down`: Xbox 360 X button.
- `handbrake`: Xbox 360 B button.
