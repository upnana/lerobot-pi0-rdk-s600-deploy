# 02 · 训练 π0（Post-training）

> 状态：待填。目标不是从零预训练，而是用 `pi0_base` + 自己的数据做下游适配。

## 本章目标

得到一份可复现的 BF16 checkpoint，例如：

```text
outputs/train/<run_name>/checkpoints/<step>/pretrained_model/
```

## 数据

| 项 | 记录 |
|----|------|
| 数据集 repo_id / 本地路径 | |
| 相机（几路、名字映射） | |
| episode 数 / 任务描述 | |
| 语言指令（固定还是多样） | |

训练时相机映射按自己的 schema 记清楚（官方教程常见：`front → base_0_rgb` 等）。写错映射，后面量化和部署都会一起错。

## 怎么启动

脚本模板：[`../train/train_pi0.sh`](../train/train_pi0.sh)

```bash
cd /home/rxn/lerobot-pi0-rdk-s600-deploy
# 改脚本里的 BASE_MODEL / DATASET_REPO_ID / OUTPUT_DIR
bash train/train_pi0.sh
```

实际 CLI 参数以你本机 LeRobot 版本 + 官方 `models/pi0` 脚本为准；跑通后把**最终命令**贴回这里，覆盖模板。

## 训练时盯什么

- loss 曲线
- 中间 checkpoint 的推理视频（不要只看数字）
- 是否全参数训练还是只训 Expert（双相机域偏移大时，官方建议更倾向全参数）

## 本章完成标准

- [ ] checkpoint 目录齐全（`config` + 权重）
- [ ] 离线或真机粗看动作合理
- [ ] 路径写进 [01 环境](./01-env.md)

## 下一章

→ [03 BF16 基线](./03-bf16-baseline.md)
