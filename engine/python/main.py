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


def left_x_to_gamepad_value(left_x):
    if left_x >= 0:
        return int(left_x * LEFT_STICK_MAX)

    return int(left_x * abs(LEFT_STICK_MIN))


def send_neutral_state(gamepad):
    print("Sending neutral controller state...")

    gamepad.left_joystick(x_value=0, y_value=0)
    gamepad.right_joystick(x_value=0, y_value=0)
    gamepad.left_trigger(value=0)
    gamepad.right_trigger(value=0)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_A)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_B)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_X)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_Y)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_START)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT)
    gamepad.release_button(button=vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT)
    gamepad.update()


def parse_packet(data):
    try:
        packet = json.loads(data.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        print(f"Warning: malformed packet ignored: invalid JSON ({error})")
        return None

    if not isinstance(packet, dict):
        print("Warning: malformed packet ignored: JSON root must be an object")
        return None

    if packet.get("type") != "gamepad_update":
        print('Warning: malformed packet ignored: type must equal "gamepad_update"')
        return None

    left_x = packet.get("left_x")
    if not isinstance(left_x, (int, float)) or isinstance(left_x, bool):
        print("Warning: malformed packet ignored: left_x must be a number")
        return None

    return max(-1.0, min(1.0, float(left_x)))


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

    first_sender = None
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
                    print("Safety timeout: no valid packet for 500 ms. Returning joystick to center.")
                    gamepad.left_joystick(x_value=0, y_value=0)
                    gamepad.update()
                    timeout_reported = True

                continue

            left_x = parse_packet(data)
            if left_x is None:
                continue

            if first_sender is None:
                first_sender = address[0]
                print(f"First valid packet received from {first_sender}")

            print(f"Received steering value: {left_x:.3f}")
            gamepad.left_joystick(x_value=left_x_to_gamepad_value(left_x), y_value=0)
            gamepad.update()

            last_valid_packet_time = time.monotonic()
            timeout_reported = False
    except KeyboardInterrupt:
        print("\nCtrl+C received. Shutting down...")
    finally:
        send_neutral_state(gamepad)
        udp_socket.close()
        print("UDP socket closed.")
        print("Controller returned to neutral. Goodbye.")


if __name__ == "__main__":
    main()
