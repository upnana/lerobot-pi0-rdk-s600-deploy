# 我怎么理解 SigLIP 量化（叠积木 / front+wrist）

> 写于量化实跑前。参考[地瓜论坛 π0×S600 教程](https://forum.d-robotics.cc/t/topic/35528)和 `rdk_LeRobot_tools` 的 `quantize_siglip_real_calib.py`，用**我自己的任务**把这一段想清楚。  
> 任务：白→蓝→黑叠积木；相机：`front` + `wrist`；ckpt：`pi0_stack_white_blue_black_040000`。

## 1. 先摆正位置：SigLIP 不是「整网压缩」

板上 π0 被拆成三段，不是论文里两个逻辑模块的简单一一对应，而是为了编译和调度：

```text
front / wrist 图像
      ↓
  SigLIP HBM          ← 我现在要量化的这一段
      ↓ 每路 256 个视觉 token
  PaliGemma HBM
      ↓ 36 组 prefix KV
  Expert HBM × 10
      ↓
  [50, 6] 关节动作
```

对我来说，SigLIP 只干一件事：**把相机画面变成后面还能用的视觉表示**。  
叠积木成败高度依赖「白色块在画面哪里、夹爪相对它偏了多少」。所以这一段量化如果伤到**空间位置**，后面 Expert 再准也救不回来——表现往往是稳定偏一点，而不是直接崩。

## 2. 为什么我特别怕 position embedding 被量化坏

读论文/教程时最有用的一句区分：

| 部分 | 它告诉模型什么 | 量化太狠时我预期看到什么 |
|------|----------------|--------------------------|
| patch embedding | 「这块长什么样」 | 纹理/颜色略糊，有时还能抓 |
| **position embedding** | 「这块在画面哪里」 | **落点系统性偏前/偏后/偏一侧** |

所以我准备采用的配置（和论坛最终方案一致）：

- `--patch-embedding-mode quant8`
- **`--position-embedding-mode fp16`**（这里不省）
- attention / MLP / projector：`dynamic`
- `--march nash-p`，`--valid-camera-slots 2`

一句话：**能省的省在 patch，不能省的留给 position。**

## 3. 「校准」对我意味着什么

量化不是只把权重砍成 int8。工具链要用一批**真实输入**跑一遍，估计激活范围。  
我已经抽好的校准集：

```text
/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
```

对我任务的要求是：

- 必须用**叠积木过程里的真图**，不能用无关图或随机噪声。
- 要覆盖接近、抓取、抬起、叠放；只抽静止初始帧，动作阶段的激活可能对不上。
- 相机键是 **`front` + `wrist`**，不是论坛示例里的 `side`；第三槽仍是 mask 空图（物理 3 槽、有效 2 路）。

校准集抽坏了，SigLIP HBM「能编过」也不代表叠积木时分布对。

## 4. 编出 HBM 之后，我还不能立刻去量化 PaliGemma

这是我一开始最容易漏的一点。

错误直觉：

```text
校准图 → float SigLIP → 用 float 特征校准 PaliGemma
部署时：校准图 → SigLIP HBM → PaliGemma
```

两套输入分布不一样。上游量化误差在部署时真实存在，校准时却没见过，误差会级联：

```text
位置略偏 → 视觉 token 偏 → PaliGemma KV 偏 → Expert 关节偏 → 积木放歪 / 夹空
```

我认的正确顺序：

```text
1. 本机 oellm_s600：量化编译 SigLIP → .hbm
2. S600 板上：用同一批校准图跑 SigLIP HBM，dump 真实视觉特征
3. 再拿这些「带板端误差的特征」去校准 / 量化 PaliGemma
```

所以 SigLIP 量化的交付物不止是一个文件，而是：

- `pi0_siglip_ptq.hbm`（或脚本实际文件名）
- **板上 dump 出来的 vision embedding 目录**（给下一段用）

## 5. 和我这份 ckpt / 数据相关的注意点

- 训练开了 `use_relative_actions`；SigLIP 本身不直接出关节角，但整链语义要在 BF16 基线里先确认，别把相对动作问题和量化混在一起。
- `empty_cameras=0` 与官方常见「2 真 + 1 mask」编译图是否完全一致，要以实际 export 脚本为准；我这边抽校准时按 **3 槽 / 2 有效** 做的。
- HBM **固定** shape、槽位、mask；编完不能靠改 JSON 把相机数改掉。换相机 schema = 重做校准和三份 HBM。

## 6. 我准备怎么跑（命令骨架）

环境：`conda activate oellm_s600`（见 [`../quantize/ENV.md`](../quantize/ENV.md)）

```bash
export PI0_VALID_CAMERA_SLOTS=2
export RDK_TOOLS=/home/rxn/rdk_LeRobot_tools
export CHECKPOINT=/home/rxn/models/pi0_stack_white_blue_black_040000
export CALIB_DIR=/home/rxn/gemma/calibration_data/pi0_stack3_040000_real50_v2
export QUANT_OUT=/home/rxn/gemma/output/pi0_stack3_040000_sdk102

cd "$RDK_TOOLS"
python3 models/pi0/tools/quantize_siglip_real_calib.py \
  --model-dir "$CHECKPOINT" \
  --calibration-dir "$CALIB_DIR" \
  --output-dir "$QUANT_OUT/siglip" \
  --device cuda:0 \
  --vision-tokens-num 256 \
  --valid-camera-slots 2 \
  --max-samples 50 \
  --jobs 20 \
  --march nash-p \
  --max-l2m-size 0 \
  --patch-embedding-mode quant8 \
  --position-embedding-mode fp16 \
  --attention-linear-mode dynamic \
  --mlp-linear-mode dynamic \
  --attention-matmul-mode dynamic \
  --projector-linear-mode dynamic \
  --layernorm-mode standard
```

更完整的级联步骤见 [`../quantize/COMMANDS.md`](../quantize/COMMANDS.md)。

## 7. 我用来判断「这一段算做完」的标准

- [ ] `$QUANT_OUT/siglip/` 下有可用的 `.hbm`
- [ ] 精度配置确认：position 是 fp16，不是误用 quant8
- [ ] 有效相机槽 = 2，且和校准目录里的 `front`/`wrist` 一致
- [ ] 板上 dump 过真实 SigLIP 输出，目录已拉回训练机
- [ ] 记下 SHA256，后面 deployment manifest 要绑死

在此之前，我不会宣称「量化通了」——最多只能说「SigLIP 编译产物出来了」。

## 8. 一句话收束

对我这个叠积木任务，**SigLIP 量化 = 用真实 front/wrist 图，把视觉编码器编成保位置信息的板端 HBM，并产出带真实量化误差的视觉特征，供 PaliGemma 做链路感知校准。**  
省的是算力和带宽，不能省的是「积木在哪」。
