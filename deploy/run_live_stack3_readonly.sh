#!/usr/bin/env bash
# Stack3 真机：只读（不发力矩）。在 S600 上运行。
# 先填好下方 ROBOT_PORT / CAMERA / CALIB，并算好 calibration 的 sha256。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 若脚本已拷到板上 tools 仓，改成：
# ROOT=/root/rdk_LeRobot_tools/models/pi0
PI0="${RDK_TOOLS_PI0:-/root/rdk_LeRobot_tools/models/pi0}"
cd "$PI0"

export LD_LIBRARY_PATH="/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:${LD_LIBRARY_PATH:-}"
export HB_DNN_USER_DEFINED_L2M_SIZES="${HB_DNN_USER_DEFINED_L2M_SIZES:-6:6:6:6}"

# ===== 按板子实机修改 =====
ROBOT_PORT="${ROBOT_PORT:-/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AE6083854-if00}"
ROBOT_ID="${ROBOT_ID:-so101_follower}"
CALIB_DIR="${CALIB_DIR:-$PI0/calibration/robots/so_follower}"
CALIB_FILE="${CALIB_FILE:-$CALIB_DIR/${ROBOT_ID}.json}"
# UGREEN → often video0; USB2.0_CAM1 → video2 (override if swapped)
FRONT_CAM="${FRONT_CAM:-/dev/video0}"
WRIST_CAM="${WRIST_CAM:-/dev/video2}"
LEROBOT_ROOT="${LEROBOT_ROOT:-/root/lerobot}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
export PYTHONPATH="${LEROBOT_ROOT}/src${PYTHONPATH:+:$PYTHONPATH}"
# ==========================

NORM_STATS="/root/pi0_models/versions/pi0_stack3_040000_sdk102/norm_stats.json"
CONFIG="configs/deployments/pi0_stack3_final.json"
RUN_DIR="$PI0/diagnostics/live_stack3_readonly_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RUN_DIR"

if [[ ! -f "$CALIB_FILE" ]]; then
  echo "缺少标定文件: $CALIB_FILE"
  echo "把 SO-101 follower 标定 JSON 放到该路径，或 export CALIB_FILE=..."
  exit 1
fi

STATS_SHA=$(sha256sum "$NORM_STATS" | awk '{print $1}')
CALIB_SHA=$(sha256sum "$CALIB_FILE" | awk '{print $1}')
SIGLIP_SHA=123a9da5ac188917cde03fc504266ea3eede501a99d3168952af6817ceeb8915
PALI_SHA=410d33ab42adfbebf7852e3d34f49c74fc5d0cb064fd8c78be227d092173122d
EXPERT_SHA=125d00fb98a2bb4ef916d1858bbed19e50e029775fe72a19cebbe68b9bae4b32
PROMPT_SHA=e4e974e2aca9b6f36f91ffb3021514406f7ea25c9fd0e6b57a503dfebf87b963

echo "READONLY live: no --execute (torque stays off)"
echo "Using --relative-actions: absolute = relative + state (gripper excluded)"
echo "ROBOT_PORT=$ROBOT_PORT FRONT=$FRONT_CAM WRIST=$WRIST_CAM"
echo "CALIB_FILE=$CALIB_FILE sha=$CALIB_SHA"

exec "$PYTHON_BIN" -u pi0_full_pipeline.py \
  --config "$CONFIG" \
  --norm-stats "$NORM_STATS" \
  --expected-stats-sha256 "$STATS_SHA" \
  --expected-calibration-sha256 "$CALIB_SHA" \
  --expected-siglip-sha256 "$SIGLIP_SHA" \
  --expected-paligemma-sha256 "$PALI_SHA" \
  --expected-expert-sha256 "$EXPERT_SHA" \
  --expected-prompt-embedding-sha256 "$PROMPT_SHA" \
  --lerobot-root "$LEROBOT_ROOT" \
  --robot-port "$ROBOT_PORT" \
  --robot-id "$ROBOT_ID" \
  --calibration-dir "$CALIB_DIR" \
  --calibration-file "$CALIB_FILE" \
  --camera "$FRONT_CAM" \
  --camera-name front \
  --side-camera "$WRIST_CAM" \
  --side-camera-name wrist \
  --task 'Stack the blocks from bottom to top: white, blue, black.' \
  --max-chunks 3 \
  --prefetch-steps 0 \
  --no-fixed-noise \
  --save-artifact-every-chunks 0 \
  --output-dir "$RUN_DIR/output" \
  --relative-actions \
  --relative-exclude-joints gripper \
  "$@"
