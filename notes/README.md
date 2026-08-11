# notes/

| 文件 | 说明 |
|------|------|
| [pitfalls.md](./pitfalls.md) | 踩坑本：现象 → 原因 → 处理 |
| [siglip-quantize-analysis.md](./siglip-quantize-analysis.md) | 我怎么理解 SigLIP 量化（叠积木视角） |
| [calibration-images.md](./calibration-images.md) | 校准图是什么 |
| [bootstrap-vs-dump.md](./bootstrap-vs-dump.md) | 为何要浮点垫脚才能 dump（死结逻辑） |
| [expert-kv-dump.md](./expert-kv-dump.md) | `expert_kv_00`…`35` 是什么、给谁用 |
| [bench/](./bench/) | 离线 smoke / BF16 vs HBM 对比数据与备忘 |

板端逐步操作（串口 / SSH / rsync / standalone）见：

- [`../docs/06-board-access.md`](../docs/06-board-access.md)
- [`../docs/07-board-prepare-siglip-dump.md`](../docs/07-board-prepare-siglip-dump.md)

教程主线在 [`../docs/`](../docs/)，这里记分析和实验碎片。
