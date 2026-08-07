# 03 · BF16 基线（量化前必过）

> 状态：待做。这一章用来把「训练问题」和「量化问题」拆开。

## 为什么必须先做

如果直接量化上 S600，真机差时你会同时怀疑：

1. 数据 / 训练  
2. 量化误差  
3. position / mask / 前后处理  
4. 控制频率、标定、相机  

先在服务器用 **同一套相机与控制方式** 跑 BF16：

```text
BF16 也差  → 先别量化，回训练
BF16 正常、HBM 差 → 再查量化与部署
两者离线都正常、真机仍差 → 查控制 / 标定 / 频率
```

## 我怎么验证

| 项 | 记录 |
|----|------|
| checkpoint | `/home/rxn/models/pi0_stack_white_blue_black_040000` |
| 相机 | `front` + `wrist` |
| 任务 | Stack the blocks from bottom to top: white, blue, black. |
| 验证方式 | 服务器 BF16 推理服务 + 板端/本机客户端（官方：`pi0_torch_server.py` / `pi0_remote_pipeline.py`） |
| 任务成功率 / 视频路径 | （待填） |
| 结论 | 通过 / 不通过 |

### 推荐流程（对齐官方工具仓）

GPU 服务器：

```bash
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
cd /home/rxn/rdk_LeRobot_tools

HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 HF_DATASETS_OFFLINE=1 \
python -u models/pi0/pi0_torch_server.py \
  --checkpoint "$CHECKPOINT" \
  --host 0.0.0.0 \
  --port 31001 \
  --device cuda \
  --dtype bfloat16 \
  --camera-keys front wrist \
  --token-file /secure/path/pi0_token
```

板端先只读、不发动作：

```bash
cd /root/rdk_LeRobot_tools/models/pi0
/home/sunrise/lerobot/.venv/bin/python -u pi0_remote_pipeline.py \
  --server-url http://<GPU_SERVER_IP>:31001 \
  --token-file /secure/path/pi0_token \
  --robot-port /dev/ttyACM0 \
  --camera /dev/video0 \
  --side-camera /dev/videoX \
  --max-chunks 1 \
  --prefetch-remaining-steps 0
```

注意：官方脚本参数名可能仍叫 `--side-camera`，接的是你的 **wrist** 设备号。确认后再加 `--execute`。

若你习惯用本仓 LeRobot 的 `lerobot-record` / eval 脚本做真机闭环，也可以；关键是：**同一相机、同一标定、同一任务文本**，并留下视频。

## relative actions 检查

我的训练开了 `use_relative_actions=true`。BF16 基线必须确认：

- 服务器端 policy 按 relative 语义解码
- 下发给 SO-101 的最终目标角正确

如果 BF16 在相对动作下正常，而板上 runtime 只按绝对角写，上板必然偏。先在这一章验证语义，不要拖到量化后才发现。

## 本章完成标准

- [ ] 相同任务下 BF16 能稳定完成（或达到你接受的成功率）
- [ ] 留了视频或日志，方便和板上结果对比
- [ ] relative / absolute 语义已核对

## 下一章

→ [04 量化](./04-quantize.md)
