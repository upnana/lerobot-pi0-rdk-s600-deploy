# Expert KV dump 是什么：`expert_kv_00` … `expert_kv_35`

> 配套操作：[12 正式 PaliGemma 上板 / KV dump](../docs/12-formal-paligemma-on-board.md)  
> 板上 dump 时加 `--save-expert-kv` 才会写出这些文件。

---

## 一句话

**`expert_kv_00_fp16.bin`～`expert_kv_35_fp16.bin` = 正式 PaliGemma 在板上算出的整份 KV cache，拆成 36 个文件**，供后面编正式 Expert 校准用。

`00` 是开头，`35` 是结尾——不是两种完全不同的东西。

---

## 为什么是 36 个？

PaliGemma 有 **18 层** transformer；Expert 需要每层的 **K** 和 **V**：

```text
18 层 × 2（K / V）= 36 个文件
```

| 文件 | 含义 |
|------|------|
| `expert_kv_00_fp16.bin` | 36 路里的 **第 1 个**（最浅层附近的 K/V 之一） |
| `expert_kv_01_fp16.bin` | 第 2 个 |
| … | … |
| `expert_kv_35_fp16.bin` | **最后 1 个**（最深层附近的 K/V 之一） |

编号就是 PaliGemma 输出里那 36 路 KV 的下标。engine（`pi0_standalone`）从 `paligemma.outputs[1]…[36]` 拷到 Expert 输入，并按 `expert_kv_XX_fp16.bin` 落盘。

你不需要单独「用」某一个；编正式 Expert 时脚本会把 **`00`–`35` 整套**读进 `--paligemma-kv-dir`。

---

## 每个文件长什么样？

脚本常量（`dump_siglip_hbm_calibration.py`）：

```text
shape = [1, 816, 256]   # FP16
```

| 维 | 含义（直观） |
|----|----------------|
| `1` | batch |
| `816` | 前缀长度（视觉 token + 语言容量那一段） |
| `256` | KV head 相关宽度 |

也就是：看完 front / wrist（+ empty 槽）和固定 prompt 之后，PaliGemma 留下的「记忆」，Expert 做 flow matching 多步去噪时要读这些 KV。

每条校准样本一个目录，例如：

```text
.../pi0_stack3_040000_paligemma_hbm_kv_real50/0/
  paligemma_inputs_embeds.bin      # 顺带仍会存视觉 embedding
  expert_kv_00_fp16.bin
  expert_kv_01_fp16.bin
  …
  expert_kv_35_fp16.bin
```

---

## 和 SigLIP dump 差在哪？

| | SigLIP dump（[10](../docs/10-board-siglip-dump.md)） | KV dump（加 `--save-expert-kv`） |
|--|------------------------------------------------------|----------------------------------|
| 主要产物 | `paligemma_inputs_embeds.bin` | **再加** 36× `expert_kv_XX_fp16.bin` |
| 校准谁 | 正式 PaliGemma | **正式 Expert** |
| 板上 HBM | 正品 SigLIP + 临时后两段即可 | 正品 SigLIP + **正式 PaliGemma** + 临时 Expert |

两终端结构一样：A = dump 脚本（Server），B = engine（Client）。

---

## 后面怎么用？

拉回本机后：

```bash
# 示例路径
export PALIGEMMA_HBM_KV=/home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50

python -u quantize_expert_real_calib.py \
  ... \
  --paligemma-kv-dir "$PALIGEMMA_HBM_KV"
```

脚本会按样本读取 `expert_kv_00`…`35`（见 `quantize_expert_real_calib.py` 的 `load_precomputed_kv`）。  
**不要**再用浮点垫脚 Expert（[09](../docs/09-expert-float-bootstrap.md)）那套 `float_paligemma` KV。

---

## 快速自检

```bash
# 板上或拉回后
SAMPLE=0
DIR=/root/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50/$SAMPLE
# 本机则换成 /home/rxn/gemma/calibration_data/...

ls "$DIR"/expert_kv_*.bin | wc -l          # 期望 36
ls -lah "$DIR"/expert_kv_00_fp16.bin \
        "$DIR"/expert_kv_35_fp16.bin       # 大小应相同
# 单文件约 1*816*256*2 ≈ 417792 字节
```
