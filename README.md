# 我的 π0 × RDK S600 部署教程

个人复现笔记：用 LeRobot 训一个 **π0**，再量化部署到 **RDK S600**。

> 参考（不是照搬）：[地瓜论坛原帖](https://forum.d-robotics.cc/t/topic/35528) · 官方工具 [`rdk_LeRobot_tools` s600](https://github.com/D-Robotics/rdk_LeRobot_tools)  
> 本仓写的是**我自己走通时的步骤、命令和踩坑**，以本机实操为准。

## 教程目录

| 章节 | 内容 | 状态 |
|------|------|------|
| [00 总览](./docs/00-overview.md) | 目标、整条链路、和官方的关系 | 骨架 |
| [01 环境](./docs/01-env.md) | 训练机 / 板端 / 依赖版本 | 待填 |
| [02 训练 π0](./docs/02-train.md) | base → post-training → checkpoint | 待填 |
| [03 BF16 基线](./docs/03-bf16-baseline.md) | 服务器浮点验证，量化前必过 | 待填 |
| [04 量化](./docs/04-quantize.md) | SigLIP → PaliGemma → Expert | 待填 |
| [05 板上部署](./docs/05-deploy.md) | S600 真机推理与控制 | 待填 |
| [踩坑本](./notes/pitfalls.md) | 问题 → 原因 → 处理 | 进行中 |

## 一条线记住

```text
pi0_base
  → 自己的数据 post-training（BF16）
  → 服务器真机基线 OK
  → 三段级联量化（HBM）
  → S600 同步推理
```

**不要**直接拿未验证的 checkpoint 去量化；BF16 都跑不好，量化救不回来。

## 代码与脚本

| 目录 | 放什么 |
|------|--------|
| [`train/`](./train/) | 训练启动脚本 |
| [`quantize/`](./quantize/) | 量化命令备忘 |
| [`deploy/`](./deploy/) | 板端启动脚本 |
| [`docs/`](./docs/) | 教程正文 |
| [`notes/`](./notes/) | 踩坑与实验记录 |

大文件（权重、HBM、数据集）不进 git，见 `.gitignore`。

## 进度（自己改）

- [ ] 环境搭好
- [ ] π0 训完并保存 checkpoint
- [ ] BF16 基线任务成功
- [ ] 三段 HBM 产出
- [ ] S600 真机跑通
