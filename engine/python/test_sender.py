import json
import socket
import time


HOST = "127.0.0.1"
PORT = 5005
STEP_DELAY_SECONDS = 0.02
STEPS_PER_MOVE = 100


def send_left_x(udp_socket, left_x):
    packet = {
        "type": "gamepad_update",
        "left_x": left_x,
    }
    udp_socket.sendto(json.dumps(packet).encode("utf-8"), (HOST, PORT))
    print(f"Sent steering value: {left_x:.3f}")


def sweep(udp_socket, start_value, end_value, label):
    print(label)

    for step in range(STEPS_PER_MOVE + 1):
        progress = step / STEPS_PER_MOVE
        left_x = start_value + (end_value - start_value) * progress
        send_left_x(udp_socket, left_x)
        time.sleep(STEP_DELAY_SECONDS)


def main():
    print(f"Sending UDP gamepad updates to {HOST}:{PORT}")
    print("Press Ctrl+C to stop.")

    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        while True:
            sweep(udp_socket, 0.0, 1.0, "Sweeping center to right...")
            sweep(udp_socket, 1.0, -1.0, "Sweeping right to left...")
            sweep(udp_socket, -1.0, 0.0, "Sweeping left to center...")
            print("Sequence complete. Repeating...")
    except KeyboardInterrupt:
        print("\nCtrl+C received. Sender stopped.")
    finally:
        udp_socket.close()


if __name__ == "__main__":
    main()
