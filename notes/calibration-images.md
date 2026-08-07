# 校准图是什么（我怎么理解）

> 叠积木 π0 → S600 量化语境下的笔记。

## 一句话

**校准图** = 给量化工具看的「真实任务输入样本」，用来估激活范围、决定怎么压精度。  
**不是**再拿来训练网络，也**不是**随便下的网图。

## 对我这次任务

路径：

```text
/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2/
├─ images/
│  ├─ 0/image_0.jpg   # front
│  ├─ 0/image_1.jpg   # wrist
│  ├─ 0/image_2.jpg   # 空图（第 3 物理槽，mask）
│  ├─ 1/...
│  └─ 49/...          # 共 50 组
├─ action/            # state / noise 等 Expert 侧输入
├─ text/
└─ manifest.json
```

来源：训练数据 `/home/rxn/datasets/stack_3blocks_white_blue_black`，按 episode / 阶段均匀抽的，不是只抽静止初始帧。

## 量化时它干什么

以 SigLIP 为例：

```text
校准图（front + wrist）
    ↓
工具链跑一遍浮点/校准前向
    ↓
统计激活分布 → 确定 quant 参数
    ↓
编译成 SigLIP .hbm
```

没有贴近叠积木场景的校准图，HBM 可能「能加载」，但真机分布和训练时差一截，后面 PaliGemma / Expert 更容易一起偏。

## 和几种「图」的区别

| 名字 | 干什么 |
|------|--------|
| 训练视频/帧 | 用来训 π0 |
| **校准图** | 用来 PTQ（训练后量化）估范围 |
| 板上 dump 的特征 | SigLIP HBM 真跑出来的 embedding，给下一段校准用 |
| 评测/真机相机流 | 部署推理时的实时输入 |

## 我给自己定的要求

- 必须是**本任务**的 front / wrist，键名不能偷换成论坛示例的 `side` 就完事。
- 要覆盖接近、抓取、抬起、叠放，避免只校准「手放在桌上不动」。
- 数量：当前 50 组够开跑；若某阶段板上误差大，再针对性加样本重做校准。
- 第三槽空图要保留，和 3 物理槽 / 2 有效相机的编译图一致。

## 相关文件

- 怎么抽的：[`../quantize/COMMANDS.md`](../quantize/COMMANDS.md) §2  
- SigLIP 为什么依赖它：[`siglip-quantize-analysis.md`](./siglip-quantize-analysis.md)
