# 08 · 浮点垫脚编译临时 PaliGemma（已完成）

> 状态：**已完成**（2026-08-08）  
> 目的：打破「dump 要 3 段 HBM / 正式 PaliGemma 要 dump」的死结，先编出能上板启动 engine 的**临时** PaliGemma。  
> 概念背景：[浮点垫脚 vs dump](../notes/bootstrap-vs-dump.md)

**这不是最终部署用的 PaliGemma。** 板上 dump 真实 SigLIP 输出后，还要用 `--vision-embeddings-dir` **重编一版**。

---

## 1. 这一步实际在干什么

```text
校准图 50 张
  → 电脑 GPU 上跑【浮点 SigLIP】得到视觉特征
  → 特征 + fixed prompt →【浮点 PaliGemma】前向，收集各层激活范围
  → 定 scale / 精度策略 → hbdk 编译
  → pi0_gemma_llm_ptq.hbm + fixed_prompt_embedding.bin
```

`quantization_manifest.json` 里写明：

```text
"vision_embeddings_source": "float_siglip"
"vision_embeddings_dir": null
```

即：**没有**用板上 SigLIP HBM dump，用的是浮点 SigLIP。

---

## 2. 环境

```bash
conda activate oellm_s600
export PI0_VALID_CAMERA_SLOTS=2
export PI0_TOKENIZER_DIR=/home/rxn/models/paligemma-3b-pt-224
export PYTHONUNBUFFERED=1
export D_ROBOTICS_LLM_SDK_ROOT=/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime

# 本机曾把 transformers 钉在 4.57.6（5.x 与 leap_llm 不兼容）
# pip show transformers  → 4.57.6
```

| 项 | 路径 / 值 |
|----|-----------|
| conda | `oellm_s600`（Python 3.10） |
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 校准集 | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2` |
| tokenizer | `/home/rxn/models/paligemma-3b-pt-224`（经 `PI0_TOKENIZER_DIR`） |
| 输出目录 | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma_float_bootstrap` |
| GPU | `cuda:0`（RTX 3090） |

---

## 3. 脚本小改动（本机 `rdk_LeRobot_tools`）

LeRobot 的 `config.json` **没有** HF `model_type`，也没有 tokenizer 文件。  
在 `models/pi0/tools/quantize_paligemma_real_calib.py` 里改为可读环境变量：

```python
tokenizer_dir = Path(
    os.environ.get("PI0_TOKENIZER_DIR", str(model_dir))
).resolve()
tokenizer = AutoTokenizer.from_pretrained(tokenizer_dir, local_files_only=True)
```

跑之前必须：

```bash
export PI0_TOKENIZER_DIR=/home/rxn/models/paligemma-3b-pt-224
```

---

## 4. 完整命令（可复现）

```bash
OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma_float_bootstrap
mkdir -p "$OUT"
cd /home/rxn/rdk_LeRobot_tools/models/pi0/tools

# 注意：不要传 --vision-embeddings-dir（留给正式版）
python -u quantize_paligemma_real_calib.py \
  --model-dir /home/rxn/models/pi0_stack_white_blue_black_040000 \
  --calibration-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2 \
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

日志阶段顺序（本次实跑）：

```text
loading_calibration
loading_models
calibrating          # 1/50 … 50/50，约数秒～十几秒级
exporting_bc
converting_bc
compiling_hbo        # 最久，本次约 471s
linking_hbm
complete
```

---

## 5. 产物（2026-08-08）

目录：`.../paligemma_float_bootstrap/`

| 文件 | 大小（约） | 说明 |
|------|------------|------|
| `pi0_gemma_llm_ptq.hbm` | **2.0G** | 临时 PaliGemma，可上板 |
| `fixed_prompt_embedding.bin` | 192K | `[1,48,2048]` FP16，standalone 需要 |
| `fixed_prompt_tokens.bin` / `fixed_prompt.json` | 小 | prompt 元数据 |
| `quantization_manifest.json` | — | 精度与路径记录 |
| `quantize_paligemma.log` | — | 完整日志 |
| `.bc` / `.convert.bc` / `.hbo` | 各 ~2G | 编译中间产物 |

HBM SHA256：

```text
af9bd2ea05dac2964a962a1c276d5fc70bb57d0ac8225be14cc4a87e12bd4599
```

精度摘要（manifest）：

- `attention_linear_mode=dynamic`
- `mlp_linear_mode=dynamic` / `mlp_down_linear_mode=dynamic`
- `attention_matmul_mode=fixed16`
- `march=nash-p`，`valid_camera_slots=2`，prompt 如上

校验：

```bash
ls -lah "$OUT/pi0_gemma_llm_ptq.hbm" "$OUT/fixed_prompt_embedding.bin"
sha256sum "$OUT/pi0_gemma_llm_ptq.hbm"
python -c "import json; print(json.load(open('$OUT/run_state.json'))['stage'])"
# 期望：complete
```

---

## 6. 踩坑（本次）

### 6.1 `transformers` 5.x 与 leap_llm 不兼容

- **现象：** `GemmaConfig` 无 `rope_theta`（5.14.1）
- **处理：** `pip install 'transformers==4.57.6'`（与 SDK `requirements.txt` 的 `>=4.57.6` 下限一致，且保留 `rope_theta`）

### 6.2 LeRobot ckpt 不能直接当 HF tokenizer 目录

- **现象：** `Unrecognized model ... Should have a model_type key`
- **处理：** `PI0_TOKENIZER_DIR` 指向本机已有的 `paligemma-3b-pt-224`

### 6.3 沙箱里 CUDA 可能假失败

- **现象：** 某些受限 shell 里 `torch.cuda.is_available()==False`
- **处理：** 在正常终端 / 非沙箱跑量化（`nvidia-smi` 能看到 3090）

### 6.4 输出目录已有 `.hbm` 会拒绝覆盖

- 脚本：`FileExistsError: Refusing to overwrite existing model`
- 换目录或先移走旧 `pi0_gemma_llm_ptq.hbm`

---

## 7. 和「正式 PaliGemma」的差别

| | 本步（bootstrap） | 正式版（dump 之后） |
|--|------------------|---------------------|
| 视觉特征 | 浮点 SigLIP | 板上 SigLIP **HBM** dump |
| `--vision-embeddings-dir` | **不传** | 指向 dump 目录 |
| 输出目录建议 | `paligemma_float_bootstrap` | `paligemma`（或带日期后缀） |
| 用途 | 凑齐 3 段、启动 engine、先 dump | 最终部署精度 |

---

## 8. 下一步

1. ~~同样垫脚编 **临时 Expert**~~ → 已完成，见 [09](./09-expert-float-bootstrap.md)  
2. 把 SigLIP + 本步 PaliGemma + Expert + `fixed_prompt_embedding.bin` + `norm_stats` 拷上板  
3. 起 engine → dump 真实 SigLIP → 再跑正式 `quantize_paligemma_real_calib.py`（带 `--vision-embeddings-dir`）

板端路径备忘见 [07-board-prepare-siglip-dump.md](./07-board-prepare-siglip-dump.md)。
