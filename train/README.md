# train/

π0 post-training：从 LeRobot 兼容的 `pi0_base` 出发，用自己的 SO100（双相机）数据全参数微调。

## 目标产物

```text
outputs/train/<run_name>/checkpoints/<step>/pretrained_model/
```

量化前必须先在服务器上用这份 **BF16** checkpoint 做真机/闭环验证。

## 建议步骤

1. 准备 `BASE_MODEL=/path/to/pi0_base`
2. 同步数据集到训练机
3. 按 `train_pi0.sh` 启动训练（按本机路径改环境变量）
4. 看 loss + checkpoint 推理视频，不要只看 loss
5. BF16 基线通过后，再进入 `../quantize/`

## 参考

- 论坛教程第三章「数据采集与全参数 Post-training」
- 官方工具仓：`rdk_LeRobot_tools` → `models/pi0/`
