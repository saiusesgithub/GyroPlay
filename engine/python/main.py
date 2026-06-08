import sys
import time

try:
    import vgamepad as vg
except ImportError:
    print("Error: vgamepad is not installed.")
    print("Install dependencies with: python -m pip install -r requirements.txt")
    sys.exit(1)


STEP_DELAY_SECONDS = 0.02
STEPS_PER_MOVE = 100


def move_left_x(gamepad, start_value, end_value, label):
    print(label)

    for step in range(STEPS_PER_MOVE + 1):
        progress = step / STEPS_PER_MOVE
        x_value = int(start_value + (end_value - start_value) * progress)

        gamepad.left_joystick(x_value=x_value, y_value=0)
        gamepad.update()

        time.sleep(STEP_DELAY_SECONDS)


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


def main():
    print("GyroPlay Python controller engine proof of concept")
    print("Creating virtual Xbox 360 controller...")

    try:
        gamepad = vg.VX360Gamepad()
    except Exception as error:
        print("Error: failed to initialize the virtual Xbox 360 controller.")
        print("Make sure ViGEmBus is installed and running on Windows.")
        print(f"Details: {error}")
        sys.exit(1)

    print("Controller initialized.")
    print("Left joystick Y-axis will stay centered.")
    print("Press Ctrl+C to stop.")

    try:
        send_neutral_state(gamepad)

        while True:
            move_left_x(gamepad, 0, 32767, "Moving left joystick X-axis: center to full right...")
            move_left_x(gamepad, 32767, -32768, "Moving left joystick X-axis: full right to full left...")
            move_left_x(gamepad, -32768, 0, "Moving left joystick X-axis: full left to center...")
            print("Sequence complete. Repeating...")
    except KeyboardInterrupt:
        print("\nCtrl+C received. Shutting down...")
    finally:
        send_neutral_state(gamepad)
        print("Controller returned to neutral. Goodbye.")


if __name__ == "__main__":
    main()
