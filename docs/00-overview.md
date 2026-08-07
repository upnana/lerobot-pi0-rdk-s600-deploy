# 00 · 总览：我要做什么

## 一句话目标

在 **SO-101 叠三块积木** 数据上微调 **π0**，确认 GPU 上 BF16 能完成任务后，再按地瓜工具链量化，部署到 **RDK S600** 真机推理。

## 这条链路里各段干什么

| 阶段 | 在哪做 | 输入 | 输出 |
|------|--------|------|------|
| Post-training | GPU 服务器 | `pi0_base` + 自己的数据集 | BF16 checkpoint |
| BF16 基线 | 服务器 + 真机相机/臂 | checkpoint | 「浮点能完成任务」的证据 |
| 量化 | 量化服务器 + 板端校准 | BF16 checkpoint + 校准样本 | SigLIP / PaliGemma / Expert 三份 HBM |
| 部署 | RDK S600 | HBM + runtime | 板上闭环控制 |

```text
图像(front,wrist)
  → SigLIP HBM
  → PaliGemma HBM（prefix KV）
  → Expert HBM × 10（flow matching）
  → [50, 6] 关节动作
```

## 和官方教程的关系

- **[官方论坛](https://forum.d-robotics.cc/t/topic/35528) / [`rdk_LeRobot_tools`](https://github.com/D-Robotics/rdk_LeRobot_tools)**：工具、脚本、已验证流程的来源。
- **本教程**：我复现时的路径、版本、改过的命令、失败案例。  
  冲突时以「我这台机器实际跑通的」为准，并在 [踩坑本](../notes/pitfalls.md) 记下差异。

### 我这次和官方示例的差异（先记住）

| 点 | 官方示例 | 我这次 |
|----|----------|--------|
| 臂 | SO100 | SO-101（同样 6 维绝对关节名） |
| 相机 | `front` + `side` | `front` + `wrist` |
| 任务 | 相机盒放到 MCU 盒上 | 白→蓝→黑叠积木 |
| 动作表示 | 绝对角为主 | 训练开了 `use_relative_actions=true` |
| empty camera | 常留 1 个 mask 空槽 | 训练 config 里 `empty_cameras=0`（上板前要对齐编译图） |

这些差异意味着：**不能直接复用官方成品 HBM / deployment JSON**，校准集、prompt、norm_stats、manifest 都要按自己的 checkpoint 重做。

## 明确不做的事

- 不从零预训练通用 π0（用现成 `pi0_base`）。
- 不在本教程里走 π0.5（量化链路目前按 π0 切分）。
- 不把大权重、数据集推进这个 git 仓。

## 下一章

→ [01 环境](./01-env.md)
