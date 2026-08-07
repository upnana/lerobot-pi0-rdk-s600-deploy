# lerobot-pi0-rdk-s600-deploy

LeRobot **π0** → 量化 → **RDK S600** 部署学习仓库。

对照文档：
- 论坛教程：[π0 Policy 在 RDK S600 上的训练、量化全流程](https://forum.d-robotics.cc/t/topic/35528)
- 官方工具仓：[D-Robotics/rdk_LeRobot_tools](https://github.com/D-Robotics/rdk_LeRobot_tools)（`s600` 分支）

## 目录

| 目录 | 用途 |
|------|------|
| [`train/`](./train/) | 训练脚本和配置（post-training） |
| [`quantize/`](./quantize/) | 跟教程对齐的量化步骤 |
| [`deploy/`](./deploy/) | S600 真机推理 |
| [`notes/`](./notes/) | 踩坑记录与实验笔记 |

## 推荐流程

```text
1. train/     从 pi0_base 做 SO100 post-training，得到 BF16 checkpoint
2. train/     服务器 BF16 真机基线验证通过
3. quantize/  SigLIP → PaliGemma → Expert 级联量化，产出 HBM
4. deploy/    板上同步推理 + SO100 控制
```

## 说明

- 训练使用 Hugging Face LeRobot（`policy.type=pi0`），不是本仓重写训练框架。
- 量化 / 板上 runtime 以 `rdk_LeRobot_tools` 的 `models/pi0/` 为准；本仓放自己的命令、配置和笔记。
- 本仓**不跟踪**大文件：checkpoint、HBM、数据集、校准样本等（见 `.gitignore`）。
