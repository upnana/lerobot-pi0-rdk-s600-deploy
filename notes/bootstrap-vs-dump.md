# 为什么要先「浮点垫脚」才能 dump？

> 一句话：板上 dump 和编正式 PaliGemma **互相等对方**，所以中间要插一步临时 HBM。

## 死结长什么样

```text
要 dump（板上真跑 SigLIP HBM，导出视觉特征）
  → 得先启动 engine（pi0_standalone）
  → engine 启动要 3 段 HBM：SigLIP + PaliGemma + Expert

要编「正式」PaliGemma
  → 校准输入最好是：板上 dump 出来的 SigLIP HBM 输出

两边互相等 → 走不动
```

用现成工具（`dump_siglip_hbm_calibration.py` + `pi0_standalone`）时：

- **不能**只挂 SigLIP 一个 HBM 就 dump（校验/引擎按整条 π0 起）
- SDK 自带的别的 Pi0 demo HBM 也**不能**直接塞进我们的 standalone（图不一致）

## 「浮点 SigLIP 输出垫一脚」是什么意思

编 PaliGemma 时，编译器要看一批**视觉特征**来估数量化范围。特征从哪来有两条路：

| 路 | 视觉特征从哪来 | 用途 |
|----|----------------|------|
| **正路** | 板上 SigLIP **HBM** dump 的文件 | 编正式、更准的 PaliGemma |
| **垫脚** | 电脑 GPU 上 **浮点 SigLIP** 当场算出同形状特征 | 先编出**临时** PaliGemma `.hbm`，打破死结 |

注意：

- 浮点**不是**在板上代替 HBM 跑
- 浮点只在**电脑量化校准**时当输入
- 板上跑的始终是 `.hbm`

Expert 同理：理想用板上 PaliGemma 的真实 KV dump；第一次也可以先浮点中间量垫一脚。

## 实际顺序（打破死结）

```text
① 已有：SigLIP HBM（本机已编好）
② 本机 oellm_s600：用浮点 SigLIP 输出 → 编临时 PaliGemma（+ fixed_prompt_embedding）
③ 本机：再垫一脚编临时 Expert（或等价能过 validate 的占位）
④ 三份 HBM 拷上板 → 启动 engine
⑤ dump 真实 SigLIP HBM 输出 → 拉回本机
⑥ 用 dump → 重编正式 PaliGemma
⑦ dump KV → 重编正式 Expert
⑧ 最终三份上板部署
```

②③ 叫 bootstrap / 垫脚；⑥⑦ 才是级联正路。

## 和「只跑 SigLIP」的关系

- **物理上**可以写个只跑 SigLIP 的小程序
- **本教程跟的官方 cascade 工具**不支持「只挂一段就 dump」
- 所以选垫脚，而不是另写 runner

## 相关文档

- 板端接入：[06-board-access.md](../docs/06-board-access.md)
- 板端已拷文件 / standalone：[07-board-prepare-siglip-dump.md](../docs/07-board-prepare-siglip-dump.md)
- 量化命令：[../quantize/COMMANDS.md](../quantize/COMMANDS.md)
