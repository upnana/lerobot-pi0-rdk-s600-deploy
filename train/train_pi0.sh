#!/usr/bin/env bash
# π0 post-training 启动模板。按本机路径改下面变量后再跑。
set -euo pipefail

# ---- 必改 ----
BASE_MODEL="${BASE_MODEL:-/path/to/pi0_base}"
DATASET_ROOT="${DATASET_ROOT:-/home/rxn/datasets/stack_3blocks_white_blue_black}"
DATASET_REPO_ID="${DATASET_REPO_ID:-local/stack_3blocks_white_blue_black}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/rxn/models/pi0_stack_white_blue_black_040000}"
JOB_NAME="${JOB_NAME:-pi0_stack3_white_blue_black}"

# ---- 可选 ----
DEVICE="${DEVICE:-cuda}"
STEPS="${STEPS:-40000}"
BATCH_SIZE="${BATCH_SIZE:-1}"

echo "BASE_MODEL=${BASE_MODEL}"
echo "DATASET_ROOT=${DATASET_ROOT}"
echo "DATASET_REPO_ID=${DATASET_REPO_ID}"
echo "OUTPUT_DIR=${OUTPUT_DIR}"
echo "STEPS=${STEPS}"

# 具体参数以论坛教程 / rdk_LeRobot_tools 脚本为准。
# 跑通后把最终完整命令贴回 docs/02-train.md。
lerobot-train \
  --dataset.repo_id="${DATASET_REPO_ID}" \
  --dataset.root="${DATASET_ROOT}" \
  --policy.type=pi0 \
  --policy.pretrained_path="${BASE_MODEL}" \
  --output_dir="${OUTPUT_DIR}" \
  --job_name="${JOB_NAME}" \
  --policy.device="${DEVICE}" \
  --batch_size="${BATCH_SIZE}" \
  --steps="${STEPS}"
