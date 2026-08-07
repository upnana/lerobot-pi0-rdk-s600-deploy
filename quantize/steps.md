# 量化步骤备忘

> 跟着论坛教程填；命令以 `rdk_LeRobot_tools` 为准，这里只记自己的路径和结果。

## 环境

| 项 | 值 |
|----|----|
| 训练 checkpoint | |
| SDK / OE 版本 | |
| rdk_LeRobot_tools 路径 / 分支 | |
| 校准样本数 | |

## Step 0 — 校准集

- [ ] 从训练数据均匀抽样本
- [ ] 覆盖接近、抓取、放置等阶段

命令 / 路径：

```bash
# TODO: 粘贴教程中的抽校准样本命令，并改成自己的路径
```

## Step 1 — SigLIP

- [ ] 量化 + 编译 HBM
- [ ] 板上跑双相机样本，导出视觉特征给 PaliGemma

```bash
# TODO
```

结果 SHA256：

## Step 2 — PaliGemma

- [ ] 用 SigLIP HBM 真实输出做校准
- [ ] 量化 + 编译
- [ ] 板上导出 36 组 KV

```bash
# TODO
```

结果 SHA256：

## Step 3 — Action Expert

- [ ] 用真实 PaliGemma KV 校准
- [ ] 量化 + 编译

```bash
# TODO
```

结果 SHA256：

## 产出清单

- [ ] `siglip.hbm`
- [ ] `paligemma.hbm`
- [ ] `expert.hbm`
- [ ] prompt embedding / norm stats
