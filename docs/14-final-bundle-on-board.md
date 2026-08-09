# 14 · 三段正式 HBM 上板 + 最终 deployment JSON

> 状态：**已完成**（2026-08-09）——正式 Expert 已上板，最终 JSON 已 `validate` OK  
> 前置：[11](./11-paligemma-formal.md) · [12](./12-formal-paligemma-on-board.md) · [13](./13-expert-formal.md)  
> 下一步：离线 smoke / 真机控制（[05](./05-deploy.md)）——注意 SO-101 与 relative actions

本步把 **正式 Expert** 补上板，并写一份**最终** deployment JSON（三份路径全部指向正式目录，不再用 `*_float_bootstrap`）。

---

## 板上最终布局

```text
/root/pi0_models/versions/pi0_stack3_040000_sdk102/
  siglip/pi0_siglip_ptq.hbm                         # 正式 SigLIP（早已上板）
  paligemma/pi0_gemma_llm_ptq.hbm                   # 正式 PaliGemma（[12] 已上板）
  paligemma/fixed_prompt_embedding.bin
  expert/pi0_gemma_expert_ptq.hbm                   # 正式 Expert（本步新传）
  norm_stats.json
```

| 段 | 板上路径 | SHA256（本机） |
|----|----------|----------------|
| SigLIP | `.../siglip/pi0_siglip_ptq.hbm` | `123a9da5ac188917cde03fc504266ea3eede501a99d3168952af6817ceeb8915` |
| PaliGemma | `.../paligemma/pi0_gemma_llm_ptq.hbm` | `410d33ab42adfbebf7852e3d34f49c74fc5d0cb064fd8c78be227d092173122d` |
| Expert | `.../expert/pi0_gemma_expert_ptq.hbm` | `125d00fb98a2bb4ef916d1858bbed19e50e029775fe72a19cebbe68b9bae4b32` |

临时目录 `paligemma_float_bootstrap/`、`expert_float_bootstrap/` 可留作备份，**最终部署不要再指向它们**。

---

## 第 1 步 — PC → 板：rsync 正式 Expert

```bash
export S600=root@192.168.54.29
export RSYNC_SSH='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519'
VER=/root/pi0_models/versions/pi0_stack3_040000_sdk102

ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" "mkdir -p $VER/expert"

rsync -a --info=progress2 -e "$RSYNC_SSH" \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert/pi0_gemma_expert_ptq.hbm \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/expert/quantization_manifest.json \
  "$S600":$VER/expert/
```

校验：

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" '
  VER=/root/pi0_models/versions/pi0_stack3_040000_sdk102
  ls -lah $VER/siglip/*.hbm $VER/paligemma/*.hbm $VER/expert/*.hbm \
          $VER/paligemma/fixed_prompt_embedding.bin $VER/norm_stats.json
  sha256sum $VER/expert/pi0_gemma_expert_ptq.hbm
'
# Expert SHA256 期望：125d00fb98a2bb4ef916d1858bbed19e50e029775fe72a19cebbe68b9bae4b32
```

---

## 第 2 步 — 最终 deployment JSON

教程仓备份：[`deploy/pi0_stack3_final.json`](../deploy/pi0_stack3_final.json)

板上路径：

```text
/root/rdk_LeRobot_tools/models/pi0/configs/deployments/pi0_stack3_final.json
```

### 和上一份 KV-dump JSON 的差别

| 字段 | [KV dump JSON](../deploy/pi0_stack3_formal_paligemma_kv_dump.json) | **最终 JSON** |
|------|---------------------------------------------------------------------|---------------|
| `action_hbm_path` | `.../expert_float_bootstrap/` | **`.../expert/`** |
| SigLIP / PaliGemma / embedding | 已正式 | 不变 |
| `candidate_note` | KV dump stage | **FINAL** 三段正式 |

### JSON 全文

```json
{
  "runtime": "standalone_dnn",
  "siglip_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm",
  "paligemma_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/paligemma/pi0_gemma_llm_ptq.hbm",
  "action_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/expert/pi0_gemma_expert_ptq.hbm",
  "prompt_embedding_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/paligemma/fixed_prompt_embedding.bin",
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
  "candidate_note": "stack3 FINAL: formal SigLIP + formal PaliGemma + formal Expert (precomputed S600 cascade)"
}
```

### 上传 + validate

```bash
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  /home/rxn/lerobot-pi0-rdk-s600-deploy/deploy/pi0_stack3_final.json \
  "$S600":/root/rdk_LeRobot_tools/models/pi0/configs/deployments/

ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" \
  'cd /root/rdk_LeRobot_tools/models/pi0 && \
   python3 validate_pi0_config.py configs/deployments/pi0_stack3_final.json'
# 期望：PI0_SO100_STANDALONE_CONFIG_OK
```

---

## 机器分工

| 动作 | 在哪 |
|------|------|
| rsync Expert / scp JSON | **PC → 板** |
| `validate_pi0_config.py` | **板** |
| 离线 smoke / 真机 | **板**（下一步） |

---

## 下一步（尚未做）

### 离线 smoke（不接臂）

```bash
# 板上；python 用系统 python3（无 sunrise venv 时）
cd /root/rdk_LeRobot_tools/models/pi0
python3 -u pi0_standalone_offline.py \
  --config configs/deployments/pi0_stack3_final.json \
  --front /root/calibration_data/pi0_stack3_040000_real50_v2/images/0/image_0.jpg \
  --side  /root/calibration_data/pi0_stack3_040000_real50_v2/images/0/image_1.jpg \
  --state 0 0 0 0 0 0 \
  --output-dir diagnostics/offline_smoke_stack3_final_$(date +%Y%m%d_%H%M%S)
```

期望动作输出 shape `[50, 6]`。官方参数名可能仍叫 `--side`，这里第二路是 **wrist** 图。

### 真机

见 [05](./05-deploy.md) / `run_live_sync.sh` 一类入口。注意：

- 机械臂是 **SO-101**，官方脚本默认 SO100 —— 端口 / 标定 / `robot-id` 要改  
- 训练开了 **`use_relative_actions`**；JSON 里 `action_mode` 目前跟官方示例写 `absolute`，真机前核对语义  

---

## 勾选

- [x] rsync 正式 Expert 上板  
- [x] 最终 JSON 上传 + `validate` OK  
- [ ] 离线 smoke `[50,6]`  
- [ ] 真机跑通  
