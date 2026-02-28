#!/usr/bin/env python3

import subprocess
import time
import json
import os
import sys
import numpy as np

# Removed cv2 as it hangs on some setups. Using v4l2-ctl streams instead.

CONFIG_PATH = os.path.expanduser("~/.config/kamlux/config.json")
DEFAULT_CONFIG = {
    "device": "/dev/video0",
    "interval": 5,
    "smoothing_alpha": 0.2,
    "curve": [[0.0, 100.0], [0.5, 40.0], [0.8, 20.0], [1.0, 5.0]],
    "override_cooldown_minutes": 30,
}

# State variables
override_until = 0
last_set_brightness = -1
camera_bounds_initialized = False
bounds = {"gain_min": 0, "gain_max": 255, "exp_min": 1, "exp_max": 10000}


def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}. Using defaults.")

    local_config = "config.json"
    if os.path.exists(local_config):
        try:
            with open(local_config, "r") as f:
                return json.load(f)
        except:
            pass

    return DEFAULT_CONFIG


def init_camera_bounds(device):
    global camera_bounds_initialized, bounds
    try:
        res = subprocess.check_output(
            f"v4l2-ctl -d {device} --list-ctrls",
            shell=True,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        for line in res.split("\n"):
            line = line.strip()
            if "gain " in line:
                # Extract min/max. Example: gain 0x00980913 (int) : min=0 max=128 step=1 default=64 value=64 flags=has-min-max
                parts = line.split(":")
                if len(parts) > 1:
                    props = parts[1].strip().split()
                    for p in props:
                        if p.startswith("min="):
                            bounds["gain_min"] = float(p.split("=")[1])
                        if p.startswith("max="):
                            bounds["gain_max"] = float(p.split("=")[1])
            elif "exposure_time_absolute " in line:
                parts = line.split(":")
                if len(parts) > 1:
                    props = parts[1].strip().split()
                    for p in props:
                        if p.startswith("min="):
                            bounds["exp_min"] = float(p.split("=")[1])
                        if p.startswith("max="):
                            bounds["exp_max"] = float(p.split("=")[1])
        camera_bounds_initialized = True
        print(f"Camera bounds initialized: {bounds}")
    except Exception as e:
        print(f"Failed to read camera bounds: {e}. Using defaults.")


def get_v4l2_val(device, control_name):
    try:
        res = subprocess.check_output(
            f"v4l2-ctl -d {device} --get-ctrl={control_name}",
            shell=True,
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return float(res.split(":")[1].strip())
    except:
        return None


def wakeup_camera(device):
    try:
        # Grab just 1 frame to trigger AE logic for next cycle
        print("Waking up camera with v4l2-ctl...")
        subprocess.run(
            f"v4l2-ctl -d {device} --stream-mmap --stream-count=1",
            shell=True,
            stderr=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            timeout=2,
        )
        print("Camera wakeup complete.")
    except Exception as e:
        print(f"v4l2-ctl wakeup failed: {e}")


def get_kde_brightness():
    try:
        cmd = (
            f"qdbus org.kde.Solid.PowerManagement "
            f"/org/kde/Solid/PowerManagement/Actions/BrightnessControl "
            f"org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightness"
        )
        res = subprocess.check_output(
            cmd, shell=True, text=True, stderr=subprocess.DEVNULL
        )
        value = float(res.strip())
        max_b = get_kde_brightness_max()
        if max_b > 0:
            return (value / max_b) * 100.0
        return value
    except:
        return None


def get_kde_brightness_max():
    try:
        cmd = (
            f"qdbus org.kde.Solid.PowerManagement "
            f"/org/kde/Solid/PowerManagement/Actions/BrightnessControl "
            f"org.kde.Solid.PowerManagement.Actions.BrightnessControl.brightnessMax"
        )
        res = subprocess.check_output(
            cmd, shell=True, text=True, stderr=subprocess.DEVNULL
        )
        return float(res.strip())
    except:
        return 10000


def set_kde_brightness(percent):
    global last_set_brightness
    percent = max(0, min(100, int(percent)))
    max_b = get_kde_brightness_max()
    kde_value = int((percent / 100.0) * max_b)
    cmd = (
        f"qdbus org.kde.Solid.PowerManagement "
        f"/org/kde/Solid/PowerManagement/Actions/BrightnessControl "
        f"org.kde.Solid.PowerManagement.Actions.BrightnessControl.setBrightness {kde_value}"
    )
    subprocess.run(
        cmd, shell=True, stderr=subprocess.DEVNULL, stdout=subprocess.DEVNULL
    )
    last_set_brightness = percent


def check_manual_override(cooldown_minutes):
    global override_until, last_set_brightness

    current_b = get_kde_brightness()
    if current_b is None:
        return False

    # If the brightness is significantly different from what we last set (>25 units / 25%)
    # We assume the user has overriden it via keyboard shortcuts or UI
    if last_set_brightness != -1 and abs(current_b - last_set_brightness) > 25:
        print(
            f"Manual override detected! Current: {current_b}, Last Set: {last_set_brightness}"
        )
        override_until = time.time() + (cooldown_minutes * 60)
        last_set_brightness = -1  # Reset so we don't trigger repeatedly in sleep mode
        return True

    # Check if we are still in cooldown
    if time.time() < override_until:
        remaining = (override_until - time.time()) / 60
        print(f"In override cooldown mode for ~{remaining:.1f} more minutes...")
        return True

    # Always sync last_set to current to avoid false override detection
    last_set_brightness = current_b
    return False


def calculate_target_brightness(config):
    device = config.get("device", "/dev/video0")

    if not camera_bounds_initialized:
        print("Initializing bounds...")
        init_camera_bounds(device)

    # Read values first (AE has been running from previous iteration)
    print("Reading V4L2 values...")
    gain = get_v4l2_val(device, "gain")
    exposure = get_v4l2_val(device, "exposure_time_absolute")
    print(f"Got gain: {gain}, exp: {exposure}")

    # Then wake up camera for next cycle - triggers AE to run
    print("Pre-wakeup")
    wakeup_camera(device)

    # Give AE time to adjust for next reading (especially important when
    # transitioning from dark to bright - AE needs time to reduce exposure)
    time.sleep(2)

    if gain is None or exposure is None:
        return None

    # Normalize values between 0.0 and 1.0 based on camera bounds
    # Avoid division by zero
    gain_range = max(1.0, bounds["gain_max"] - bounds["gain_min"])
    exp_range = max(1.0, bounds["exp_max"] - bounds["exp_min"])

    gain_norm = max(0.0, min(1.0, (gain - bounds["gain_min"]) / gain_range))
    exp_norm = max(0.0, min(1.0, (exposure - bounds["exp_min"]) / exp_range))

    # Calculate an absolute darkness score 0.0 to 1.0
    # Higher value = darker environment
    darkness_score = (gain_norm + exp_norm) / 2.0

    print(
        f"V4L2 Read - Gain: {gain}/{bounds['gain_max']} | Exp: {exposure}/{bounds['exp_max']} | Darkness: {darkness_score:.2f}"
    )

    # Interpolate using configured curve
    curve = config.get("curve", DEFAULT_CONFIG["curve"])

    # Curve format: [[darkness_score, brightness%]...]
    # Sort just in case user misconfigured
    curve.sort(key=lambda x: x[0])

    xp = [p[0] for p in curve]  # Darkness scores
    fp = [p[1] for p in curve]  # Brightness percentages

    target_brightness = np.interp(darkness_score, xp, fp)

    return float(target_brightness)


def main():
    config = load_config()
    print("Starting Kamlux Auto Brightness Daemon [Phase 2]...")

    alpha = config.get("smoothing_alpha", 0.2)
    interval = config.get("interval", 5)

    # Initial read without setting (to establish baseline)
    calculate_target_brightness(config)
    last_set_brightness = get_kde_brightness() or 50

    while True:
        try:
            config = load_config()
            alpha = config.get("smoothing_alpha", 0.2)
            interval = config.get("interval", 5)
            cooldown = config.get("override_cooldown_minutes", 30)

            # Check if user has overridden brightness
            if check_manual_override(cooldown):
                time.sleep(interval)
                continue

            target_brightness = calculate_target_brightness(config)

            if target_brightness is not None:
                current_sys_brightness = get_kde_brightness() or 50
                # Exponential Moving Average against CURRENT system brightness for ultra smooth transitions
                new_brightness = (alpha * target_brightness) + (
                    (1 - alpha) * current_sys_brightness
                )

                # Only set if difference is meaningful to prevent dbus spam (>0.5%)
                if abs(new_brightness - current_sys_brightness) > 0.5:
                    print(
                        f"Setting brightness: {new_brightness:.1f}% (target: {target_brightness:.1f}%, current: {current_sys_brightness:.1f}%)"
                    )
                    set_kde_brightness(new_brightness)

            time.sleep(interval)
        except KeyboardInterrupt:
            print("\nExiting Kamlux...")
            sys.exit(0)
        except Exception as e:
            print(f"Daemon error: {e}")
            time.sleep(interval)


if __name__ == "__main__":
    main()
