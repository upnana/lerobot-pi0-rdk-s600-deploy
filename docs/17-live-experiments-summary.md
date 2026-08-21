# 17 · 真机实验记录总结（2026-08-21）

> 板端：`root@192.168.54.29`（RDK S600）  
> 模型：`pi0_stack_white_blue_black_040000`（2cam front+wrist，relative actions）  
> Bundle：`pi0_stack3_final.json` → `/root/pi0_models/versions/pi0_stack3_040000_sdk102/`  
> 任务：`Stack the blocks from bottom to top: white, blue, black.`

本文记录 **离线 smoke 之后** 的真机闭环、录像与 dataset replay，方便复盘和求职作品集标注。

---

## 1. 上板软件准备

| 项 | 结果 |
|----|------|
| 臂串口 | `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AE6083854-if00` → `ttyACM0` |
| 相机 | UGREEN → `/dev/video0`；USB2.0_CAM1 → `/dev/video2`（front/wrist） |
| 标定 | PC `so101_follower.json` → 板 `.../calibration/robots/so_follower/` |
| LeRobot | rsync alohamini `src` → `/root/lerobot`；无 torch 补丁（`utils/__init__.py`、`types.py`） |
| 依赖 | `feetech-servo-sdk`、`draccus`、`opencv`、`pyserial` |
| 磁盘 | 删除 SDK `.tar.gz` 腾出空间（约剩 4GB+） |
| 启动脚本 | `deploy/run_live_stack3_readonly.sh` / `run_live_stack3.sh` |

板端控制入口仍是官方 `pi0_full_pipeline.py`（类名 SO100），SO-101 走同一 so_follower 协议。

---

## 2. Relative → absolute（关键）

训练：`use_relative_actions=true`，`relative_exclude_joints=["gripper"]`。

只读日志曾出现：

```text
state  ≈ [-2.7, -102, 97, 75, 4, 3]     # 绝对角
action0≈ [0.03, -4.7, -0.5, ...]       # 臂为增量
```

官方 pipeline 默认把模型输出当 Goal_Position。已在板端 `pi0_full_pipeline.py` 增加：

- `--relative-actions`：`absolute = relative + infer_state`（臂）
- gripper 保持绝对
- first-delta 安全门只检查 relative 维

启动脚本已默认打开该开关。

---

## 3. 真机跑通结果

### 3.1 只读（不发力矩）

- 相机 + engine OK，3 chunk 推理完成  
- 加 relative 后 exit **0**  
- 日志例：`/tmp/live_stack3_readonly_relabs_*.log`

### 3.2 Execute（发力矩）

| 跑次 | 配置 | 结果 |
|------|------|------|
| 短跑 | `--max-chunks 5` | **EXECUTE_OK**，torque on，`motor_actions_sent=True` |
| 加长 | `--max-chunks 50` | 用户中断 / 已 stop |
| 录像 | `--max-chunks 30 --record-video` | ~24 chunk 后 Feetech 总线掉线；已录到 MP4 |

**踩坑：** execute 不能带 `--no-fixed-noise`（官方 initial motor smoke 需要 fixed noise）。

**总线：** 长跑中途出现 `no status packet`，力矩关闭也可能失败——需重新插拔/检查供电后再跑。

### 3.3 π0 推理录像（求职可用，需诚实标注）

本地（PC，自板拉取）：

```text
tmp_replay_assets/videos/live_stack3_exec_20260821_210523/output/
  pi0_s600_infer_front_wrist_h264.mp4   # ~6.2MB，~41s，front|wrist
```

建议 caption：

> π0 on RDK S600 closed-loop inference — stack white→blue→black  
> （本段未稳定完成整次叠积木；视频为真实 HBM 闭环片段）

---

## 4. Dataset replay（开环）

Replay **只重放关节轨迹，不看图**。积木不在录制时位置 → **必然抓偏**。

| 数据 | Episode | 帧数 | 本地视频目录 |
|------|---------|------|----------------|
| 2cam | 72 | 578 | `dataset_replay_record_20260821_210402/` |
| 3cam | 59 | 644 | `dataset_replay_3cam_20260821_211823/` |

脚本（本仓 `deploy/replay/`）：

- `replay_episode_record_video.py`
- `run_dataset_replay_record.sh`（2cam）
- `run_dataset_replay_3cam_record.sh`（3cam）
- `episode_*_actions.npy` + meta

参考摆场图：录制集 front/side 抽帧（板外 PC 数据集 videos）。

建议 caption（replay）：

> SO-101 stack — dataset teleop replay on S600（hardware bring-up）  
> **不要**标成 π0 inference

---

## 5. 结论与未完成

**已完成**

- [x] 正式 2cam HBM bundle 上板 + 离线 smoke  
- [x] 板上挂 LeRobot + 标定 + 双相机  
- [x] 只读 / relative 转换 / 短 execute  
- [x] `--record-video` 真·π0 片段  
- [x] 2cam / 3cam dataset replay + 录像  

**未完成 / 不稳定**

- [ ] 任务成功（白→蓝→黑完整叠好）并留成功视频  
- [ ] 长时 execute 不掉总线  
- [ ] BF16 服务器真机基线（docs/03）  
- [ ] 若改用 3cam ckpt：需完整重新量化级联（当前 HBM 是 2cam）

**求职材料建议**

1. 主片：π0 execute 的 `*_h264.mp4`（标 inference）  
2. 辅片：dataset replay（标 teleop replay）  
3. 文档链：本仓 docs/14–17 + 量化笔记  

---

## 6. 板端常用命令备忘

```bash
# 只读
cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6
./run_live_stack3_readonly.sh

# 执行 + 录像（注意急停）
./run_live_stack3.sh --max-chunks 30

# 3cam 数据回放 + 录像
bash replay_assets/run_dataset_replay_3cam_record.sh
```

板端 pipeline 补丁（相对官方）：`--relative-actions`、`--record-video`、relative 维 first-delta 门。源文件在本机 `rdk_LeRobot_tools/models/pi0/pi0_full_pipeline.py`，以板上同步副本为准。
