# quantize/

把 **已验证的 BF16 π0 checkpoint** 量化编译成 S600 可跑的三段 HBM。

## 前置条件

- [ ] `train/` 产出的 checkpoint 完整存在
- [ ] 服务器 BF16 真机基线正常（叠积木能完成）
- [ ] 已安装 D-Robotics LLM S600 SDK 1.0.2
- [ ] 本地已 clone [`rdk_LeRobot_tools`](https://github.com/D-Robotics/rdk_LeRobot_tools) 的 `s600` 分支

## 级联顺序（不要打乱）

```text
1. 从训练数据抽校准样本（覆盖完整任务阶段）
2. 量化 SigLIP  → 板上跑出真实视觉特征
3. 用 SigLIP HBM 输出校准并量化 PaliGemma
4. 用 PaliGemma 真实 KV 校准并量化 Action Expert
5. 核对 Prompt Embedding / Normalization Stats / SHA256
```

教程强调：**下游校准必须看到上游 HBM 的真实输出**，不能三段各自用浮点中间量独立量化后硬拼。

## 本目录放什么

- **可粘贴完整命令**：[`COMMANDS.md`](./COMMANDS.md)（按本机 ckpt 写好）
- **量化环境说明**：[`ENV.md`](./ENV.md)（`oellm_s600` + SDK 1.0.2）
- 勾选备忘：[`steps.md`](./steps.md)
- 与官方脚本的差异说明（`front`/`wrist`、relative actions 等）


大文件（`.hbm` / ONNX / 校准 bin）不要提交 git。

## 参考

- 正文：[docs/04-quantize.md](../docs/04-quantize.md)
- 论坛：[量化原理 + 量化实操](https://forum.d-robotics.cc/t/topic/35528)
- 官方：`rdk_LeRobot_tools/models/pi0/`
