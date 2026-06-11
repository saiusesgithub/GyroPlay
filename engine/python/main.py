import argparse
import json
import os
import socket
import sys
import time
import uuid
from datetime import datetime, timezone

try:
    import vgamepad as vg
except ImportError:
    print("Error: vgamepad is not installed.")
    print("Install dependencies with: python -m pip install -r requirements.txt")
    sys.exit(1)


HOST = "0.0.0.0"
PORT = 5005
SOCKET_TIMEOUT_SECONDS = 0.05
SESSION_TIMEOUT_SECONDS = 3.0
LEFT_STICK_MIN = -32768
LEFT_STICK_MAX = 32767
TRIGGER_MAX = 255
SUPPORTED_VERSION = 1
DEFAULT_PAIRING_FILE = os.path.join(os.path.dirname(__file__), "pairing.json")

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


def parse_json_packet(data):
    try:
        packet = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON ({error})") from error

    if not isinstance(packet, dict):
        raise ValueError("JSON root must be an object")

    if packet.get("version") != SUPPORTED_VERSION:
        raise ValueError(f"version must equal {SUPPORTED_VERSION}")

    packet_type = packet.get("type")
    if not isinstance(packet_type, str):
        raise ValueError("type must be a string")

    return packet


def parse_arguments():
    parser = argparse.ArgumentParser(description="GyroPlay UDP controller engine")
    parser.add_argument(
        "--pairing-file",
        default=os.environ.get("GYROPLAY_PAIRING_FILE", DEFAULT_PAIRING_FILE),
        help="Path to the pairing state JSON file written by the desktop app.",
    )
    return parser.parse_args()


def load_pairing_info(pairing_file):
    if not os.path.exists(pairing_file):
        raise ValueError(f"pairing file is missing: {pairing_file}")

    try:
        with open(pairing_file, "r", encoding="utf-8") as file:
            pairing_info = json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"could not read pairing file {pairing_file} ({error})") from error

    if not isinstance(pairing_info, dict):
        raise ValueError("pairing file root must be an object")

    if pairing_info.get("version") != SUPPORTED_VERSION:
        raise ValueError(f"pairing file version must equal {SUPPORTED_VERSION}")

    pairing_token = pairing_info.get("pairing_token")
    if not isinstance(pairing_token, str) or not pairing_token:
        raise ValueError("pairing_token is missing from pairing file")

    expires_at_text = pairing_info.get("expires_at")
    if not isinstance(expires_at_text, str):
        raise ValueError("expires_at is missing from pairing file")

    try:
        expires_at = datetime.fromisoformat(expires_at_text)
    except ValueError as error:
        raise ValueError("expires_at is not a valid ISO timestamp") from error

    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if datetime.now(timezone.utc) >= expires_at.astimezone(timezone.utc):
        raise ValueError("pairing token expired. Refresh pairing code in the desktop app")

    return pairing_token


def validate_hello(packet, pairing_file):
    if packet.get("type") != "hello":
        raise ValueError('type must equal "hello"')

    device_name = packet.get("device_name", "Unknown device")
    if not isinstance(device_name, str):
        raise ValueError("device_name must be a string")

    pairing_token = packet.get("pairing_token")
    if not isinstance(pairing_token, str) or not pairing_token:
        raise ValueError("pairing_token is required")

    expected_token = load_pairing_info(pairing_file)
    if pairing_token != expected_token:
        raise ValueError("invalid pairing_token")

    return device_name


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


def parse_gamepad_update(packet, expected_session_id):
    if packet.get("type") != "gamepad_update":
        raise ValueError('type must equal "gamepad_update"')

    if packet.get("session_id") != expected_session_id:
        raise ValueError("invalid session_id")

    return {
        "left_x": parse_number(packet, "left_x", -1.0, 1.0),
        "throttle": parse_number(packet, "throttle", 0.0, 1.0),
        "brake": parse_number(packet, "brake", 0.0, 1.0),
        "gear_up": parse_bool(packet, "gear_up"),
        "gear_down": parse_bool(packet, "gear_down"),
        "handbrake": parse_bool(packet, "handbrake"),
    }


