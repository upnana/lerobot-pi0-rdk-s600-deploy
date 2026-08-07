# 04 · 量化（级联，不能乱序）

> 状态：待填。细节 checklist 也可写在 [`../quantize/steps.md`](../quantize/steps.md)。

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

## 步骤总览

1. 从训练数据抽覆盖完整阶段的校准样本  
2. SigLIP → 编译 HBM → 板上导出特征  
3. PaliGemma → 编译 HBM → 板上导出 KV  
4. Expert → 编译 HBM  
5. 核对 stats / prompt embedding / SHA256  

## 我的命令与结果

把每次真正跑通的命令记在 [`../quantize/steps.md`](../quantize/steps.md)。本章只保留结论：

| 段 | HBM 路径 | SHA256 | 备注 |
|----|----------|--------|------|
| SigLIP | | | |
| PaliGemma | | | |
| Expert | | | |

## 本章完成标准

- [ ] 三份 HBM + 配套文件齐全
- [ ] 与 BF16 在同分布样本上做过基本数值/行为对比（能记多少记多少）

## 下一章

→ [05 板上部署](./05-deploy.md)
