# deploy/replay/

Dataset **teleop** episode replay + dual-camera record on S600.

> Not π0 inference. For policy clips use `run_live_stack3.sh --record-video`.

## Assets

| File | Meaning |
|------|---------|
| `episode_000072_*.{npy,json}` | 2cam dataset episode 72 actions |
| `episode3cam_000059_*.{npy,json}` | 3cam dataset episode 59 actions |
| `replay_episode_record_video.py` | Replay joints + write front/wrist MP4 |
| `run_dataset_replay_record.sh` | Launcher (2cam stem) |
| `run_dataset_replay_3cam_record.sh` | Launcher (3cam stem) |
| `reference_ep59_3cam/` | Optional layout reference JPEGs |

Copy this folder to the board as `/root/rdk_LeRobot_tools/models/pi0/replay_assets/`.

See experiment log: [`docs/17-live-experiments-summary.md`](../docs/17-live-experiments-summary.md).
