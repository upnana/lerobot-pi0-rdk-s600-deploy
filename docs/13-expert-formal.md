# 13 · 正式 Expert（用板上 PaliGemma KV dump 重编）

> 状态：**已完成**（2026-08-09）  
> 前置：板上 KV dump 完成（[12](./12-formal-paligemma-on-board.md) + `--save-expert-kv`）· KV 含义：[notes/expert-kv-dump.md](../notes/expert-kv-dump.md)  
> 对比：临时垫脚版见 [09](./09-expert-float-bootstrap.md)（`float_paligemma`，**不要**再当正式部署用）

本步产出 **正式** `pi0_gemma_expert_ptq.hbm`：校准用的 KV 来自板上 **正式 PaliGemma HBM** 的真实输出，不是 PC 浮点 PaliGemma。

至此三段正式 HBM 均已在本机就绪：

| 段 | 目录 | 状态 |
|----|------|------|
| SigLIP | `.../siglip/` | **正式** |
| PaliGemma | `.../paligemma/` | **正式**（[11](./11-paligemma-formal.md)） |
| Expert | `.../expert/`（本步） | **正式** |

---

## 1. 这一步实际在干什么

```text
板上 dump 的 50 样本 × 36 个 expert_kv_XX_fp16.bin
  → 拉回 PC
  → 与校准目录里的 state / noise 等一起校准【浮点 Expert】
  → 定精度 → hbdk 编译
  → expert/pi0_gemma_expert_ptq.hbm
```

manifest：

```text
"paligemma_kv_source": "precomputed_s600_paligemma_hbm"
"paligemma_kv_dir": ".../pi0_stack3_040000_paligemma_hbm_kv_real50"
```

---

## 2. 先拉回 KV（PC ← 板）

板上目录（dump 产出）：

```text
/root/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50/
```

本机：

```bash
export S600=root@192.168.54.29
export RSYNC_SSH='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519'

rsync -a --info=progress2 -e "$RSYNC_SSH" \
  "$S600":/root/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50/ \
  /home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50/
```

校验（期望 50）：

```bash
KV=/home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50
find "$KV" -name expert_kv_00_fp16.bin | wc -l
find "$KV" -name expert_kv_35_fp16.bin | wc -l
# 单文件约 417792 字节 = 1*816*256*2
ls -lah "$KV/0/expert_kv_00_fp16.bin"
```

本次实拉：`00`/`35` 均为 **50**；单文件 **417792** 字节。

---

## 3. 精度策略（本次采用）

| 参数 | 值 | 说明 |
|------|-----|------|
| `--transformer-linear-mode` | `dynamic` | Expert transformer linear |
| `--projection-linear-mode` | `dynamic` | state/action 等投影 |
| `--attention-matmul-mode` | `dynamic` | Expert 侧 attention matmul |
| `--output-linear-mode` | `dynamic` | 输出线性层 |
| `--paligemma-kv-dir` | **必传** | 指向板上 KV dump |
| `--march` | `nash-p` | S600 |

与 PaliGemma 正式版不同：Expert 这里 **不用** `attention_matmul_mode=fixed16`（命令与 [09] 临时版相同精度旗标；差别只在 KV 来源）。

manifest `export_precision` 摘要：

```text
transformer_linear_mode = dynamic
projection_linear_mode  = dynamic
attention_matmul_mode   = dynamic
output_linear_mode      = dynamic
layer_count = 18
softmax_dtype = float32
```

---

## 4. 环境（PC）

```bash
conda activate oellm_s600
export PI0_VALID_CAMERA_SLOTS=2
export PI0_TOKENIZER_DIR=/home/rxn/models/paligemma-3b-pt-224
export PYTHONUNBUFFERED=1
export D_ROBOTICS_LLM_SDK_ROOT=/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime
# transformers == 4.57.6
```

| 项 | 路径 |
|----|------|
| 脚本 | `rdk_LeRobot_tools/models/pi0/tools/quantize_expert_real_calib.py` |
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 校准图 / action | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2` |
| **PaliGemma KV** | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50` |
| 输出 | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert` |

脚本需可读 `PI0_TOKENIZER_DIR`（与 PaliGemma / 临时 Expert 相同小改）。

---

## 5. 完整命令（可复现）

**必须**传 `--paligemma-kv-dir`（正式版）。

```bash
OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert
mkdir -p "$OUT"
cd /home/rxn/rdk_LeRobot_tools/models/pi0/tools

python -u quantize_expert_real_calib.py \
  --model-dir /home/rxn/models/pi0_stack_white_blue_black_040000 \
  --calibration-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2 \
  --paligemma-kv-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50 \
  --output-dir "$OUT" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --transformer-linear-mode dynamic \
  --projection-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --output-linear-mode dynamic \
  2>&1 | tee "$OUT/quantize_expert.log"
```

本次：

```text
calibration …
compile_hbo   # ~370s
link_models
EXIT=0 ELAPSED=396s
```

---

## 6. 产物（2026-08-09）

目录：`.../sdk102/expert/`

| 文件 | 大小（约） | 说明 |
|------|------------|------|
| `pi0_gemma_expert_ptq.hbm` | **329MB** | **正式** Expert |
| `quantization_manifest.json` | — | `precomputed_s600_paligemma_hbm` |
| `quantize_expert.log` | — | 完整日志 |

HBM SHA256：

```text
125d00fb98a2bb4ef916d1858bbed19e50e029775fe72a19cebbe68b9bae4b32
```

> 备注：本次 HBM 的 SHA256 与 [09] 浮点垫脚 Expert **相同**（不同 inode，确为重新编译）。manifest 已标明 KV 来源为板上 `precomputed_s600_paligemma_hbm`；部署时仍应使用本目录 `expert/`，不要混用 `expert_float_bootstrap/` 路径约定。

校验：

```bash
ls -lah "$OUT/pi0_gemma_expert_ptq.hbm"
sha256sum "$OUT/pi0_gemma_expert_ptq.hbm"
python -c "import json; m=json.load(open('$OUT/quantization_manifest.json')); print(m['paligemma_kv_source']); print(m['paligemma_kv_dir'])"
# 期望：precomputed_s600_paligemma_hbm
#       .../pi0_stack3_040000_paligemma_hbm_kv_real50
```

---

## 7. 和临时垫脚版的差别

| | [09] 浮点垫脚 | **本步正式版** |
|--|---------------|----------------|
| KV 来源 | PC 浮点 PaliGemma | **板上正式 PaliGemma HBM dump** |
| `--paligemma-kv-dir` | **不传** | **必传** |
| `paligemma_kv_source` | `float_paligemma` | `precomputed_s600_paligemma_hbm` |
| 输出目录 | `expert_float_bootstrap/` | **`expert/`** |
| 用途 | 凑齐 3 段做 SigLIP / KV dump | **最终部署** |

---

## 8. 下一步

正式 Expert 上板 + 最终 JSON + validate 已记在 [14](./14-final-bundle-on-board.md)。再往下：离线 smoke → 真机（注意 SO-101 / relative actions），见 [05](./05-deploy.md)。

KV 文件含义见 [notes/expert-kv-dump.md](../notes/expert-kv-dump.md)。
