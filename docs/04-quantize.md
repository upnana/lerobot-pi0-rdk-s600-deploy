# 04 · 量化（级联，不能乱序）

> 状态：SigLIP 本机 HBM 已出（2026-08-08）；待板上 dump → PaliGemma / Expert。

## 核心原则（自己的话）

π0 在板上是三段：

```text
图像 → SigLIP → 视觉特征
              → PaliGemma → KV
                         → Action Expert（flow matching 多步）→ 动作
```

上游量化误差会进下游；Expert 还会多步迭代。所以：

1. 先量化 SigLIP，用**板上真实 HBM 输出**去校准 PaliGemma  
2. 再跑 PaliGemma HBM，用**真实 KV** 校准 Expert  
3. 不要三段都只拿浮点中间结果各自量化完硬拼  

精度分配直觉（见 [我自己的 SigLIP 分析](../notes/siglip-quantize-analysis.md)）：

| 段 | 危险点 | 我采用的方向 |
|----|--------|--------------|
| SigLIP | position embedding 歪了 → 抓偏 | position 留 FP16；其余 dynamic / quant8 |
| PaliGemma | attention / RoPE 污染整段 KV | attention matmul `fixed16` |
| Expert | 10 步误差回灌 + 反归一化放大 | 尽量 dynamic，输出保 FP16 |

## 前置

- [ ] [03 BF16 基线](./03-bf16-baseline.md) 通过（建议补，未阻塞本机 SigLIP 编译）  
- [x] `rdk_LeRobot_tools` `s600` + SDK 1.0.2 + conda `oellm_s600`  
- [x] 统一：`export PI0_VALID_CAMERA_SLOTS=2`  
- [x] 相机键：**`front wrist`**（不是 `side`）  
- [x] prompt：`$TASK`  
- [x] 校准集 50 条：`pi0_stack3_040000_real50_v2`

## 步骤总览

```text
1. 抽 50 条真实校准样本（覆盖接近/抓取/叠放）
2. SigLIP → HBM → 板上 dump vision embedding
3. PaliGemma（用真实 SigLIP 输出）→ HBM → 板上 dump 36×KV
4. Expert（用真实 KV）→ HBM
5. 打包 prompt embedding / norm_stats / SHA256
```

具体命令模板已写在 [`../quantize/steps.md`](../quantize/steps.md)，路径按 [01 环境](./01-env.md) 的环境变量。

## 我的命令与结果

| 段 | HBM 路径 | SHA256 | 备注 |
|----|----------|--------|------|
| SigLIP | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm` | `123a9da5ac188917cde03fc504266ea3eede501a99d3168952af6817ceeb8915` | 425MB；patch quant8 / position fp16；编译 ~629s |
| PaliGemma | | | 待板上 dump SigLIP 特征后量化 |
| Expert | | | 待 PaliGemma KV dump 后量化 |

大文件不进 git；SHA256 与 `quantization_manifest.json` 留在本机产物目录。

## 本章完成标准

- [ ] 三份 HBM + prompt embedding + norm_stats 齐全  
- [ ] 三段来自同一次训练 / 同一相机 schema，并用 SHA256 绑定  
- [ ] 与 BF16 在同分布样本上做过基本对比  

## 下一章

→ [05 板上部署](./05-deploy.md)
