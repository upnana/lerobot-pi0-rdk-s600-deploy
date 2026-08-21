# 16 · 真机收尾（040000 正式 bundle）

> 状态：**真机短闭环已跑通**（只读 → `--relative-actions` → execute；可 `--record-video`）。  
> 完整实验记录见 **[17 真机实验总结](./17-live-experiments-summary.md)**。  
> 模型：继续用 **`pi0_stack_white_blue_black_040000`**（2cam）；3cam 新 ckpt 需重新量化。  
> Bundle：[`pi0_stack3_final.json`](../deploy/pi0_stack3_final.json)

官方入口是 `pi0_full_pipeline.py`（硬编码 `SO100Follower`）。SO-101 通常仍走同一套 so_follower 串口协议，但 **标定文件 / robot-id / 端口** 必须用你的臂。

---

## 0. 安全：relative actions

训练开了 `use_relative_actions=true`。离线 smoke 里 HBM 的 `first_action` 曾出现 **几度级增量**，而 state 是 **±几十～一百度** 绝对角。

`pi0_full_pipeline` 默认把模型输出当 **Goal_Position（绝对角）** 发给舵机。

**发力矩前必须在只读日志里看：**

```text
state=...
action0=...
```

| action0 形态 | 含义 | 能不能 --execute |
|--------------|------|------------------|
| 和 state 同量级（如 -16, -98, 98…） | 更像绝对角 | 可谨慎试 |
| 小数 / 几度（如 1.1, -1.9, -3.8…） | 更像相对增量 | **先别 execute**，要先 `target = state + action`（夹爪按训练约定）或改控制环 |

急停手放在电源/开关旁。

---

## 1. 恢复板子网络

```bash
# PC
ping -c 2 192.168.54.29
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29 hostname
```

不通就串口登录查 WiFi / IP（见 [06](./06-board-access.md)）。

---

## 2. 硬件接到 **S600**（不是 PC）

| 设备 | 接到 |
|------|------|
| SO-101 follower USB | 板子 |
| front 相机 | 板子 `/dev/videoX` |
| wrist 相机 | 板子 `/dev/videoY` |

板上查：

```bash
ls -la /dev/serial/by-id/
ls /dev/ttyACM* /dev/ttyUSB*
ls /dev/video*
# 有 v4l2 时：
v4l2-ctl --list-devices
```

记下实际路径，后面 `export ROBOT_PORT=... FRONT_CAM=... WRIST_CAM=...`。

---

## 3. 板上软件依赖

`pi0_full_pipeline.py` 需要板上能 `import lerobot`（官方常用 `/root/lerobot` 或 sunrise venv）。

```bash
python3 -c "import lerobot; print(lerobot.__file__)"
# 或
/home/sunrise/lerobot/.venv/bin/python -c "import lerobot; print('ok')"
```

没有就先装/挂上 LeRobot，再跑真机。dump / offline smoke 只用 protobuf+standalone，**不等于** live 依赖已齐。

标定：把 follower 的 JSON 放到例如：

```text
/root/rdk_LeRobot_tools/models/pi0/calibration/robots/so_follower/so101_follower.json
```

（文件名与 `--robot-id` 一致；hash 由启动脚本自动算。）

---

## 4. 拷启动脚本到板

PC：

```bash
export S600=root@192.168.54.29
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  /home/rxn/lerobot-pi0-rdk-s600-deploy/deploy/run_live_stack3_readonly.sh \
  /home/rxn/lerobot-pi0-rdk-s600-deploy/deploy/run_live_stack3.sh \
  "$S600":/root/rdk_LeRobot_tools/models/pi0/
ssh ... "$S600" 'chmod +x /root/rdk_LeRobot_tools/models/pi0/run_live_stack3*.sh'
```

---

## 5. 只读跑（不发力矩）— 必做

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29

cd /root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6

# 按实机改：
export ROBOT_PORT=/dev/serial/by-id/<你的串口>
export FRONT_CAM=/dev/video0
export WRIST_CAM=/dev/video2
export ROBOT_ID=so101_follower
export CALIB_FILE=/root/rdk_LeRobot_tools/models/pi0/calibration/robots/so_follower/so101_follower.json
export LEROBOT_ROOT=/root/lerobot   # 或你板上实际路径
export PYTHON_BIN=python3          # 或 sunrise venv 的 python

./run_live_stack3_readonly.sh
```

看日志：

- 能否连上 engine  
- `state=` / `action0=` 量级（relative 判定）  
- 图像是否更新（vision）  

**无 `--execute`，力矩应保持关闭。**

---

## 6. 确认语义后再 execute

仅当只读结果合理时：

```bash
./run_live_stack3.sh
```

脚本带 `--execute --force-model-actions --confirm ENABLE_SO100_MOTORS`（确认字符串是官方写死的，即使臂是 SO-101）。

建议先 `--max-chunks` 改成小数（只读脚本默认 3；execute 脚本默认 0=无限，可临时改）。

---

## 7. 参数对照（别抄官方 side）

| 项 | 我们 |
|----|------|
| config | `pi0_stack3_final.json` |
| 第二路相机名 | **`wrist`**（`--side-camera-name wrist`） |
| task | Stack the blocks from bottom to top: white, blue, black. |
| prefetch | `0`（整 chunk 同步） |
| SigLIP SHA | `123a9da5…8915` |
| PaliGemma SHA | `410d33ab…122d` |
| Expert SHA | `125d00fb…4b32` |
| prompt emb SHA | `e4e974e2…b963` |

---

## 勾选

- [x] 板子 SSH 恢复  
- [x] 臂 + front/wrist 接到 S600，设备节点确认  
- [x] 板上 `import lerobot` OK + SO-101 标定文件就位  
- [x] 只读 live：有 state/action 日志，判定 absolute vs relative  
- [x] relative 已处理后再 `--execute`（短跑 OK）  
- [ ] 叠积木至少成功一次 + 成功视频  
- [x] 回写真实端口 / 命令（见 [17](./17-live-experiments-summary.md)）  

脚本：

- [`deploy/run_live_stack3_readonly.sh`](../deploy/run_live_stack3_readonly.sh)  
- [`deploy/run_live_stack3.sh`](../deploy/run_live_stack3.sh)（含 `--record-video`）  
- [`deploy/replay/`](../deploy/replay/)（dataset teleop 回放）  
