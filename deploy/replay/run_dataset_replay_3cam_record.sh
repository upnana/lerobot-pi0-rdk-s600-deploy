#!/usr/bin/env bash
# Replay 3cam dataset episode + record front/wrist on S600.
# TELEOP REPLAY — not π0 inference. Match block layout to reference frames first.
set -euo pipefail

PI0="${RDK_TOOLS_PI0:-/root/rdk_LeRobot_tools/models/pi0}"
ASSETS="${REPLAY_ASSETS:-$PI0/replay_assets}"
OUT="$PI0/diagnostics/dataset_replay_3cam_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

export PYTHONPATH="/root/lerobot/src${PYTHONPATH:+:$PYTHONPATH}"

# Default: 3cam episode 59
STEM="${REPLAY_STEM:-episode3cam_000059}"
ACTIONS="$ASSETS/${STEM}_actions.npy"
META="$ASSETS/${STEM}_meta.json"

if [[ ! -f "$ACTIONS" || ! -f "$META" ]]; then
  echo "Missing $ACTIONS or $META"
  exit 1
fi

echo "3CAM DATASET TELEOP REPLAY + RECORD"
echo "stem=$STEM actions=$ACTIONS out=$OUT"
echo "Place blocks like the 3cam episode reference before continuing."

exec python3 -u "$ASSETS/replay_episode_record_video.py" \
  --actions-npy "$ACTIONS" \
  --meta-json "$META" \
  --output-dir "$OUT" \
  --front-camera "${FRONT_CAM:-/dev/video0}" \
  --wrist-camera "${WRIST_CAM:-/dev/video2}" \
  --confirm ENABLE_SO100_MOTORS \
  "$@"
