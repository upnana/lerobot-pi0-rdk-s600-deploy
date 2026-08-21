#!/usr/bin/env python3
"""Replay one dataset episode on SO-101 and record front+wrist MP4 on S600.

IMPORTANT: This is teleop trajectory replay from the dataset, NOT π0 policy inference.
For a true policy-inference portfolio clip, record during run_live_stack3.sh --execute.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
from pathlib import Path

import cv2
import numpy as np


MOTOR_NAMES = [
    "shoulder_pan",
    "shoulder_lift",
    "elbow_flex",
    "wrist_flex",
    "wrist_roll",
    "gripper",
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--actions-npy", type=Path, required=True)
    p.add_argument("--meta-json", type=Path, required=True)
    p.add_argument("--lerobot-root", type=Path, default=Path("/root/lerobot"))
    p.add_argument(
        "--robot-port",
        type=Path,
        default=Path(
            "/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AE6083854-if00"
        ),
    )
    p.add_argument("--robot-id", default="so101_follower")
    p.add_argument(
        "--calibration-dir",
        type=Path,
        default=Path(
            "/root/rdk_LeRobot_tools/models/pi0/calibration/robots/so_follower"
        ),
    )
    p.add_argument("--front-camera", type=Path, default=Path("/dev/video0"))
    p.add_argument("--wrist-camera", type=Path, default=Path("/dev/video2"))
    p.add_argument("--width", type=int, default=640)
    p.add_argument("--height", type=int, default=480)
    p.add_argument("--fps", type=float, default=0.0, help="0 = use meta fps")
    p.add_argument("--output-dir", type=Path, required=True)
    p.add_argument(
        "--confirm",
        required=True,
        help="Must be ENABLE_SO100_MOTORS to enable torque",
    )
    p.add_argument(
        "--max-frames",
        type=int,
        default=0,
        help="0 = full episode; >0 truncates for a short take",
    )
    return p.parse_args()


def make_robot(args):
    sys.path.insert(0, str(args.lerobot_root / "src"))
    from lerobot.cameras.opencv import OpenCVCameraConfig
    from lerobot.robots.so_follower import SO100Follower, SO100FollowerConfig

    cameras = {
        "front": OpenCVCameraConfig(
            index_or_path=args.front_camera,
            width=args.width,
            height=args.height,
            fps=30,
            warmup_s=1,
            fourcc="MJPG",
        ),
        "wrist": OpenCVCameraConfig(
            index_or_path=args.wrist_camera,
            width=args.width,
            height=args.height,
            fps=30,
            warmup_s=1,
            fourcc="MJPG",
        ),
    }
    config = SO100FollowerConfig(
        port=str(args.robot_port),
        calibration_dir=args.calibration_dir,
        id=args.robot_id,
        cameras=cameras,
        use_degrees=True,
    )
    return SO100Follower(config)


def open_writer(path: Path, width: int, height: int, fps: float) -> cv2.VideoWriter:
    path.parent.mkdir(parents=True, exist_ok=True)
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")
    writer = cv2.VideoWriter(str(path), fourcc, fps, (width, height))
    if not writer.isOpened():
        raise RuntimeError(f"Failed to open VideoWriter: {path}")
    return writer


def main() -> int:
    args = parse_args()
    if args.confirm != "ENABLE_SO100_MOTORS":
        raise SystemExit("Refusing to move motors without --confirm ENABLE_SO100_MOTORS")

    meta = json.loads(args.meta_json.read_text())
    actions = np.load(args.actions_npy).astype(np.float64)
    if actions.ndim != 2 or actions.shape[1] != 6:
        raise ValueError(f"Expected actions [T,6], got {actions.shape}")
    if args.max_frames > 0:
        actions = actions[: args.max_frames]

    fps = float(args.fps or meta.get("fps") or 30.0)
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(out / "replay_record.log"),
        ],
    )
    logging.warning(
        "DATASET TELEOP REPLAY — not pi0 inference. label=%s episode=%s frames=%d",
        meta.get("label_for_portfolio"),
        meta.get("episode_index"),
        len(actions),
    )

    robot = make_robot(args)
    # Connect bus + cameras without auto-calibrate
    robot.bus.connect()
    if not robot.is_calibrated:
        raise RuntimeError("Calibration mismatch; refusing to move")
    for cam in robot.cameras.values():
        cam.connect()

    mosaic_path = out / "stack3_dataset_replay_front_wrist.mp4"
    front_path = out / "stack3_dataset_replay_front.mp4"
    wrist_path = out / "stack3_dataset_replay_wrist.mp4"
    mosaic_w = open_writer(mosaic_path, args.width * 2, args.height, fps)
    front_w = open_writer(front_path, args.width, args.height, fps)
    wrist_w = open_writer(wrist_path, args.width, args.height, fps)

    # Enable torque holding current pose
    positions = robot.bus.sync_read("Present_Position")
    hold = {name: float(positions[name]) for name in MOTOR_NAMES}
    robot.bus.sync_write("Goal_Position", hold)
    robot.bus.enable_torque(num_retry=5)
    logging.warning("Torque enabled; replaying episode")

    period = 1.0 / fps
    try:
        for idx, target in enumerate(actions):
            t0 = time.perf_counter()
            action = {
                f"{name}.pos": float(target[i]) for i, name in enumerate(MOTOR_NAMES)
            }
            robot.send_action(action)

            obs = robot.get_observation()
            front = np.asarray(obs["front"])
            wrist = np.asarray(obs["wrist"])
            # OpenCV writers expect BGR
            if front.shape[-1] == 3:
                front_bgr = cv2.cvtColor(front, cv2.COLOR_RGB2BGR)
                wrist_bgr = cv2.cvtColor(wrist, cv2.COLOR_RGB2BGR)
            else:
                front_bgr, wrist_bgr = front, wrist
            front_w.write(front_bgr)
            wrist_w.write(wrist_bgr)
            mosaic_w.write(np.concatenate([front_bgr, wrist_bgr], axis=1))

            if idx % 30 == 0:
                logging.info("frame %d/%d target=%s", idx, len(actions), np.round(target, 2).tolist())
            dt = time.perf_counter() - t0
            sleep_s = period - dt
            if sleep_s > 0:
                time.sleep(sleep_s)
    finally:
        try:
            robot.bus.disable_torque(num_retry=5)
        except Exception:
            logging.exception("Failed to disable torque")
        mosaic_w.release()
        front_w.release()
        wrist_w.release()
        for cam in robot.cameras.values():
            if cam.is_connected:
                cam.disconnect()
        if robot.bus.is_connected:
            robot.bus.disconnect(disable_torque=False)

    # Remux to H.264 if ffmpeg exists (better for sharing)
    h264 = out / "stack3_dataset_replay_front_wrist_h264.mp4"
    import shutil
    import subprocess

    if shutil.which("ffmpeg"):
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-i",
                str(mosaic_path),
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-movflags",
                "+faststart",
                str(h264),
            ],
            check=False,
        )
        logging.info("H264 mosaic: %s", h264)

    readme = out / "README_PORTFOLIO.txt"
    readme.write_text(
        "\n".join(
            [
                "Portfolio labeling guidance",
                "===========================",
                f"Episode: {meta.get('episode_index')}",
                f"Task: {meta.get('task')}",
                "This MP4 is DATASET TELEOP REPLAY on the real SO-101 + S600 cameras.",
                "Do NOT caption it as 'π0 policy inference' unless you also record",
                "a separate clip during run_live_stack3.sh execute (true HBM policy).",
                "",
                "Suggested honest caption:",
                "  'SO-101 stack white→blue→black — dataset episode replay (hardware bring-up).'",
                "Suggested π0 caption (only for execute recording):",
                "  'π0 on RDK S600 closed-loop inference — stack white→blue→black.'",
                "",
            ]
        )
    )
    logging.info("Wrote %s %s %s", mosaic_path, front_path, wrist_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
