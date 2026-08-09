# 10 · 拷上板起 engine，做 SigLIP dump（操作手册）

> 状态：**操作说明已定稿**（2026-08-09）；dump 本身待实跑勾选  
> 前置：[07 板端准备](./07-board-prepare-siglip-dump.md) · [08 临时 PaliGemma](./08-paligemma-float-bootstrap.md) · [09 临时 Expert](./09-expert-float-bootstrap.md)  
> 概念：[浮点垫脚 vs dump](../notes/bootstrap-vs-dump.md)  
> **先读讲解（PC vs 板、每步干什么）→ [10b](./10b-siglip-dump-where-and-why.md)**

这一步目标：用 **正品 SigLIP** + **临时 PaliGemma/Expert** 把 `pi0_standalone` 拉起来，把 50 条校准图过一遍板上 SigLIP HBM，导出真实 `paligemma_inputs_embeds.bin`，拉回本机后重编正式 PaliGemma。

---

## 机器速查

| 步骤 | 在哪执行 | 一句话 |
|------|----------|--------|
| 0 设变量 / 测 SSH | **PC** | 连上板子 |
| 1 rsync 临时两段 + embedding | **PC 执行 → 文件到板** | 凑齐 3 份 HBM |
| 2 改 dump 脚本(wrist) | **PC 改 → rsync 到板** | 接受 front/wrist |
| 3 stage JSON + validate | **PC 写/传；validate 在板** | 告诉 engine 路径 |
| 4 两终端 dump | **全在板**（先 A 后 B） | 真正跑 SigLIP HBM |
| 5 拉回 embedding | **PC 执行 ← 从板拉** | 供重编正式 PaliGemma |

更细的「每步在干什么」见 [10b](./10b-siglip-dump-where-and-why.md)。

---

## 总流程

```text
本机 rsync 临时 PaliGemma + Expert + embedding
  → 板上写 stage JSON
  → 改 dump 脚本接受 wrist
  → 终端 A 起 dump 收集器
  → 终端 B 起 engine（三份 HBM）
  → 拉回 embedding → 本机重编正式 PaliGemma
```

三段现状（开 dump 时）：

| 段 | 板上用哪份 | 临时？ |
|----|------------|--------|
| SigLIP | `.../siglip/pi0_siglip_ptq.hbm` | **否**（正品） |
| PaliGemma | `.../paligemma_float_bootstrap/` | **是** |
| Expert | `.../expert_float_bootstrap/` | **是** |

---

## 0. 本机固定变量

```bash
export S600=root@192.168.54.29
export SSH='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519'
export RSYNC_SSH='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519'
VER=/root/pi0_models/versions/pi0_stack3_040000_sdk102
```

先确认 SSH：

```bash
$SSH "$S600" hostname
```

---

## 1. 本机：补传缺的两段（SigLIP 之前已拷过）

PaliGemma HBM ~2.0G，WiFi 会较慢。

```bash
# 目录
$SSH "$S600" "mkdir -p $VER/paligemma_float_bootstrap $VER/expert_float_bootstrap"

# 临时 PaliGemma HBM + embedding
rsync -a --info=progress2 -e "$RSYNC_SSH" \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma_float_bootstrap/pi0_gemma_llm_ptq.hbm \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma_float_bootstrap/fixed_prompt_embedding.bin \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma_float_bootstrap/quantization_manifest.json \
  "$S600":$VER/paligemma_float_bootstrap/

# 临时 Expert
rsync -a --info=progress2 -e "$RSYNC_SSH" \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert_float_bootstrap/pi0_gemma_expert_ptq.hbm \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert_float_bootstrap/quantization_manifest.json \
  "$S600":$VER/expert_float_bootstrap/
```

校验：

```bash
$SSH "$S600" "ls -lah \
  $VER/siglip/*.hbm \
  $VER/paligemma_float_bootstrap/*.hbm \
  $VER/paligemma_float_bootstrap/fixed_prompt_embedding.bin \
  $VER/expert_float_bootstrap/*.hbm \
  $VER/norm_stats.json"
```

---

## 2. 本机：改 dump 脚本（必做）再同步工具仓

官方 `dump_siglip_hbm_calibration.py` 硬编码：

```python
if source_manifest.get("camera_keys") != ["front", "side"]:
```

我的校准 `manifest.json` 是 `["front", "wrist"]`，不改会直接 `ValueError`。

改成同时接受 `wrist`：

```python
if source_manifest.get("camera_keys") not in (["front", "side"], ["front", "wrist"]):
    raise ValueError(
        f"Expected front/side or front/wrist calibration cameras, "
        f"got {source_manifest.get('camera_keys')}"
    )
```

文件：`/home/rxn/rdk_LeRobot_tools/models/pi0/dump_siglip_hbm_calibration.py`

然后把工具仓再同步到板：

```bash
rsync -a -e "$RSYNC_SSH" --exclude '.git' \
  /home/rxn/rdk_LeRobot_tools/ \
  "$S600":/root/rdk_LeRobot_tools/
```

读图本身用的是 `image_0.jpg` / `image_1.jpg`，不依赖键名字符串；卡点只在上面的 manifest 检查。

---

## 3. 板上：写 stage deployment JSON

路径：

```text
/root/rdk_LeRobot_tools/models/pi0/configs/deployments/pi0_stack3_bootstrap_siglip_dump.json
```

