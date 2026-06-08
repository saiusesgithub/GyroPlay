import json
import socket
import sys
import time

try:
    import vgamepad as vg
except ImportError:
    print("Error: vgamepad is not installed.")
    print("Install dependencies with: python -m pip install -r requirements.txt")
    sys.exit(1)


HOST = "0.0.0.0"
PORT = 5005
SOCKET_TIMEOUT_SECONDS = 0.05
SAFETY_TIMEOUT_SECONDS = 0.5
LEFT_STICK_MIN = -32768
LEFT_STICK_MAX = 32767
TRIGGER_MAX = 255
SUPPORTED_VERSION = 1

BUTTON_MAP = {
    "gear_up": vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    "gear_down": vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    "handbrake": vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
}

ALL_BUTTONS = [
    vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,
]


def clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def left_x_to_gamepad_value(left_x):
    if left_x >= 0:
        return int(left_x * LEFT_STICK_MAX)

    return int(left_x * abs(LEFT_STICK_MIN))


def trigger_to_gamepad_value(value):
    return int(clamp(value, 0.0, 1.0) * TRIGGER_MAX)


def send_neutral_state(gamepad):
    gamepad.left_joystick(x_value=0, y_value=0)
    gamepad.right_joystick(x_value=0, y_value=0)
    gamepad.left_trigger(value=0)
    gamepad.right_trigger(value=0)

    for button in ALL_BUTTONS:
        gamepad.release_button(button=button)

    gamepad.update()


def parse_number(packet, field, minimum, maximum):
    value = packet.get(field)
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be a number")

    return clamp(float(value), minimum, maximum)


def parse_bool(packet, field):
    value = packet.get(field)
    if not isinstance(value, bool):
        raise ValueError(f"{field} must be true or false")

    return value


def parse_packet(data):
    try:
        packet = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON ({error})") from error

    if not isinstance(packet, dict):
        raise ValueError("JSON root must be an object")

    if packet.get("version") != SUPPORTED_VERSION:
        raise ValueError(f"version must equal {SUPPORTED_VERSION}")

    if packet.get("type") != "gamepad_update":
        raise ValueError('type must equal "gamepad_update"')

    return {
        "left_x": parse_number(packet, "left_x", -1.0, 1.0),
        "throttle": parse_number(packet, "throttle", 0.0, 1.0),
        "brake": parse_number(packet, "brake", 0.0, 1.0),
        "gear_up": parse_bool(packet, "gear_up"),
        "gear_down": parse_bool(packet, "gear_down"),
        "handbrake": parse_bool(packet, "handbrake"),
    }


def apply_controller_state(gamepad, state):
    gamepad.left_joystick(
        x_value=left_x_to_gamepad_value(state["left_x"]),
        y_value=0,
    )
    gamepad.right_trigger(value=trigger_to_gamepad_value(state["throttle"]))
    gamepad.left_trigger(value=trigger_to_gamepad_value(state["brake"]))

    for field, button in BUTTON_MAP.items():
        if state[field]:
            gamepad.press_button(button=button)
        else:
            gamepad.release_button(button=button)

    gamepad.update()


def main():
    print("GyroPlay Python UDP controller engine")
    print("Creating virtual Xbox 360 controller...")

    try:
        gamepad = vg.VX360Gamepad()
    except Exception as error:
        print("Error: failed to initialize the virtual Xbox 360 controller.")
        print("Make sure ViGEmBus is installed and running on Windows.")
        print(f"Details: {error}")
        sys.exit(1)

    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        udp_socket.bind((HOST, PORT))
        udp_socket.settimeout(SOCKET_TIMEOUT_SECONDS)
    except OSError as error:
        udp_socket.close()
        print(f"Error: failed to start UDP server on {HOST}:{PORT}.")
        print(f"Details: {error}")
        sys.exit(1)

    print("Controller initialized.")
    print(f"UDP server listening on {HOST}:{PORT}")
    print("Waiting for gamepad_update packets. Press Ctrl+C to stop.")

    session_address = None
    last_valid_packet_time = None
    timeout_reported = False

    try:
        send_neutral_state(gamepad)

        while True:
            try:
                data, address = udp_socket.recvfrom(4096)
            except socket.timeout:
                if (
                    last_valid_packet_time is not None
                    and not timeout_reported
                    and time.monotonic() - last_valid_packet_time >= SAFETY_TIMEOUT_SECONDS
                ):
                    print("Safety timeout: no valid packet for 500 ms. Neutralizing controller.")
                    send_neutral_state(gamepad)
                    session_address = None
                    timeout_reported = True

                continue

            if session_address is not None and address != session_address:
                print(f"Ignoring packet from {address[0]}:{address[1]} while session is active.")
                send_neutral_state(gamepad)
                continue

            try:
                state = parse_packet(data)
            except ValueError as error:
                print(f"Warning: malformed packet ignored: {error}")
                send_neutral_state(gamepad)
                continue

            if session_address is None:
                session_address = address
                print(f"Valid controller session started from {address[0]}:{address[1]}")

            apply_controller_state(gamepad, state)
            last_valid_packet_time = time.monotonic()
            timeout_reported = False
    except KeyboardInterrupt:
        print("\nCtrl+C received. Shutting down...")
    finally:
        print("Sending neutral controller state...")
        send_neutral_state(gamepad)
        udp_socket.close()
        print("UDP socket closed.")
        print("Controller returned to neutral. Goodbye.")


if __name__ == "__main__":
    main()
