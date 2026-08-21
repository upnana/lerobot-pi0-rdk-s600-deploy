#!/usr/bin/env bash
# Dataset episode replay + dual-camera record on S600.
# Output is TELEOP REPLAY video (not π0 inference). See README_PORTFOLIO.txt after run.
set -euo pipefail

PI0="${RDK_TOOLS_PI0:-/root/rdk_LeRobot_tools/models/pi0}"
ASSETS="${REPLAY_ASSETS:-$PI0/replay_assets}"
OUT="$PI0/diagnostics/dataset_replay_record_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

export PYTHONPATH="/root/lerobot/src${PYTHONPATH:+:$PYTHONPATH}"

EP="${EPISODE:-000072}"
ACTIONS="$ASSETS/episode_${EP}_actions.npy"
META="$ASSETS/episode_${EP}_meta.json"

if [[ ! -f "$ACTIONS" || ! -f "$META" ]]; then
  echo "Missing $ACTIONS or $META"
  exit 1
fi

echo "TELEOP REPLAY + RECORD (not pi0 inference)"
echo "actions=$ACTIONS out=$OUT"

exec python3 -u "$ASSETS/replay_episode_record_video.py" \
  --actions-npy "$ACTIONS" \
  --meta-json "$META" \
  --output-dir "$OUT" \
  --front-camera "${FRONT_CAM:-/dev/video0}" \
  --wrist-camera "${WRIST_CAM:-/dev/video2}" \
  --confirm ENABLE_SO100_MOTORS \
  "$@"
