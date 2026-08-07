# 01 · 环境准备

> 状态：待填。搭好后把真实版本写进表格。

## 训练机

| 项 | 我的配置 |
|----|----------|
| GPU | |
| CUDA / 驱动 | |
| Python | |
| LeRobot 版本 / 路径 | |
| π0 base 路径 | `.../pi0_base` |

## 板端（RDK S600）

| 项 | 我的配置 |
|----|----------|
| 板端系统 / 镜像 | |
| OE / LLM SDK 版本 | |
| `rdk_LeRobot_tools` 路径与分支 | |
| 机械臂 | SO100 / SO101 / 其他 |
| 相机数量与接口 | |

## 必装清单（勾选）

- [ ] LeRobot 能 `import`，且支持 `policy.type=pi0`
- [ ] 已下载 LeRobot 兼容的 `pi0_base`
- [ ] clone 了 `rdk_LeRobot_tools`（`s600`）
- [ ] 量化工具链能跑通一个最小命令（先记版本，细节后补）
- [ ] 臂与相机在板端/服务器侧都能读到

## 本机路径备忘

```text
LeRobot:     /home/rxn/lerobot
本教程仓:    /home/rxn/lerobot-pi0-rdk-s600-deploy
rdk tools:   （待填）
数据集:      （待填）
checkpoint:  （待填）
```

## 下一章

→ [02 训练 π0](./02-train.md)
