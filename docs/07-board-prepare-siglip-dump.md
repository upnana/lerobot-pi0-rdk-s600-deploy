# 07 · 板端准备：拷文件 + 编 standalone（SigLIP dump 前置）

> 状态：**拷贝与编译已完成**（2026-08-08）  
> dump 本步：本机 **临时 PaliGemma + Expert 已齐**（[08](./08-paligemma-float-bootstrap.md) / [09](./09-expert-float-bootstrap.md)）；下一步把三份 HBM + embedding 补传到板再起 engine。

前置：已完成 [06 板端接入](./06-board-access.md)，SSH：

```bash
export S600=root@192.168.54.29
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" hostname
```

---

## 1. 本机资产清单（量化机）

| 资产 | 本机路径 | 说明 |
|------|----------|------|
| 工具仓 | `/home/rxn/rdk_LeRobot_tools`（`s600`） | dump / standalone / 量化脚本 |
| SigLIP HBM | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm` | ~425MB，已编译 |
| 校准图 | `/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2` | 50 条，`front`+`wrist` |
| norm_stats | `/home/rxn/models/pi0_stack_white_blue_black_040000/norm_stats.json` | 6 维 state/action |
| 教程仓 | `/home/rxn/lerobot-pi0-rdk-s600-deploy` | 只记笔记，不跑量化 |

SigLIP SHA256（校验用）：

```text
123a9da5ac188917cde03fc504266ea3eede501a99d3168952af6817ceeb8915
```

---

## 2. 板上目标目录

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" 'mkdir -p \
  /root/rdk_LeRobot_tools \
  /root/calibration_data \
  /root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip \
  /root/pi0_calibration'
```

| 板上路径 | 内容 |
|----------|------|
| `/root/rdk_LeRobot_tools` | 工具仓 |
| `/root/calibration_data/pi0_stack3_040000_real50_v2` | 校准图 |
| `/root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/` | SigLIP HBM + manifest |
| `/root/pi0_models/versions/pi0_stack3_040000_sdk102/norm_stats.json` | 归一化统计 |
| `/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime` | 板端已有 SDK runtime |

---

## 3. 逐项 rsync / scp（逐步）

在**量化机**执行（WiFi 同网段；速度约数 MB/s～十余 MB/s）：

### 3.1 工具仓（约 9MB，不含 `.git`）

```bash
rsync -a --info=stats2 \
  -e 'ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519' \
  --exclude '.git' \
  /home/rxn/rdk_LeRobot_tools/ \
  "$S600":/root/rdk_LeRobot_tools/
```

### 3.2 校准集（约 3MB）

```bash
rsync -a --info=stats2 \
  -e 'ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519' \
  /home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2/ \
  "$S600":/root/calibration_data/pi0_stack3_040000_real50_v2/
```

### 3.3 SigLIP HBM（约 425MB，最慢）

```bash
rsync -a --info=progress2 \
  -e 'ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519' \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/siglip/quantization_manifest.json \
  "$S600":/root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/
```

### 3.4 norm_stats

```bash
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  /home/rxn/models/pi0_stack_white_blue_black_040000/norm_stats.json \
  "$S600":/root/pi0_models/versions/pi0_stack3_040000_sdk102/norm_stats.json
```

### 3.5 校验

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" '
  ls -lah /root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/
  du -sh /root/rdk_LeRobot_tools /root/calibration_data/pi0_stack3_040000_real50_v2
  test -f /root/rdk_LeRobot_tools/models/pi0/dump_siglip_hbm_calibration.py && echo dump_script_ok
  sha256sum /root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm
'
```

期望 SHA256 与本机一致。

---

## 4. 板上编译 `pi0_standalone_sdk102`

板端已有 `g++`、OpenCV4、Eigen、`libdnn.so`。

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" 'bash -s' <<'EOF'
set -e
export D_ROBOTICS_LLM_SDK_ROOT=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime
cd /root/rdk_LeRobot_tools/models/pi0
bash native/build_standalone_pi0.sh
ls -lah native/install/bin/pi0_standalone_sdk102
EOF
```

