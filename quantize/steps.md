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

## Step 1 — SigLIP（本机编译已完成 · 2026-08-08）

- [x] 量化 + 编译 HBM（`oellm_s600`，~11 min）
- [ ] 板上跑双相机样本，导出视觉特征给 PaliGemma

实际从 `models/pi0/tools` 目录跑（需能 import `pi0_sdk_precision_patch`）：

```bash
conda activate oellm_s600
cd "$RDK_TOOLS/models/pi0/tools"
python -u quantize_siglip_real_calib.py \
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

产物：

```text
$QUANT_OUT/siglip/pi0_siglip_ptq.hbm              # 425MB
$QUANT_OUT/siglip/quantization_manifest.json
$QUANT_OUT/siglip/calibration_forward.json
$QUANT_OUT/siglip/quantize_siglip.log
```

结果 SHA256（`pi0_siglip_ptq.hbm`）：

```text
123a9da5ac188917cde03fc504266ea3eede501a99d3168952af6817ceeb8915
```

精度确认：`patch=quant8`，`position=fp16`，相机键 `front`+`wrist`，`valid_camera_slots=2`。

板上接入与文件准备（已完成）：

- [x] 串口 + SSH → [`docs/06-board-access.md`](../docs/06-board-access.md)（`root@192.168.54.29`）
- [x] rsync HBM/校准/工具 + 编 standalone → [`docs/07-board-prepare-siglip-dump.md`](../docs/07-board-prepare-siglip-dump.md)
- [x] 浮点垫脚临时 PaliGemma → [`docs/08-paligemma-float-bootstrap.md`](../docs/08-paligemma-float-bootstrap.md)
- [x] 浮点垫脚临时 Expert → [`docs/09-expert-float-bootstrap.md`](../docs/09-expert-float-bootstrap.md)
- [ ] 三份上板后才能真正 dump

板上 dump（仍待做；命令见 `COMMANDS.md` §3.2）：

```bash
# 终端 A：收集 SigLIP HBM 输出
# 终端 B：完整 deployment JSON 后启动 engine（不能只有 SigLIP）
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
