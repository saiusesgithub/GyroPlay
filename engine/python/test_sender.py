import json
import socket
import time


HOST = "127.0.0.1"
PORT = 5005
STEP_DELAY_SECONDS = 0.02
STEPS_PER_MOVE = 100
HEARTBEAT_INTERVAL_SECONDS = 1.0


def send_packet(udp_socket, packet):
    udp_socket.sendto(json.dumps(packet).encode("utf-8"), (HOST, PORT))


def connect(udp_socket):
    packet = {
        "version": 1,
        "type": "hello",
        "device_name": "Python Test Sender",
    }
    send_packet(udp_socket, packet)
    udp_socket.settimeout(3.0)

    data, _ = udp_socket.recvfrom(4096)
    response = json.loads(data.decode("utf-8"))

    if response.get("type") != "hello_ack" or not isinstance(response.get("session_id"), str):
        raise RuntimeError(f"Unexpected hello response: {response}")

    udp_socket.settimeout(None)
    return response["session_id"]


def send_heartbeat(udp_socket, session_id):
    packet = {
        "version": 1,
        "type": "heartbeat",
        "session_id": session_id,
    }
    send_packet(udp_socket, packet)


def send_left_x(udp_socket, session_id, left_x):
    packet = {
        "version": 1,
        "type": "gamepad_update",
        "session_id": session_id,
        "left_x": left_x,
        "throttle": 0.0,
        "brake": 0.0,
        "gear_up": False,
        "gear_down": False,
        "handbrake": False,
    }
    send_packet(udp_socket, packet)
    print(f"Sent steering value: {left_x:.3f}")


def sweep(udp_socket, session_id, start_value, end_value, label):
    print(label)
    last_heartbeat_time = 0.0

    for step in range(STEPS_PER_MOVE + 1):
        now = time.monotonic()
        if now - last_heartbeat_time >= HEARTBEAT_INTERVAL_SECONDS:
            send_heartbeat(udp_socket, session_id)
            last_heartbeat_time = now

        progress = step / STEPS_PER_MOVE
        left_x = start_value + (end_value - start_value) * progress
        send_left_x(udp_socket, session_id, left_x)
        time.sleep(STEP_DELAY_SECONDS)


def main():
    print(f"Sending UDP gamepad updates to {HOST}:{PORT}")
    print("Press Ctrl+C to stop.")

    udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        session_id = connect(udp_socket)
        print(f"Connected with session_id: {session_id}")

        while True:
            sweep(udp_socket, session_id, 0.0, 1.0, "Sweeping center to right...")
            sweep(udp_socket, session_id, 1.0, -1.0, "Sweeping right to left...")
            sweep(udp_socket, session_id, -1.0, 0.0, "Sweeping left to center...")
            print("Sequence complete. Repeating...")
    except KeyboardInterrupt:
        print("\nCtrl+C received. Sender stopped.")
    finally:
        udp_socket.close()


if __name__ == "__main__":
    main()
