# 02 · 训练 π0（Post-training）

> 状态：进行中。目标不是从零预训练，而是用 `pi0_base` + 自己的数据做下游适配。

## 本章目标

得到一份可复现的 BF16 checkpoint，例如：

```text
/home/rxn/models/pi0_stack_white_blue_black_040000/
  ├── config.json
  ├── model.safetensors          # 必须完整（数 GB 级），不能是半截临时文件
  └── （可选）policy_preprocessor.json 等
```

## 数据

| 项 | 记录 |
|----|------|
| 本地路径 | `/home/rxn/datasets/stack_3blocks_white_blue_black` |
| 格式 | LeRobot `v3.0` |
| 机器人 | `so101_follower` |
| 相机 | `observation.images.front` + `observation.images.wrist` |
| episode 数 | 199 |
| 帧数 | 122,138 |
| FPS | 30 |
| 任务描述 | Stack the blocks from bottom to top: white, blue, black. |
| 动作 / 状态 | 6 维：`shoulder_pan/lift`、`elbow_flex`、`wrist_flex/roll`、`gripper` |

训练时相机名字必须和后面校准、部署一致：我这边是 **`front` / `wrist`**，不是官方示例里的 `side`。

### 我这份 checkpoint 的关键 config 点

来自 `config.json`（摘要）：

- `type: pi0`
- `chunk_size / n_action_steps: 50`
- `num_inference_steps: 10`
- `use_relative_actions: true`（gripper 除外）
- `empty_cameras: 0`
- 输入图像：`front` + `wrist`

上板前要核对：官方 S600 编译图若强制 3 物理槽（2 真相机 + 1 mask），需要和训练 schema 对齐，否则 position / mask 会错。详见 [踩坑本](../notes/pitfalls.md)。

## 怎么启动

脚本模板：[`../train/train_pi0.sh`](../train/train_pi0.sh)

```bash
cd /home/rxn/lerobot-pi0-rdk-s600-deploy

export BASE_MODEL=/path/to/pi0_base
export DATASET_ROOT=/home/rxn/datasets/stack_3blocks_white_blue_black
export DATASET_REPO_ID=local/stack_3blocks_white_blue_black
export OUTPUT_DIR=/home/rxn/models/pi0_stack_white_blue_black_040000
export STEPS=40000

bash train/train_pi0.sh
```

实际 CLI 以你本机 LeRobot 版本 + `rdk_LeRobot_tools/models/pi0` 脚本为准；跑通后把**最终完整命令**贴回本章，覆盖模板。

### 导出 norm_stats（部署要用）

从数据集 `meta/stats.json` 抽出 state/action 统计，供板上反归一化：

```bash
export DATASET_ROOT=/home/rxn/datasets/stack_3blocks_white_blue_black
export NORM_STATS=/home/rxn/models/pi0_stack_white_blue_black_040000/norm_stats.json

python - <<'PY'
import json, os
from pathlib import Path
stats = json.loads((Path(os.environ["DATASET_ROOT"]) / "meta/stats.json").read_text())
keys = ("mean", "std", "q01", "q99")
result = {
    "norm_stats": {
        "state": {k: stats["observation.state"][k] for k in keys},
        "actions": {k: stats["action"][k] for k in keys},
    }
}
Path(os.environ["NORM_STATS"]).write_text(json.dumps(result, indent=2) + "\n")
print("wrote", os.environ["NORM_STATS"])
PY
```

## 训练时盯什么

- loss 曲线是否持续下降
- 中间 checkpoint 的推理视频（不要只看数字）
- 双相机任务更倾向**全参数** post-training（只训 Expert 往往不够）
- 落盘是否完整：`ls -lh $CHECKPOINT/model.safetensors`

## 本章完成标准

- [ ] checkpoint 目录齐全（`config.json` + 完整 `model.safetensors`）
- [ ] `norm_stats.json` 已导出
- [ ] 离线或真机粗看动作合理
- [ ] 路径写进 [01 环境](./01-env.md)

## 下一章

→ [03 BF16 基线](./03-bf16-baseline.md)
