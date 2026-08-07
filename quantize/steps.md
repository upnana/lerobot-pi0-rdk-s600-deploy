# 量化步骤备忘

> 路径按本机填写；命令以 `rdk_LeRobot_tools` 为准。先完成 BF16 基线再跑。

## 环境

| 项 | 值 |
|----|----|
| 训练 checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 数据集 | `/home/rxn/datasets/stack_3blocks_white_blue_black` |
| SDK / OE 版本 | LLM S600 SDK 1.0.2 |
| rdk_LeRobot_tools | `/home/rxn/rdk_LeRobot_tools` · 分支 `s600` |
| 校准样本数 | 50 |
| 有效相机槽 | 2（`front` + `wrist`） |
| 任务文本 | `Stack the blocks from bottom to top: white, blue, black.` |

```bash
export PI0_VALID_CAMERA_SLOTS=2
export RDK_TOOLS=/home/rxn/rdk_LeRobot_tools
export DATASET_ROOT=/home/rxn/datasets/stack_3blocks_white_blue_black
export DATASET_NAME=stack_3blocks_white_blue_black
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
export CALIB_DIR=/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
export QUANT_OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102
export TASK='Stack the blocks from bottom to top: white, blue, black.'
mkdir -p "$CALIB_DIR" "$QUANT_OUT"
cd "$RDK_TOOLS"
```

## Step 0 — 校准集（已完成）

- [x] 从训练数据均匀抽样本
- [x] 覆盖接近、抓取、抬起、叠放等阶段
- [x] `--tolerance-s 0.04` 规避 FrameTimestampError

```bash
python models/pi0/tools/prepare_pi0_calibration_v5_2cam.py \
  --dataset-root "$DATASET_ROOT" \
  --checkpoint "$CHECKPOINT" \
  --output-dir "$CALIB_DIR" \
  --repo-id "local/$DATASET_NAME" \
  --samples 50 \
  --camera-keys front wrist \
  --camera-slots 3 \
  --tolerance-s 0.04 \
  --task "$TASK"
```

> `--camera-slots 3` 是否保留：取决于最终 HBM 编译图是否使用「2 真相机 + 1 mask」。与训练 `empty_cameras` 不一致时先对齐再量化。

## Step 1 — SigLIP

- [ ] 量化 + 编译 HBM
- [ ] 板上跑双相机样本，导出视觉特征给 PaliGemma

```bash
python3 models/pi0/tools/quantize_siglip_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --output-dir "$QUANT_OUT/siglip" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --valid-camera-slots 2 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --max-l2m-size 0 \
  --patch-embedding-mode quant8 \
  --position-embedding-mode fp16 \
  --attention-linear-mode dynamic \
  --mlp-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --projector-linear-mode dynamic \
  --layernorm-mode standard
```

板上 dump（脚本名以官方仓为准）：

```bash
# 终端 A：收集 SigLIP HBM 输出
# 终端 B：临时 deployment 只绑新 SigLIP HBM 后启动 engine
```

结果 SHA256：

```text
（待填）
```

## Step 2 — PaliGemma

- [ ] 用 SigLIP HBM 真实输出做校准
- [ ] 量化 + 编译
- [ ] 板上导出 36 组 KV

```bash
export SIGLIP_HBM_CALIB=/home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50

python3 models/pi0/tools/quantize_paligemma_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --vision-embeddings-dir "$SIGLIP_HBM_CALIB" \
  --output-dir "$QUANT_OUT/paligemma" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --max-samples 50 \
  --num-hidden-layers 18 \
  --jobs 20 \
  --march nash-p \
  --compile-opt 2 \
  --compile-balance 2 \
  --compile-max-l2m-size 0 \
  --max-hbm-bytes 2140000000 \
  --attention-linear-mode dynamic \
  --mlp-linear-mode dynamic \
  --mlp-down-linear-mode dynamic \
  --attention-matmul-mode fixed16 \
  --fixed-prompt "$TASK" \
  --prompt-embedding-input
```

结果 SHA256：

```text
（待填）
```

## Step 3 — Action Expert

- [ ] 用真实 PaliGemma KV 校准
- [ ] 量化 + 编译

```bash
export PALIGEMMA_HBM_KV=/home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50

python3 models/pi0/tools/quantize_expert_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --paligemma-kv-dir "$PALIGEMMA_HBM_KV" \
  --output-dir "$QUANT_OUT/expert" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --transformer-linear-mode dynamic \
  --projection-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --output-linear-mode dynamic
```

结果 SHA256：

```text
（待填）
```

## 产出清单

- [ ] `siglip` HBM
- [ ] `paligemma` HBM
- [ ] `expert` HBM
- [ ] `fixed_prompt_embedding.bin`
- [ ] `norm_stats.json`（来自本次数据集）
- [ ] deployment JSON + SHA256 manifest
