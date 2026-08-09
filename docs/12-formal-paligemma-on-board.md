# 12 · 正式 PaliGemma 上板（为 dump KV 做准备）

> 状态：**第 1–2 步已完成**（2026-08-09）——文件已上板 + stage JSON 已校验  
> 前置：[11 正式 PaliGemma](./11-paligemma-formal.md) · SigLIP dump：[10](./10-board-siglip-dump.md)  
> 本步目标：用 **正品 SigLIP + 正式 PaliGemma + 临时 Expert** 凑齐 engine，下一步才能 dump **36× Expert KV**。

**还没跑 KV dump。** 第 3 步（两终端 + `--save-expert-kv`）见文末。

---

## 总流程里本步位置

```text
✓ SigLIP 正品
✓ 板上 dump SigLIP embedding
✓ 正式 PaliGemma（PC 已编）
→ 【本步】正式 PaliGemma 拷上板 + 写 KV-dump 用 JSON
→ 板上 dump PaliGemma KV（--save-expert-kv）
→ PC 编正式 Expert
```

三段现状（本步结束后、开 dump 前）：

| 段 | 板上路径 | 状态 |
|----|----------|------|
| SigLIP | `.../siglip/pi0_siglip_ptq.hbm` | **正品** |
| PaliGemma | `.../paligemma/`（本步新传） | **正式** |
| Expert | `.../expert_float_bootstrap/` | **仍临时**（垫脚） |
| prompt embedding | `.../paligemma/fixed_prompt_embedding.bin` | **正式配套** |

临时垫脚 PaliGemma（`paligemma_float_bootstrap/`）可留着备份，**KV dump 不要再用它**。

---

## 第 1 步 — PC → 板：rsync 正式 PaliGemma

### 本机资产

| 文件 | 本机路径 | 约大小 |
|------|----------|--------|
| HBM | `/home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma/pi0_gemma_llm_ptq.hbm` | 2.0G |
| embedding | `.../paligemma/fixed_prompt_embedding.bin` | 192K |
| manifest（可选） | `.../paligemma/quantization_manifest.json` | — |

HBM SHA256：

```text
410d33ab42adfbebf7852e3d34f49c74fc5d0cb064fd8c78be227d092173122d
```

来源：`vision_embeddings_source=precomputed_s600_siglip_hbm`（见 [11](./11-paligemma-formal.md)）。

### 命令（PC 执行）

```bash
export S600=root@192.168.54.29
export RSYNC_SSH='ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519'
VER=/root/pi0_models/versions/pi0_stack3_040000_sdk102

ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" \
  "mkdir -p $VER/paligemma"

# ~2G，WiFi 会较慢
rsync -a --info=progress2 -e "$RSYNC_SSH" \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma/pi0_gemma_llm_ptq.hbm \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma/fixed_prompt_embedding.bin \
  /home/rxn/gemma/output/pi0_stack3_040000_sdk102/paligemma/quantization_manifest.json \
  "$S600":$VER/paligemma/
```

### 板上校验

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" '
  VER=/root/pi0_models/versions/pi0_stack3_040000_sdk102
  ls -lah $VER/paligemma/pi0_gemma_llm_ptq.hbm \
          $VER/paligemma/fixed_prompt_embedding.bin
  sha256sum $VER/paligemma/pi0_gemma_llm_ptq.hbm
  # 期望 SHA256 与本机一致
  # embedding 必须 196608 字节 = 1*48*2048*2
  wc -c $VER/paligemma/fixed_prompt_embedding.bin
'
```

---

## 第 2 步 — 写 stage JSON（KV dump 专用）

教程仓备份：

[`deploy/pi0_stack3_formal_paligemma_kv_dump.json`](../deploy/pi0_stack3_formal_paligemma_kv_dump.json)

板上路径：

```text
/root/rdk_LeRobot_tools/models/pi0/configs/deployments/pi0_stack3_formal_paligemma_kv_dump.json
```

### 和 SigLIP-dump JSON 的差别

| 字段 | [bootstrap SigLIP dump](../deploy/pi0_stack3_bootstrap_siglip_dump.json) | **本步 KV dump** |
|------|--------------------------------------------------------------------------|------------------|
| `paligemma_hbm_path` | `.../paligemma_float_bootstrap/` | **`.../paligemma/`** |
| `prompt_embedding_path` | 临时 bootstrap embedding | **正式 `paligemma/fixed_prompt_embedding.bin`** |
| `siglip_hbm_path` | 正品 | 正品（不变） |
| `action_hbm_path` | 临时 Expert | 临时 Expert（仍垫脚） |

### JSON 全文

```json
{
  "runtime": "standalone_dnn",
  "siglip_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/siglip/pi0_siglip_ptq.hbm",
  "paligemma_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/paligemma/pi0_gemma_llm_ptq.hbm",
  "action_hbm_path": "/root/pi0_models/versions/pi0_stack3_040000_sdk102/expert_float_bootstrap/pi0_gemma_expert_ptq.hbm",
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
  "candidate_note": "stack3 KV dump stage: final SigLIP + formal PaliGemma + float Expert bootstrap"
}
```

### 上传 + validate（PC）

```bash
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  /home/rxn/lerobot-pi0-rdk-s600-deploy/deploy/pi0_stack3_formal_paligemma_kv_dump.json \
  "$S600":/root/rdk_LeRobot_tools/models/pi0/configs/deployments/

ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 "$S600" \
  'cd /root/rdk_LeRobot_tools/models/pi0 && \
   python3 validate_pi0_config.py configs/deployments/pi0_stack3_formal_paligemma_kv_dump.json'
# 期望：PI0_SO100_STANDALONE_CONFIG_OK
```

`validate` **只检查路径与 embedding 大小**，不加载 BPU、不跑 dump。

---

## 机器分工（本步）

| 动作 | 在哪 |
|------|------|
| rsync / scp / 写 JSON | **PC 执行 → 文件到板** |
| `validate_pi0_config.py` | **板**（经 SSH） |
| 真正 dump KV | **尚未做**（仍要板上两终端） |

---

## 第 3 步预告 — 板上 dump KV（下一步再跑）

与 SigLIP dump 相同结构：**先 A 后 B**；差别是加 `--save-expert-kv`，并换 JSON / dump 目录。

### 终端 A

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29
cd /root/rdk_LeRobot_tools/models/pi0
mkdir -p /root/pi0_calibration
python3 -u dump_siglip_hbm_calibration.py \
  --calibration-dir /root/calibration_data/pi0_stack3_040000_real50_v2 \
  --engine-dump-dir /root/pi0_calibration/engine_paligemma_kv_real50 \
  --output-dir /root/calibration_data/pi0_stack3_040000_paligemma_hbm_kv_real50 \
  --prompt 'Stack the blocks from bottom to top: white, blue, black.' \
  --save-expert-kv
```

### 终端 B

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29
cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6
PI0_STANDALONE_DUMP_DIR=/root/pi0_calibration/engine_paligemma_kv_real50 \
  ./run_pi0_standalone_config.sh \
  configs/deployments/pi0_stack3_formal_paligemma_kv_dump.json
```

每条 sample 期望多出 36 个：

```text
expert_kv_00_fp16.bin … expert_kv_35_fp16.bin
```

跑完后拉回本机，再用 `--paligemma-kv-dir` 编正式 Expert。

---

## 勾选

- [x] rsync 正式 PaliGemma HBM + embedding 上板  
- [x] stage JSON 上传 + `validate` OK  
- [ ] 两终端 dump KV（`--save-expert-kv`）  
- [ ] 拉回本机 → 编正式 Expert  
