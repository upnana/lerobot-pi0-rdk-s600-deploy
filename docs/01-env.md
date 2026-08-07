# 01 · 环境准备

> 状态：训练机 SDK / 量化环境已就绪（2026-08-08）。

## 训练机

| 项 | 我的配置 |
|----|----------|
| 用户 / 主机 | `rxn` |
| GPU | RTX 3090 ×2 |
| Python（训练） | conda `lerobot_alohamini`（LeRobot 0.5.2） |
| Python（量化） | conda **`oellm_s600`**（Python 3.10） |
| LeRobot 路径 | `/home/rxn/lerobot_alohamini` |
| 本教程仓 | `/home/rxn/lerobot-pi0-rdk-s600-deploy` |
| 数据集 | `/home/rxn/datasets/stack_3blocks_white_blue_black` |
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| LLM SDK | `/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK`（1.0.2） |

## 板端（RDK S600）

| 项 | 我的配置 |
|----|----------|
| 板端系统 / 镜像 | （待填） |
| OE / LLM SDK 版本 | **D-Robotics LLM S600 SDK 1.0.2** |
| BPU march | `nash-p` |
| `rdk_LeRobot_tools` | `/home/rxn/rdk_LeRobot_tools` · `s600`（训练机已 clone；板端另拷） |
| 机械臂 | SO-101 follower（6 DoF） |
| 相机 | `front`（俯视）+ `wrist`（腕部），USB UVC |

## 必装清单（勾选）

- [x] LeRobot 能 `import`，且支持 `policy.type=pi0`（conda `lerobot_alohamini` 0.5.2）
- [x] 已下载 LeRobot 兼容的 π0 checkpoint（`model.safetensors` ~8.3G）
- [x] clone 了 `rdk_LeRobot_tools`（`s600`）→ `/home/rxn/rdk_LeRobot_tools`
- [x] 量化工具链 / SDK 1.0.2 + conda `oellm_s600` 可用 → 见 [`../quantize/ENV.md`](../quantize/ENV.md)
- [ ] 臂与两路相机在板端都能读到
- [x] 校准集 50 条已生成 → `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2`
- [x] `norm_stats.json` 已导出

## 本机路径备忘

```text
LeRobot:      /home/rxn/lerobot_alohamini
本教程仓:     /home/rxn/lerobot-pi0-rdk-s600-deploy
rdk tools:    /home/rxn/rdk_LeRobot_tools
SDK:          /home/rxn/D-Robotics_LLM_S600_1.0.2_SDK
量化 conda:   oellm_s600
数据集:       /home/rxn/datasets/stack_3blocks_white_blue_black
checkpoint:   /home/rxn/models/pi0_stack_white_blue_black_040000
校准输出:     /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
量化输出:     /home/rxn/gemma/output/pi0_stack3_040000_sdk102
任务文本:     Stack the blocks from bottom to top: white, blue, black.
```

## 一键环境变量（后面章节复用）

```bash
export LEROBOT_ROOT=/home/rxn/lerobot
export TUTORIAL_ROOT=/home/rxn/lerobot-pi0-rdk-s600-deploy
export RDK_TOOLS=/home/rxn/rdk_LeRobot_tools
export DATASET_ROOT=/home/rxn/datasets/stack_3blocks_white_blue_black
export DATASET_NAME=stack_3blocks_white_blue_black
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
export NORM_STATS=$CHECKPOINT/norm_stats.json
export TASK='Stack the blocks from bottom to top: white, blue, black.'
export CALIB_DIR=/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
export QUANT_OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102
export D_ROBOTICS_LLM_SDK_ROOT=/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime
```

量化时另加：`conda activate oellm_s600`（详见 [`../quantize/ENV.md`](../quantize/ENV.md)）。

## clone 官方工具

```bash
cd /home/rxn
git clone https://github.com/D-Robotics/rdk_LeRobot_tools.git
cd rdk_LeRobot_tools
git checkout s600
```

## 下一章

→ [02 训练 π0](./02-train.md)
