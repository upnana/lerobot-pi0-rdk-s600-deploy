#!/usr/bin/env bash
# π0 post-training 启动模板。按本机路径改下面变量后再跑。
set -euo pipefail

# ---- 必改 ----
BASE_MODEL="${BASE_MODEL:-/path/to/pi0_base}"
DATASET_REPO_ID="${DATASET_REPO_ID:-local/your_so100_dataset}"
OUTPUT_DIR="${OUTPUT_DIR:-outputs/train/pi0_so100}"
JOB_NAME="${JOB_NAME:-pi0_so100_posttrain}"

# ---- 可选 ----
DEVICE="${DEVICE:-cuda}"
STEPS="${STEPS:-15000}"

echo "BASE_MODEL=${BASE_MODEL}"
echo "DATASET_REPO_ID=${DATASET_REPO_ID}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"

# 具体参数以论坛教程 / rdk_LeRobot_tools 脚本为准，这里先留 CLI 骨架：
lerobot-train \
  --dataset.repo_id="${DATASET_REPO_ID}" \
  --policy.type=pi0 \
  --policy.pretrained_path="${BASE_MODEL}" \
  --output_dir="${OUTPUT_DIR}" \
  --job_name="${JOB_NAME}" \
  --policy.device="${DEVICE}" \
  --steps="${STEPS}"