本教程仓备份：[deploy/pi0_stack3_bootstrap_siglip_dump.json](../deploy/pi0_stack3_bootstrap_siglip_dump.json)

内容：

```json
{
  "runtime": "standalone_dnn",
  "siglip_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm",
  "paligemma_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/paligemma_float_bootstrap/pi0_gemma_llm_ptq.hbm",
  "action_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/expert_float_bootstrap/pi0_gemma_expert_ptq.hbm",
  "prompt_embedding_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/paligemma_float_bootstrap/fixed_prompt_embedding.bin",
  "siglip_bpu_core": [0, 1, 2],
  "paligemma_bpu_core": [0],
  "action_bpu_core": [0, 1, 2, 3],
  "norm_stats_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/norm_stats.json",
  "server_ip": "127.0.0.1",
  "server_port": 30001,
  "state_size": 6,
  "exec_size": 6,
  "real_camera_num": 2,
  "action_mode": "absolute",
  "denoise_num": 10,
  "parallel_siglip": true,
  "task": "Stack the blocks from bottom to top: white, blue, black.",
  "candidate_note": "stack3 bootstrap: final SigLIP + float PaliGemma/Expert for SigLIP dump only"
}
```

本机 scp 上去（可选）：

```bash
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  /home/rxn/lerobot-pi0-rdk-s600-deploy/deploy/pi0_stack3_bootstrap_siglip_dump.json \
  "$S600":/root/rdk_LeRobot_tools/models/pi0/configs/deployments/
```

先校验配置：

```bash
$SSH "$S600" 'cd /root/rdk_LeRobot_tools/models/pi0 && \
  python3 validate_pi0_config.py configs/deployments/pi0_stack3_bootstrap_siglip_dump.json'
# 期望：PI0_SO100_STANDALONE_CONFIG_OK
```

`validate_pi0_config.py` 会检查三份 HBM、`fixed_prompt_embedding.bin`（必须是 `[1,48,2048]` FP16 = 196608 字节）、以及 `norm_stats` 的 6 维 state/actions。

---

## 4. 板上两终端 dump（顺序别反）

dump 脚本是 **TCP server**（听 `30001`），engine 是 **client**。必须 **先 A 后 B**。

`PI0_STANDALONE_DUMP_DIR` 必须和 `--engine-dump-dir` **同一路径**。

### 终端 A（先开）：收集器

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29

cd /root/rdk_LeRobot_tools/models/pi0
mkdir -p /root/pi0_calibration
python3 -u dump_siglip_hbm_calibration.py \
  --calibration-dir /root/calibration_data/pi0_stack3_040000_real50_v2 \
  --engine-dump-dir /root/pi0_calibration/engine_siglip_real50 \
  --output-dir /root/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
  --prompt 'Stack the blocks from bottom to top: white, blue, black.'
```

看到：

```text
SIGLIP_CALIBRATION_SERVER_READY host=127.0.0.1 port=30001 samples=50
```

再开 B。用系统 **`python3`**，板子没有 `/home/sunrise/lerobot/.venv`。

### 终端 B：起 engine

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29

cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6
PI0_STANDALONE_DUMP_DIR=/root/pi0_calibration/engine_siglip_real50 \
  ./run_pi0_standalone_config.sh \
  configs/deployments/pi0_stack3_bootstrap_siglip_dump.json
```

成功时 A 会逐条刷 50 个 sample，并出现 `S600_ENGINE_CONNECTED`。

产出目录：

```text
/root/calibration_data/pi0_stack3_040000_siglip_hbm_real50/<id>/paligemma_inputs_embeds.bin
```

每份约 `1×768×2048` FP16 ≈ 3MB（三槽拼在一起：2 真相机 + 1 empty）。

中断重跑可加 `--resume`（输出目录已存在时）。

---

## 5. 拉回本机

```bash
rsync -a --info=progress2 -e "$RSYNC_SSH" \
  "$S600":/root/calibration_data/pi0_stack3_040000_siglip_hbm_real50/ \
  /home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50/
```

本机快速数一下：

```bash
find /home/rxn/gemma/calibration_data/pi0_stack3_040000_siglip_hbm_real50 \
  -name paligemma_inputs_embeds.bin | wc -l
# 期望：50
```

之后本机用这份目录当 `--vision-embeddings-dir`，重编**正式** PaliGemma（不再用浮点垫脚）。

---

## 注意一览

| 点 | 说明 |
|----|------|
| 先 A 后 B | dump 是 server，engine 连上来 |
| `PI0_STANDALONE_DUMP_DIR` | 必须和 `--engine-dump-dir` 同一路径 |
| `front` / `wrist` | dump 脚本默认只认 `side`，必须改 |
| 系统 `python3` | 不要抄官方 sunrise venv 路径 |
| 临时 PaliGemma/Expert | 只为凑齐 3 段起 engine；dump 完要重编正式版 |
| `action_mode` | dump 阶段跟官方一样用 `absolute`；relative 是后面真机控制的事 |
| 校准目录名 | 用 `..._real50_v2`，不是旧的 `_real50` |

---

## 勾选

- [ ] rsync 临时 PaliGemma / Expert / embedding
- [ ] dump 脚本接受 `front`/`wrist`
- [ ] stage JSON + `validate_pi0_config` OK
- [ ] 两终端跑完 50 条
- [ ] 拉回本机 50 个 `paligemma_inputs_embeds.bin`
- [ ] 用真实 embedding 重编正式 PaliGemma
