# 15 · 离线 smoke + BF16 vs HBM 对比结果（2026-08-11）

> 状态：**已完成**（离线；非真机）  
> Bundle：[14 最终上板](./14-final-bundle-on-board.md) · JSON：`pi0_stack3_final.json`  
> 原始对比备忘：[`notes/bench/compare_bf16_vs_hbm_sample0.md`](../notes/bench/compare_bf16_vs_hbm_sample0.md)

同一校准样本 `0`（front + wrist + `raw_state`），任务句：

```text
Stack the blocks from bottom to top: white, blue, black.
```

---

## 1. 板上离线 smoke（量化后 HBM）

```bash
# 板上
cd /root/rdk_LeRobot_tools/models/pi0
python3 -u pi0_standalone_offline.py \
  --config configs/deployments/pi0_stack3_final.json \
  --front /root/calibration_data/pi0_stack3_040000_real50_v2/images/0/image_0.jpg \
  --side  /root/calibration_data/pi0_stack3_040000_real50_v2/images/0/image_1.jpg \
  --state <raw_state 6 维> \
  --task 'Stack the blocks from bottom to top: white, blue, black.' \
  --output-dir diagnostics/offline_smoke_stack3_final_YYYYMMDD_HHMMSS
```

| 项 | 结果 |
|----|------|
| 配置 | `pi0_stack3_final.json`（三段正式 HBM） |
| 动作 shape | **`[50, 6]`** |
| 端到端时延 | **1224.71 ms**（client send→recv，n=1） |
| 板上目录 | `diagnostics/offline_smoke_stack3_final_20260811_155544` |

摘要 JSON：[`notes/bench/hbm_smoke_sample0_summary.json`](../notes/bench/hbm_smoke_sample0_summary.json)

---

## 2. PC BF16 时延（量化前参考）

| 项 | 结果 |
|----|------|
| 设备 | RTX 3090 `cuda:0` |
| 运行时 | LeRobot π0 BF16 `predict_action_chunk` |
| 加载 | 66.74 s |
| 协议 | warmup 5 + timed 20，`cuda.synchronize`，`noise_seed=0` |
| **mean / p50 / p90** | **154.84 / 154.40 / 156.07 ms** |
| min / max / std | 152.18 / 161.66 / 2.34 ms |
| 动作 shape | **`[50, 6]`** |

摘要 JSON：[`notes/bench/bf16_latency_sample0_summary.json`](../notes/bench/bf16_latency_sample0_summary.json)

---

## 3. 对比表

| 端 | 运行时 | 加载 | 端到端 infer | shape |
|----|--------|------|----------------|-------|
| PC RTX 3090 | BF16 torch（量化前） | 66.7 s | **154.8 ms**（n=20） | `[50,6]` |
| S600 | HBM standalone（量化后） | — | **1224.7 ms**（n=1） | `[50,6]` |

粗算：`1224.7 / 154.8 ≈ 7.9` → 板上约 **~8×** 于 3090 BF16。

### 动作误差（同 fixed noise）

| 指标 | 值 |
|------|-----|
| MAE | **1.60°** |
| RMSE | **2.32°** |
| 每维 MAE | pan 0.52 · lift 1.36 · elbow 1.12 · wrist_flex 3.84 · wrist_roll 0.79 · gripper 1.94 |

（BF16 绝对角对齐到 relative / mixed 语义后再比。）

---

## 4. 怎么理解「量化了反而更慢」

这是 **3090 BF16 vs S600 HBM**，不是同芯片上「浮点 vs 量化」。

- HBM = **已经量化**、给板上 BPU 用的产物  
- 量化目的是 **能上板跑**，不是赢过桌面 GPU  
- ~8× 慢来自 **平台算力差**；离线 smoke 能出 `[50,6]` 且动作误差不大，说明链路可用  

---

## 5. 尚未做

- [ ] 接 SO-101 + 相机的真机闭环  
- [ ] 叠积木任务成功率 / 视频  
- [ ] 板上多 chunk 长时间跑  

---

## 勾选

- [x] 最终 bundle 离线 smoke `[50,6]`  
- [x] BF16 时延统计（n=20）  
- [x] BF16 vs HBM 对比记录入库  
- [ ] 真机  
