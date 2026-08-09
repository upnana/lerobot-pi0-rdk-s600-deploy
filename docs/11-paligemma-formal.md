# 11 · 正式 PaliGemma（用板上 SigLIP dump 重编）

> 状态：**已完成**（2026-08-09）  
> 前置：板上 SigLIP dump 已拉回（[10](./10-board-siglip-dump.md)）  
> 对比：临时垫脚版见 [08](./08-paligemma-float-bootstrap.md)（`float_siglip`，**不要**再当正式部署用）

本步产出 **正式** `pi0_gemma_llm_ptq.hbm`：校准视觉输入来自板上正品 SigLIP HBM 的真实输出，不是 PC 浮点 SigLIP。

---

## 1. 这一步实际在干什么

```text
板上 dump 的 50 份 paligemma_inputs_embeds.bin
  → PC：喂给浮点 PaliGemma 做校准（带真实量化误差）
  → 定精度 → hbdk 编译
  → paligemma/pi0_gemma_llm_ptq.hbm
  → fixed_prompt_embedding.bin（板端直接吃 embedding）
```

manifest：

```text
"vision_embeddings_source": "precomputed_s600_siglip_hbm"
"vision_embeddings_dir": ".../pi0_stack3_040000_siglip_hbm_real50"
```

---

## 2. 精度与关键参数（本次采用）

| 参数 | 值 | 为什么 |
|------|-----|--------|
| `--attention-matmul-mode` | **`fixed16`** | 注意力 matmul 更稳，少污染整段 KV（PaliGemma 输出要给 Expert 用） |
| `--attention-linear-mode` | `dynamic` | attention 侧 linear 动态量化 |
| `--mlp-linear-mode` | `dynamic` | MLP 多为 dynamic |
| `--mlp-down-linear-mode` | `dynamic` | MLP down 投影同样 dynamic |
| `--prompt-embedding-input` | 打开 | **板上直接吃 prompt embedding**，不在板端 tokenize |
| `--max-hbm-bytes` | **`2140000000`** | 限制编译产物体积上限（约 2.14GB），避免 HBM 过大难上板 |
| `--fixed-prompt` | 任务句 | 与训练 / dump 一致 |
| `--march` | `nash-p` | S600 |

manifest `export_precision` 摘要：

```text
attention_matmul_mode = fixed16
attention_linear_mode = dynamic
mlp_linear_mode       = dynamic
mlp_down_linear_mode  = dynamic
attention_matmul_qk_bits / sv_bits = [16, 16]
accumulation = float32, output = float16
```

`--prompt-embedding-input` 时 HBM 输入顺序：

```text
prompt_embeddings → vision_embeddings → attention_mask
```

板端配套文件是 `fixed_prompt_embedding.bin`（`[1,48,2048]` FP16），standalone 不再跑 tokenizer。

---

## 3. 环境（PC）

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
| 脚本 | `rdk_LeRobot_tools/models/pi0/tools/quantize_paligemma_real_calib.py` |
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 校准图目录 | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2` |
| **视觉 embedding** | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50` |
| 输出 | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma` |

与 [08](./08-paligemma-float-bootstrap.md) 的关键差别：**必须传** `--vision-embeddings-dir`（指向板上 dump）。

---

## 4. 完整命令（可复现）

```bash
OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma
mkdir -p "$OUT"
cd /home/rxn/rdk_LeRobot_tools/models/pi0/tools

python -u quantize_paligemma_real_calib.py \
  --model-dir /home/rxn/models/pi0_stack_white_blue_black_040000 \
  --calibration-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2 \
  --vision-embeddings-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
  --output-dir "$OUT" \
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
  --fixed-prompt 'Stack the blocks from bottom to top: white, blue, black.' \
  --prompt-embedding-input \
  2>&1 | tee "$OUT/quantize_paligemma.log"
```

本次日志阶段：

```text
calibration 1/50 … 50/50
exporting_bc
converting_bc
compiling_hbo      # ~439s
linking_hbm
complete
END … EXIT=0 ELAPSED_SEC=532
```

---

## 5. 产物（2026-08-09）

目录：`.../sdk102/paligemma/`

| 文件 | 大小（约） | 说明 |
|------|------------|------|
| `pi0_gemma_llm_ptq.hbm` | **2.0G** | **正式** PaliGemma |
| `fixed_prompt_embedding.bin` | 192K | 板端 prompt 输入 |
| `quantization_manifest.json` | — | 含 `precomputed_s600_siglip_hbm` |
| `quantize_paligemma.log` | — | 完整日志 |

HBM SHA256：

```text
410d33ab42adfbebf7852e3d34f49c74fc5d0cb064fd8c78be227d092173122d
```

校验：

```bash
ls -lah "$OUT/pi0_gemma_llm_ptq.hbm" "$OUT/fixed_prompt_embedding.bin"
sha256sum "$OUT/pi0_gemma_llm_ptq.hbm"
python -c "import json; m=json.load(open('$OUT/quantization_manifest.json')); print(m['vision_embeddings_source']); print(m['export_precision']['attention_matmul_mode'])"
# 期望：precomputed_s600_siglip_hbm / fixed16
```

---

## 6. 和临时垫脚版的差别

| | [08] 浮点垫脚 | **本步正式版** |
|--|---------------|----------------|
| 视觉输入 | PC 浮点 SigLIP | **板上 SigLIP HBM dump** |
| `--vision-embeddings-dir` | 不传 | **必传** |
| `vision_embeddings_source` | `float_siglip` | `precomputed_s600_siglip_hbm` |
| 输出目录 | `paligemma_float_bootstrap/` | **`paligemma/`** |
| 用途 | 仅凑齐 3 段起 engine | **部署 / 后续 dump KV** |

精度策略（`fixed16` matmul + dynamic linear/MLP + prompt embedding + max-hbm）两边命令一致；差别在**校准数据来源**。

---

## 7. 下一步

1. 把本目录 HBM + `fixed_prompt_embedding.bin` 拷上板（替换临时 PaliGemma）  
2. 正品 SigLIP + **正式 PaliGemma** + 临时 Expert 起 engine  
3. dump **PaliGemma KV**（`--save-expert-kv`）  
4. 本机用 `--paligemma-kv-dir` 编**正式 Expert**
