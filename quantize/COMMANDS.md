# 量化 → 部署：按本机 ckpt 的完整命令

> ckpt：`/home/rxn/models/pi0_stack_white_blue_black_040000`  
> 数据：`/home/rxn/datasets/stack_3blocks_white_blue_black`  
> 相机：`front` + `wrist`  
> 任务：`Stack the blocks from bottom to top: white, blue, black.`

## 0. 前置状态（2026-08-07 更新）

| 项 | 状态 | 怎么办 |
|----|------|--------|
| `model.safetensors` | 已就绪（~8.3G） | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| `rdk_LeRobot_tools` | 已 clone，`s600` | `/home/rxn/rdk_LeRobot_tools` |
| `norm_stats.json` | 已导出 | 同 checkpoint 目录 |
| 校准集 50 条 | 已生成 | `.../pi0_stack3_040000_real50_v2`（需 `--tolerance-s 0.04`） |
| SigLIP HBM | 已编译 | `.../siglip/pi0_siglip_ptq.hbm`，SHA256 见 `docs/04-quantize.md` |
| S600 SDK 1.0.2 | 训练机已装 + `oellm_s600` | 板上 dump / runtime 另配 |
| S600 板子 | **已 SSH** `root@192.168.54.29` | 串口/接入见 `docs/06-board-access.md`；文件已拷见 `docs/07-...` |
| 板端 standalone | 已编译 | `/root/rdk_LeRobot_tools/.../pi0_standalone_sdk102` |
| PaliGemma / Expert HBM | **临时两段均已出** | [08](../docs/08-paligemma-float-bootstrap.md) / [09](../docs/09-expert-float-bootstrap.md) |

确认权重：

```bash
ls -lah /home/rxn/models/pi0_stack_white_blue_black_040000/model.safetensors
# 期望：约 8.3G 完整文件
```

若尚未 clone 工具仓：

```bash
# 本机代理若在 7897（verge）：
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
cd /home/rxn
git clone --branch s600 --single-branch --depth 1 \
  https://github.com/D-Robotics/rdk_LeRobot_tools.git
```

