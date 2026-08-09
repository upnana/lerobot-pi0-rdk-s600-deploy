# 我的 π0 × RDK S600 部署教程

个人复现笔记：用 LeRobot 训一个 **π0**，再量化部署到 **RDK S600**。

> 参考（不是照搬）：[地瓜论坛原帖](https://forum.d-robotics.cc/t/topic/35528) · 官方工具 [`rdk_LeRobot_tools` s600](https://github.com/D-Robotics/rdk_LeRobot_tools)  
> 本仓写的是**我自己走通时的步骤、命令和踩坑**，以本机实操为准。

## 这次复现的任务

| 项 | 我的配置 |
|----|----------|
| 策略 | LeRobot `policy.type=pi0`（不是 π0.5） |
| 机器人 | SO-101 follower（6 维关节） |
| 数据集 | `stack_3blocks_white_blue_black`（199 episodes） |
| 相机 | `front` + `wrist`（640×480，30 FPS） |
| 任务指令 | `Stack the blocks from bottom to top: white, blue, black.` |
| 板端 | RDK S600 + LLM S600 SDK |

和官方示例的主要差异：**相机叫 `wrist` 不是 `side`**；我这边还用了 **relative actions**。量化和部署时不能照抄官方成品 HBM / JSON。

## 教程目录

| 章节 | 内容 | 状态 |
|------|------|------|
| [00 总览](./docs/00-overview.md) | 目标、整条链路、和官方的关系 | 已写 |
| [01 环境](./docs/01-env.md) | 训练机 / 板端 / 路径备忘 | SDK + `oellm_s600` 已好 |
| [02 训练 π0](./docs/02-train.md) | base → post-training → checkpoint | 已有 ckpt |
| [03 BF16 基线](./docs/03-bf16-baseline.md) | 服务器浮点验证，量化前必过 | 待做 |
| [04 量化](./docs/04-quantize.md) | SigLIP → PaliGemma → Expert | **三段正式 HBM 均已出并上板** |
| [05 板上部署](./docs/05-deploy.md) | S600 真机推理与控制 | 待做（正式 bundle 已上板，下一步 smoke/真机） |
| [06 板端接入](./docs/06-board-access.md) | Type-C 串口、brltty、SSH、IP | **已走通** `192.168.54.29` |
| [07 板端准备 dump](./docs/07-board-prepare-siglip-dump.md) | rsync HBM/校准、编 standalone | 已拷贝 SigLIP；PaliGemma/Expert 待补传 |
| [08 浮点垫脚 PaliGemma](./docs/08-paligemma-float-bootstrap.md) | 临时 PaliGemma HBM 编译全过程 | **已完成** |
| [09 浮点垫脚 Expert](./docs/09-expert-float-bootstrap.md) | 临时 Expert HBM 编译全过程 | **已完成** |
| [10 板上 SigLIP dump](./docs/10-board-siglip-dump.md) | 三份上板、改 wrist、两终端 dump | **已完成**（50/50 已拉回） |
| [10b dump 流程讲解](./docs/10b-siglip-dump-where-and-why.md) | 每步在 PC 还是板、在干什么 | 已写 |
| [11 正式 PaliGemma](./docs/11-paligemma-formal.md) | 用板上 SigLIP dump 重编；fixed16 等 | **已完成** |
| [12 正式 PaliGemma 上板](./docs/12-formal-paligemma-on-board.md) | rsync 正式 HBM/embedding、KV dump 准备 | **已完成**（含 KV dump） |
| [13 正式 Expert](./docs/13-expert-formal.md) | 拉回 KV + 用板上 PaliGemma KV 重编 | **已完成** |
| [14 最终上板 bundle](./docs/14-final-bundle-on-board.md) | 正式 Expert + 最终 JSON + validate | **已完成** |
| [踩坑本](./notes/pitfalls.md) | 问题 → 原因 → 处理 | 进行中 |
| [SigLIP 量化分析](./notes/siglip-quantize-analysis.md) | 我怎么理解第一段量化 | 已写 |
| [校准图](./notes/calibration-images.md) | 校准图是什么、从哪来、干什么 | 已写 |
| [浮点垫脚 vs dump](./notes/bootstrap-vs-dump.md) | 为何 3 段 HBM 和 dump 互相等 | 已写 |
| [Expert KV dump 是什么](./notes/expert-kv-dump.md) | `expert_kv_00`…`35` 分别是什么 | 已写 |
| [量化环境](./quantize/ENV.md) | SDK 1.0.2 + conda `oellm_s600` | 已写 |
| [完整命令](./quantize/COMMANDS.md) | 校准 → 量化 → 部署粘贴命令 | 已写 |

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

- [x] 教程仓搭好，目录与章节定稿
- [x] 数据集就绪（`stack_3blocks_white_blue_black`）
- [x] 完整 π0 checkpoint 落盘（`model.safetensors` ~8.3G）
- [x] clone `rdk_LeRobot_tools`（`s600`）
- [x] 导出 `norm_stats.json` + 抽 50 条校准样本（`pi0_stack3_040000_real50_v2`）
- [x] 安装 LLM S600 SDK 1.0.2 + conda `oellm_s600`（见 [`quantize/ENV.md`](./quantize/ENV.md)）
- [x] SigLIP HBM 编译完成（SHA256 见 [`docs/04-quantize.md`](./docs/04-quantize.md)）
- [x] S600 串口 + SSH（`root@192.168.54.29`，详见 [`docs/06-board-access.md`](./docs/06-board-access.md)）
- [x] 板上已拷 SigLIP HBM / 校准图 / 工具仓，并编好 `pi0_standalone_sdk102`（[`docs/07-board-prepare-siglip-dump.md`](./docs/07-board-prepare-siglip-dump.md)）
- [x] 浮点垫脚临时 PaliGemma（[`docs/08-paligemma-float-bootstrap.md`](./docs/08-paligemma-float-bootstrap.md)）
- [x] 浮点垫脚临时 Expert（[`docs/09-expert-float-bootstrap.md`](./docs/09-expert-float-bootstrap.md)）
- [x] 板上 SigLIP dump 50/50 拉回（[`docs/10-board-siglip-dump.md`](./docs/10-board-siglip-dump.md)）
- [x] 正式 PaliGemma（板上 SigLIP dump 校准，[`docs/11-paligemma-formal.md`](./docs/11-paligemma-formal.md)）
- [x] 正式 PaliGemma 上板 + KV dump（[`docs/12-formal-paligemma-on-board.md`](./docs/12-formal-paligemma-on-board.md)）
- [x] 正式 Expert（板上 PaliGemma KV 校准，[`docs/13-expert-formal.md`](./docs/13-expert-formal.md)）
- [x] 最终正式 bundle 上板 + `pi0_stack3_final.json` validate OK（[`docs/14-final-bundle-on-board.md`](./docs/14-final-bundle-on-board.md)）
- [ ] BF16 基线任务成功
- [ ] 离线 smoke / 真机（正式 bundle 已上板）  
  （死结逻辑见 [`notes/bootstrap-vs-dump.md`](./notes/bootstrap-vs-dump.md)）
- [ ] S600 真机跑通

可粘贴命令见 [`quantize/COMMANDS.md`](./quantize/COMMANDS.md)。

## 给读者

如果你也想复现：先读 [00 总览](./docs/00-overview.md)，再按章节顺序做。命令里的路径是我本机的，换成你的即可。官方脚本仍以 `rdk_LeRobot_tools` 为准；本仓记录的是「我怎么改才跑通」。