def parse_heartbeat(packet, expected_session_id):
    if packet.get("type") != "heartbeat":
        raise ValueError('type must equal "heartbeat"')

    if packet.get("session_id") != expected_session_id:
        raise ValueError("invalid session_id")


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


def send_hello_ack(udp_socket, address, session_id):
    packet = {
        "version": SUPPORTED_VERSION,
        "type": "hello_ack",
        "session_id": session_id,
    }
    udp_socket.sendto(json.dumps(packet).encode("utf-8"), address)


def print_event(message):
    print(message, flush=True)


def main():
    args = parse_arguments()
    pairing_file = os.path.abspath(args.pairing_file)

    print("GyroPlay Python UDP controller engine")
    print(f"Pairing file: {pairing_file}")
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
    print("Waiting for hello packets. Press Ctrl+C to stop.")

    session_address = None
    session_id = None
    last_session_packet_time = None
    last_packet_event_time = 0.0
    disconnected_reported = False

    try:
        send_neutral_state(gamepad)

        while True:
            try:
                data, address = udp_socket.recvfrom(4096)
            except socket.timeout:
                if (
                    session_id is not None
                    and last_session_packet_time is not None
                    and time.monotonic() - last_session_packet_time >= SESSION_TIMEOUT_SECONDS
                    and not disconnected_reported
                ):
                    print("Phone disconnected: no heartbeat/input for 3 seconds. Neutralizing controller.")
                    print_event("EVENT:PHONE_DISCONNECTED")
                    send_neutral_state(gamepad)
                    session_address = None
                    session_id = None
                    last_session_packet_time = None
                    disconnected_reported = True

                continue

            try:
                packet = parse_json_packet(data)
            except ValueError as error:
                print(f"Warning: malformed packet ignored: {error}")
                continue

            packet_type = packet.get("type")

            if packet_type == "hello":
                try:
                    device_name = validate_hello(packet, pairing_file)
                except ValueError as error:
                    print(f"Pairing rejected: {error}")
                    continue

                session_address = address
                session_id = uuid.uuid4().hex
                last_session_packet_time = time.monotonic()
                last_packet_event_time = 0.0
                disconnected_reported = False
                send_neutral_state(gamepad)
                send_hello_ack(udp_socket, address, session_id)
                print_event("EVENT:PHONE_CONNECTED")
                print(f"Phone connected: {device_name} from {address[0]}:{address[1]}")
                print(f"Session started: {session_id}")
                continue

            if session_id is None or session_address is None:
                print("Warning: packet ignored: no active session. Send hello first.")
                send_neutral_state(gamepad)
                continue

            if address != session_address:
                print(f"Ignoring packet from {address[0]}:{address[1]} while session is active.")
                continue

            if packet_type == "heartbeat":
                try:
                    parse_heartbeat(packet, session_id)
                except ValueError as error:
                    print(f"Warning: heartbeat ignored: {error}")
                    send_neutral_state(gamepad)
                    continue

                last_session_packet_time = time.monotonic()
                disconnected_reported = False
                continue

            if packet_type == "gamepad_update":
                try:
                    state = parse_gamepad_update(packet, session_id)
                except ValueError as error:
                    print(f"Warning: gamepad_update ignored: {error}")
                    send_neutral_state(gamepad)
                    continue

                apply_controller_state(gamepad, state)
                now = time.monotonic()
                last_session_packet_time = now
                if now - last_packet_event_time >= 1.0:
                    timestamp = datetime.now(timezone.utc).isoformat()
                    print_event(f"EVENT:PACKET_RECEIVED:{timestamp}")
                    last_packet_event_time = now
                disconnected_reported = False
                continue

            print(f"Warning: unsupported packet type ignored: {packet_type}")
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
