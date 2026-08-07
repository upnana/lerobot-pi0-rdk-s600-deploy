# train/

π0 post-training：从 LeRobot 兼容的 `pi0_base` 出发，用自己的 SO-101（`front`+`wrist`）数据全参数微调。

## 本次任务

- 数据：`/home/rxn/datasets/stack_3blocks_white_blue_black`
- 指令：`Stack the blocks from bottom to top: white, blue, black.`
- 目标目录：`/home/rxn/models/pi0_stack_white_blue_black_040000`

## 目标产物

```text
<checkpoint>/
  config.json
  model.safetensors    # 完整权重
  norm_stats.json      # 从数据集 stats 导出，部署用
```

量化前必须先在服务器上用这份 **BF16** checkpoint 做真机/闭环验证。

## 建议步骤

1. 准备 `BASE_MODEL=/path/to/pi0_base`
2. 确认数据集 `meta/`、`data/`、`videos/` 齐全
3. 按 `train_pi0.sh` 启动（改环境变量）
4. 看 loss + checkpoint 推理视频，不要只看 loss
5. 检查 `model.safetensors` 完整落盘
6. BF16 基线通过后，再进入 `../quantize/`

## 参考

- 正文：[docs/02-train.md](../docs/02-train.md)
- 论坛教程第三章「数据采集与全参数 Post-training」
- 官方工具仓：`rdk_LeRobot_tools` → `models/pi0/`
