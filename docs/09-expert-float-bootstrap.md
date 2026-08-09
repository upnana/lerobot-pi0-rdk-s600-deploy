# 09 · 浮点垫脚编译临时 Expert（已完成）

> 状态：**已完成**（2026-08-09）  
> 目的：凑齐 engine 启动所需的第三段 HBM（临时 Expert），以便板上 dump **正品 SigLIP** 的真实输出。  
> 概念：[浮点垫脚 vs dump](../notes/bootstrap-vs-dump.md) · 上一步 PaliGemma：[08](./08-paligemma-float-bootstrap.md)

**这不是最终部署用的 Expert。** 正式版要用板上 dump 的 **PaliGemma HBM KV**（`--paligemma-kv-dir`）再编。

三段现状：

| 段 | 当前产物 | 临时？ |
|----|----------|--------|
| SigLIP | `.../siglip/pi0_siglip_ptq.hbm` | **否**（正品） |
| PaliGemma | `.../paligemma_float_bootstrap/` | **是** |
| Expert | `.../expert_float_bootstrap/`（本步） | **是** |

---

## 1. 这一步实际在干什么

```text
校准图 50 张
  → 电脑 GPU：浮点 SigLIP → 浮点 PaliGemma → 得到 KV
  → 用这些浮点 KV + state/action 噪声等校准【浮点 Expert】
  → 定精度 → hbdk 编译
  → pi0_gemma_expert_ptq.hbm
```

manifest 写明：

```text
"paligemma_kv_source": "float_paligemma"
"paligemma_kv_dir": null
```

即：**没有**用板上 PaliGemma HBM dump 的 KV。

---

## 2. 环境

```bash
conda activate oellm_s600
export PI0_VALID_CAMERA_SLOTS=2
export PI0_TOKENIZER_DIR=/home/rxn/models/paligemma-3b-pt-224
export PYTHONUNBUFFERED=1

# transformers 保持 4.57.6（与 PaliGemma 步相同）
```

| 项 | 路径 / 值 |
|----|-----------|
| 脚本 | `rdk_LeRobot_tools/models/pi0/tools/quantize_expert_real_calib.py` |
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 校准集 | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2` |
| tokenizer | `PI0_TOKENIZER_DIR` → `paligemma-3b-pt-224` |
| 输出 | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert_float_bootstrap` |
| GPU | `cuda:0` |

### 脚本小改（与 PaliGemma 一致）

LeRobot ckpt 目录没有 HF tokenizer。本机在 expert 脚本里同样改为：

```python
tokenizer_dir = Path(
    os.environ.get("PI0_TOKENIZER_DIR", str(model_dir))
).resolve()
tokenizer = AutoTokenizer.from_pretrained(tokenizer_dir, local_files_only=True)
```

---

## 3. 完整命令（可复现）

**不要**传 `--paligemma-kv-dir`（那是正式版）。

```bash
OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert_float_bootstrap
mkdir -p "$OUT"
cd /home/rxn/rdk_LeRobot_tools/models/pi0/tools

python -u quantize_expert_real_calib.py \
  --model-dir /home/rxn/models/pi0_stack_white_blue_black_040000 \
  --calibration-dir /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2 \
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

本次实跑阶段：

```text
calibration 1/50 … 50/50
convert_mlir
compile_hbo          # 本次约 360s
link_models
Quantization manifest: .../quantization_manifest.json
```

---

## 4. 产物（2026-08-09）

目录：`.../expert_float_bootstrap/`

| 文件 | 大小（约） | 说明 |
|------|------------|------|
| `pi0_gemma_expert_ptq.hbm` | **329MB** | 临时 Expert，可上板 |
| `quantization_manifest.json` | — | 来源 `float_paligemma` |
| `quantize_expert.log` | — | 完整日志 |
| `.bc` / `.convert.bc` / `.hbo` | ~300MB+ | 中间产物 |

HBM SHA256：

```text
125d00fb98a2bb4ef916d1858bbed19e50e029775fe72a19cebbe68b9bae4b32
```

精度摘要（manifest / 命令）：

- `transformer_linear_mode=dynamic`
- `projection_linear_mode=dynamic`
- `attention_matmul_mode=dynamic`
- `output_linear_mode=dynamic`
- `march=nash-p`，50 samples

校验：

```bash
ls -lah "$OUT/pi0_gemma_expert_ptq.hbm"
sha256sum "$OUT/pi0_gemma_expert_ptq.hbm"
python -c "import json; print(json.load(open('$OUT/quantization_manifest.json'))['paligemma_kv_source'])"
# 期望：float_paligemma
```

---

## 5. 和「正式 Expert」的差别

| | 本步（bootstrap） | 正式版 |
|--|-------------------|--------|
| KV 来源 | 电脑浮点 PaliGemma | 板上 PaliGemma **HBM** dump 的 36× KV |
| `--paligemma-kv-dir` | **不传** | 指向 dump 目录 |
| 输出目录建议 | `expert_float_bootstrap` | `expert`（或带日期） |
| 用途 | 凑齐 3 段起 engine、先 dump SigLIP | 最终部署 |

---

## 6. 下一步（板端 dump）

三份已齐，可以：

1. 把 **正品 SigLIP** + **临时 PaliGemma**（含 `fixed_prompt_embedding.bin`）+ **临时 Expert** + `norm_stats` 拷到 S600  
2. 写 stage deployment JSON，起 `pi0_standalone`  
3. `dump_siglip_hbm_calibration.py` 收真实 SigLIP embedding  
4. 拉回本机 → 重编正式 PaliGemma → 再 dump KV → 重编正式 Expert  

板端路径与 rsync 见 [07](./07-board-prepare-siglip-dump.md)；PaliGemma 垫脚见 [08](./08-paligemma-float-bootstrap.md)。
