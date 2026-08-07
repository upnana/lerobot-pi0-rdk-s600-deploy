# 量化环境（训练机）· conda `oellm_s600`

> 状态：已完成（2026-08-08）  
> 用途：跑 `quantize_siglip / paligemma / expert` 三段编译；**不是**训练环境，也**不是**板端环境。

## 和别的环境怎么分

| 环境 | 干什么 |
|------|--------|
| conda `lerobot_alohamini` | 训练、抽校准、BF16 |
| conda **`oellm_s600`** | SDK 量化编译（本章） |
| S600 板端 venv | 真机 runtime / dump HBM 中间量 |

## 已安装内容

| 项 | 路径 / 值 |
|----|-----------|
| SDK 压缩包 | `/home/rxn/sdk/D-Robotics_LLM_S600_1.0.2_SDK.tar.gz`（~880MB） |
| SDK 解压目录 | `/home/rxn/sdk/D-Robotics_LLM_S600_1.0.2_SDK` |
| 软链 | `/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK` → 同上 |
| Runtime | `.../oellm_runtime` |
| Build | `.../oellm_build`（`leap_llm` / `hbdk4` wheel） |
| conda | **`oellm_s600`**，Python **3.10**（wheel 要求 cp310） |
| torch | `2.6.0+cu124`，CUDA 可用（本机 RTX 3090 ×2） |
| leap_llm | `1.0.0` |
| hbdk4-compiler | `4.10.1a2…` |
| GPU march | `nash-p`（量化脚本参数） |

## 我是怎么装的

```bash
# 1) 下载并解压 SDK
mkdir -p /home/rxn/sdk && cd /home/rxn/sdk
wget -c https://d-robotics-aitoolchain.oss-cn-beijing.aliyuncs.com/llm_s600/1.0.2/D-Robotics_LLM_S600_1.0.2_SDK.tar.gz
tar -xzf D-Robotics_LLM_S600_1.0.2_SDK.tar.gz
ln -sfn /home/rxn/sdk/D-Robotics_LLM_S600_1.0.2_SDK /home/rxn/D-Robotics_LLM_S600_1.0.2_SDK

# 2) 新建 Python 3.10 环境（不要复用 lerobot 的 3.12）
conda create -y -n oellm_s600 python=3.10
conda activate oellm_s600

# 3) 先装 SDK 自带 wheel，再装 requirements
BUILD=/home/rxn/sdk/D-Robotics_LLM_S600_1.0.2_SDK/oellm_build
pip install "$BUILD"/hbdk4_compiler-*.whl "$BUILD"/leap_llm-1.0.0-py310-none-any.whl
pip install -r "$BUILD/requirements.txt"
```

下载源见[地瓜论坛工具链汇总](https://forum.d-robotics.cc/t/topic/35229)。

## 每次量化前激活

```bash
conda activate oellm_s600
export D_ROBOTICS_LLM_SDK_ROOT=/home/rxn/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime
export PI0_VALID_CAMERA_SLOTS=2
export RDK_TOOLS=/home/rxn/rdk_LeRobot_tools
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
export CALIB_DIR=/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
export QUANT_OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102
```

自检：

```bash
python -c "import torch,leap_llm,hbdk4; print(torch.__version__, torch.cuda.is_available())"
# 期望类似：2.6.0+cu124 True
```

完整量化命令 → [`COMMANDS.md`](./COMMANDS.md)。

## 踩过的坑（装环境时）

- GitHub / PyPI 要走本机代理时用 **`127.0.0.1:7897`**（verge），不是已失效的 `7890`。
- `hbdk4` / `leap_llm` wheel **只支持 Python 3.10**，不能装进 `lerobot_alohamini`（3.12）。
- `pip install -r requirements.txt` 会拉很大的 CUDA 依赖，磁盘要留足空间，中途断了可重跑（已装的会 skip）。