SDK：按[论坛](https://forum.d-robotics.cc/t/topic/35528)装 **LLM S600 SDK 1.0.2**。常见做法是 GPU 机挂载目录进工具链容器做 `quantize_*`；板端只装 `oellm_runtime`。

---

## 1. 环境变量（训练机）

```bash
export PI0_VALID_CAMERA_SLOTS=2
export RDK_TOOLS=/home/rxn/rdk_LeRobot_tools
export DATASET_ROOT=/home/rxn/datasets/stack_3blocks_white_blue_black
export DATASET_NAME=stack_3blocks_white_blue_black
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
export NORM_STATS=$CHECKPOINT/norm_stats.json
export CALIB_DIR=/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
export QUANT_OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102
export TASK='Stack the blocks from bottom to top: white, blue, black.'
export BUNDLE_NAME=pi0_stack3_040000_front_wrist

mkdir -p "$CALIB_DIR" "$QUANT_OUT" \
  /home/rxn/gemma/calibration_data \
  /home/rxn/gemma/output
cd "$RDK_TOOLS"
```

导出 norm_stats：

```bash
python - <<'PY'
import json, os
from pathlib import Path
stats = json.loads((Path(os.environ["DATASET_ROOT"]) / "meta/stats.json").read_text())
keys = ("mean", "std", "q01", "q99")
out = {
    "norm_stats": {
        "state": {k: stats["observation.state"][k] for k in keys},
        "actions": {k: stats["action"][k] for k in keys},
    }
}
Path(os.environ["NORM_STATS"]).write_text(json.dumps(out, indent=2) + "\n")
print("wrote", os.environ["NORM_STATS"])
PY
```

---

## 2. 校准集（训练机，不需要 SDK）

```bash
cd "$RDK_TOOLS"
python models/pi0/tools/prepare_pi0_calibration_v5_2cam.py \
  --dataset-root "$DATASET_ROOT" \
  --checkpoint "$CHECKPOINT" \
  --output-dir "$CALIB_DIR" \
  --repo-id "local/$DATASET_NAME" \
  --samples 50 \
  --camera-keys front wrist \
  --camera-slots 3 \
  --tolerance-s 0.04 \
  --task "$TASK"
```

> 本数据集默认 `tolerance_s=1e-4` 会触发 `FrameTimestampError`；本地脚本已支持 `--tolerance-s`，建议 `0.04`。校准产物目录名用 `*_v2`。

把校准目录、checkpoint 同步到**装了 SDK 的量化环境**（本机路径或容器 `/host/...`）。

---

## 3. 三段量化（有 SDK 的机器/容器）

顺序不能换：`SigLIP → 板上 dump → PaliGemma → 板上 dump KV → Expert`。

### 3.1 SigLIP

```bash
export PI0_VALID_CAMERA_SLOTS=2
cd "$RDK_TOOLS"   # 容器里可能是 /host/lerobot/rdk_LeRobot_tools

python3 models/pi0/tools/quantize_siglip_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --output-dir "$QUANT_OUT/siglip" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --valid-camera-slots 2 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --max-l2m-size 0 \
  --patch-embedding-mode quant8 \
  --position-embedding-mode fp16 \
  --attention-linear-mode dynamic \
  --mlp-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --projector-linear-mode dynamic \
  --layernorm-mode standard
```

产出：`$QUANT_OUT/siglip/pi0_siglip_ptq.hbm`（文件名以脚本实际输出为准）。

### 3.2 板上 dump SigLIP 真实输出（S600）

把新 SigLIP HBM + 校准图传到板子，写一份**只绑 SigLIP** 的临时 deployment JSON，然后：

```bash
# ===== 板端终端 A：收 dump =====
cd /root/rdk_LeRobot_tools/models/pi0
/home/sunrise/lerobot/.venv/bin/python -u dump_siglip_hbm_calibration.py \
  --calibration-dir /root/calibration_data/pi0_stack3_040000_real50 \
  --engine-dump-dir /root/pi0_calibration/engine_siglip_real50 \
  --output-dir /root/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
  --prompt 'Stack the blocks from bottom to top: white, blue, black.'

# ===== 板端终端 B：起 engine =====
cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6
PI0_STANDALONE_DUMP_DIR=/root/pi0_calibration/engine_siglip_real50 \
./run_pi0_standalone_config.sh configs/deployments/<SIGLIP_STAGE_CONFIG>.json
```

把板端产出的 `pi0_stack3_040000_siglip_hbm_real50` 拉回量化机：

```bash
export SIGLIP_HBM_CALIB=/home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50
# scp -r root@<S600_IP>:/root/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
#   /home/rxn/gemma/calibration_data/
```

### 3.3 PaliGemma（必须用上面真实 SigLIP 输出）

```bash
python3 models/pi0/tools/quantize_paligemma_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --vision-embeddings-dir "$SIGLIP_HBM_CALIB" \
  --output-dir "$QUANT_OUT/paligemma" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --max-samples 50 \
  --num-hidden-layers 18 \
  --jobs 20 \
  --march nash-p \
  --compile-opt 2 \
  --compile-balance 2 \
  --compile-max-l2m-size 0 \
  --max-hbm-bytes 2140000000 \
  --attention-linear-mode dynamic \
  --mlp-linear-mode dynamic \
  --mlp-down-linear-mode dynamic \
  --attention-matmul-mode fixed16 \
  --fixed-prompt "$TASK" \
  --prompt-embedding-input
```

### 3.4 板上 dump 36 组 Expert KV

SigLIP + 新 PaliGemma 一起上板：

```bash
# 终端 A
cd /root/rdk_LeRobot_tools/models/pi0
/home/sunrise/lerobot/.venv/bin/python -u dump_siglip_hbm_calibration.py \
  --calibration-dir /root/calibration_data/pi0_stack3_040000_real50 \
  --engine-dump-dir /root/pi0_calibration/engine_paligemma_kv_real50 \
  --output-dir /root/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50 \
  --prompt 'Stack the blocks from bottom to top: white, blue, black.' \
  --save-expert-kv

# 终端 B
PI0_STANDALONE_DUMP_DIR=/root/pi0_calibration/engine_paligemma_kv_real50 \
./run_pi0_standalone_config.sh configs/deployments/<PALIGEMMA_STAGE_CONFIG>.json
```

拉回量化机：

```bash
export PALIGEMMA_HBM_KV=/home/rxn/gemma/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50
```

### 3.5 Expert

```bash
python3 models/pi0/tools/quantize_expert_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --paligemma-kv-dir "$PALIGEMMA_HBM_KV" \
  --output-dir "$QUANT_OUT/expert" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --transformer-linear-mode dynamic \
  --projection-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --output-linear-mode dynamic
```

---

## 4. 部署启动（S600）

### 4.1 上传 artifact

```bash
ssh root@<S600_IP> "mkdir -p /root/pi0_models/versions/${BUNDLE_NAME}/{siglip,paligemma,expert}"

scp "$QUANT_OUT/siglip/"*.hbm \
  root@<S600_IP>:/root/pi0_models/versions/${BUNDLE_NAME}/siglip/
scp "$QUANT_OUT/paligemma/"*.hbm \
  root@<S600_IP>:/root/pi0_models/versions/${BUNDLE_NAME}/paligemma/
scp "$QUANT_OUT/paligemma/fixed_prompt_embedding.bin" \
  root@<S600_IP>:/root/pi0_models/versions/${BUNDLE_NAME}/paligemma/
scp "$QUANT_OUT/expert/"*.hbm \
  root@<S600_IP>:/root/pi0_models/versions/${BUNDLE_NAME}/expert/
scp "$NORM_STATS" \
  root@<S600_IP>:/root/rdk_LeRobot_tools/models/pi0/configs/norm_stats_${BUNDLE_NAME}.json
```

新建 deployment JSON（相机第二路按 **wrist** 理解；官方字段名可能仍叫 `side`），写入三份 HBM 路径、size、SHA256。

### 4.2 校验 + 离线 smoke

```bash
cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6

/home/sunrise/lerobot/.venv/bin/python validate_pi0_config.py \
  configs/deployments/<NEW_DEPLOYMENT_CONFIG>.json

/home/sunrise/lerobot/.venv/bin/python -u pi0_standalone_offline.py \
  --config configs/deployments/<NEW_DEPLOYMENT_CONFIG>.json \
  --front /path/to/front.jpg \
  --side /path/to/wrist.jpg \
  --state 0 0 0 0 0 0 \
  --output-dir diagnostics/offline_smoke_$(date +%Y%m%d_%H%M%S)
# 期望动作 shape: [50, 6]
```

### 4.3 真机

```bash
cd /root/rdk_LeRobot_tools/models/pi0
./run_live_sync.sh
# 或本教程仓：
# bash /path/to/lerobot-pi0-rdk-s600-deploy/deploy/run_on_s600.sh
```

---

## 建议你现在只做这 3 步

1. 等 `model.safetensors` 下完  
2. `git clone` + `checkout s600` `rdk_LeRobot_tools`  
3. 跑 **§2 校准集**（不用 SDK）  

SDK 装好 / 进容器后，从 **§3.1 SigLIP** 接着做。