本次产物：

```text
/root/rdk_LeRobot_tools/models/pi0/native/install/bin/pi0_standalone_sdk102  (~6.9M)
```

启动包装脚本：`models/pi0/run_pi0_standalone_config.sh`（会先跑 `validate_pi0_config.py`）。

---

## 5. 为什么还不能立刻 dump SigLIP

先读概念笔记：[浮点垫脚 vs dump](../notes/bootstrap-vs-dump.md)。

`validate_pi0_config.py` / standalone 要求这些文件**真实存在**：

1. `siglip_hbm_path` ← **已有**（我们的 HBM）
2. `paligemma_hbm_path` ← **还没有**
3. `action_hbm_path`（Expert）← 临时已出，待 rsync（[09](./09-expert-float-bootstrap.md)）
4. `prompt_embedding_path`（`fixed_prompt_embedding.bin`，形状 `[1,48,2048]` FP16）← **还没有**
5. `norm_stats_path` ← **已有**

SDK 自带的 `Pi0_hammer-beat-block_*.hbm` **不能**直接塞进我们的 `pi0_standalone`（I/O / 命名与 leap_llm 导出的图不一致）。

dump 流程本身（两终端）：

```bash
# 终端 A：收集
cd /root/rdk_LeRobot_tools/models/pi0
python3 -u dump_siglip_hbm_calibration.py \
  --calibration-dir /root/calibration_data/pi0_stack3_040000_real50_v2 \
  --engine-dump-dir /root/pi0_calibration/engine_siglip_real50 \
  --output-dir /root/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
  --prompt 'Stack the blocks from bottom to top: white, blue, black.'

# 终端 B：起 engine（需要完整 deployment JSON）
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6
PI0_STANDALONE_DUMP_DIR=/root/pi0_calibration/engine_siglip_real50 \
  ./run_pi0_standalone_config.sh configs/deployments/<STAGE_CONFIG>.json
```

---

## 6. 下一步怎么补齐缺失 HBM

推荐顺序（与官方一致）：

```text
本机：PaliGemma 量化（可用浮点 SigLIP 中间量做 bootstrap）
  → 产出 paligemma HBM + fixed_prompt_embedding.bin
  →（必要时）Expert bootstrap HBM
  → 拷上板，用「新 SigLIP + bootstrap 后两段」起 engine
  → 板上 dump 真实 SigLIP embedding
  → 本机用真实 embedding 重编 PaliGemma
  → 板上 dump KV → 编 Expert
```

注意：教程仓库 [`quantize/COMMANDS.md`](../quantize/COMMANDS.md) 写的是**理想级联**；第一次把 engine 拉起来时，允许 PaliGemma/Expert 先用浮点中间量 bootstrap，再被真实 dump 覆盖。

板端 dump 脚本默认示例写过 `/home/sunrise/lerobot/.venv/bin/python`——**本板没有该 venv**。改用系统 `python3`，并确保有 `opencv-python` / `numpy` / protobuf 生成的 `msg_pb2`。

---

## 7. 环境对照（别混）

| 用途 | 机器 | 环境 |
|------|------|------|
| 训练 / 抽校准 | PC | conda `lerobot_alohamini` |
| 编 HBM（quantize_*） | PC | conda `oellm_s600` + SDK |
| dump / 跑 standalone | **S600** | 板端 root + oellm_runtime |
| 写教程 | PC | 本 git 仓 |

---

## 8. 本次已完成勾选

- [x] 串口 + SSH（`192.168.54.29`）
- [x] rsync 工具仓 / 校准图 / SigLIP HBM / norm_stats
- [x] 板上编译 `pi0_standalone_sdk102`
- [x] bootstrap PaliGemma (+ embedding) / Expert（本机已出，待补传上板）
- [ ] 写 stage deployment JSON
- [ ] 两终端 dump SigLIP 真实特征
- [ ] 拉回本机 → 重编 PaliGemma
