# 10b · SigLIP dump 流程讲解：每一步在哪台机器、干什么

> 配套操作命令：[10 · 板上 SigLIP dump](./10-board-siglip-dump.md)  
> 概念：[浮点垫脚 vs dump](../notes/bootstrap-vs-dump.md)

本文只讲清楚：**每一步在 PC 还是板子、在做什么、为什么要做**。可复制命令见 [10](./10-board-siglip-dump.md)。

---

## 一句话目标

用 **正品 SigLIP** + **临时 PaliGemma / Expert** 在板上把 `pi0_standalone` 拉起来，把 50 张校准图过一遍板上 SigLIP HBM，导出带真实量化误差的视觉 embedding，再拉回 PC 重编正式 PaliGemma。

```text
校准图 50 张
    ↓  经【板上】SigLIP HBM
视觉 embedding（带真实量化误差）
    ↓  拉回【PC】
重编正式 PaliGemma
```

---

## 谁在哪台机器

| 机器 | 角色 |
|------|------|
| **PC（量化机）** | 编 HBM、改脚本、rsync 传文件、写 JSON、拉回 dump、之后重编 PaliGemma |
| **板子 S600**（`root@192.168.54.29`） | 跑 `pi0_standalone`、跑 dump 收集器、真正执行 SigLIP HBM 推理 |

大文件（HBM、embedding）最终要出现在**板上**；dump 产物最终要回到**PC**。

---

## 为什么必须「三份一起」上板

板上 `pi0_standalone` **必须同时加载 3 个 HBM** 才能启动：

| # | 段 | 本步用哪份 | 在哪编的 | 临时？ |
|---|----|------------|----------|--------|
| 1 | SigLIP | `siglip/pi0_siglip_ptq.hbm` | PC 已编好 | **否**（正品） |
| 2 | PaliGemma | `paligemma_float_bootstrap/` | PC 浮点垫脚 | **是** |
| 3 | Expert | `expert_float_bootstrap/` | PC 浮点垫脚 | **是** |

你真正要采集的是 **① 正品 SigLIP** 的板上输出。  
②③ 只是垫脚：没有它们 engine 起不来，dump 点也触发不了。

---

## 逐步：在哪台机器 · 干什么

### 第 0 步 — PC：设 SSH 变量、测连通

| | |
|--|--|
| **机器** | PC |
| **干什么** | 固定板子地址和密钥，确认能 `ssh` 上去 |
| **不干什么** | 不传模型、不跑推理 |

要点：`S600=root@192.168.54.29`，`VER` 指向板上模型版本根目录。

---

### 第 1 步 — PC → 板：补传临时 PaliGemma / Expert / embedding

| | |
|--|--|
| **机器** | **在 PC 上执行** rsync；**文件落到板子** |
| **干什么** | 把还缺的两段 HBM + `fixed_prompt_embedding.bin` 拷到板上版本目录 |
| **为什么** | SigLIP / 校准图 / 工具仓 / `norm_stats` 以前已拷过；缺后两段就凑不齐 3 份 |

| 传到板上的文件 | 作用 |
|----------------|------|
| `pi0_gemma_llm_ptq.hbm` | 临时 PaliGemma，让 engine 能过第二段 |
| `fixed_prompt_embedding.bin` | 固定任务句的 prompt 向量（板端不跑 tokenizer） |
| `pi0_gemma_expert_ptq.hbm` | 临时 Expert，让整条前向能跑完并触发 dump |

`mkdir` 也是 PC 通过 SSH 让板子建目录。最后 `ls` 校验：**看的是板子上的路径**。

---

### 第 2 步 — PC 改脚本 → 再同步到板

| | |
|--|--|
| **机器** | **改文件在 PC**（`rdk_LeRobot_tools`）；再 rsync **到板子** |
| **干什么** | 让 dump 脚本接受 `camera_keys=["front","wrist"]` |
| **为什么** | 官方脚本写死 `["front","side"]`；你的校准是 `wrist`，不改会 ValueError |

读图其实用 `image_0.jpg` / `image_1.jpg`，键名检查才是卡点。改完必须再 rsync 工具仓，否则板上仍是旧脚本。

---

### 第 3 步 — PC 准备 JSON → 放到板 → 在板（经 SSH）校验

| | |
|--|--|
| **机器** | JSON 可在 **PC** 写好再 scp；`validate_pi0_config.py` **在板子上跑**（检查的是板上文件是否存在） |
| **干什么** | 告诉 standalone：三份 HBM / embedding / norm_stats 路径、监听 `127.0.0.1:30001`、2 相机、6 维等 |
| **不干什么** | validate **只检查配置，不加载模型、不推理** |

期望打印：`PI0_SO100_STANDALONE_CONFIG_OK`。

教程仓备份：[`deploy/pi0_stack3_bootstrap_siglip_dump.json`](../deploy/pi0_stack3_bootstrap_siglip_dump.json)。

---

### 第 4 步 — 板子：两终端配合（核心，真正跑 HBM）

| | |
|--|--|
| **机器** | **全部在板子**（两个 SSH 会话） |
| **干什么** | 用板上 SigLIP HBM 处理 50 张校准图，写出真实视觉 embedding |
| **顺序** | **先开终端 A，再开终端 B** |

#### 两个进程怎么分工

| 终端 | 进程 | 角色 | 干什么 |
|------|------|------|--------|
| **A** | `dump_siglip_hbm_calibration.py` | **TCP Server**（听 30001） | 读校准图与 state → 发给 engine → 等 dump 文件出现 → 拷到输出目录 |
| **B** | `pi0_standalone_sdk102`（经 `run_pi0_standalone_config.sh`） | **TCP Client** | 加载 3×HBM → 连上 A → 跑推理 → 把中间结果写到 dump 目录 |

`PI0_STANDALONE_DUMP_DIR`（B）必须和 `--engine-dump-dir`（A）**同一路径**。

#### 终端 A 每个 sample 在做什么

1. 读板上校准目录里的 `image_0/1.jpg` + `raw_state.npy`  
2. 经 socket 发给 engine  
3. 等 engine 回动作（确认整条链没崩）  
4. 等 `engine_dump_dir/request_XXXXXX/paligemma_vision_fp16.bin` 写完  
5. 拷成 `output_dir/<id>/paligemma_inputs_embeds.bin`

看到 `SIGLIP_CALIBRATION_SERVER_READY` 再开 B；连上后会出现 `S600_ENGINE_CONNECTED`。

#### 终端 B 环境变量在干什么

| 项 | 干什么 |
|----|--------|
| `LD_LIBRARY_PATH` | 找到板上 SDK / DNN 动态库 |
| `HB_DNN_USER_DEFINED_L2M_SIZES` | BPU L2 切分（官方推荐） |
| `PI0_STANDALONE_DUMP_DIR` | 打开 dump 模式，把 SigLIP 等中间结果写到该目录 |
| `run_pi0_standalone_config.sh` | 先 validate，再启动 standalone |
| deployment JSON | 指定加载哪三份 HBM，并连本机 30001（即 A） |

**这一步真正「干活」的是板上正品 SigLIP HBM。**  
临时 PaliGemma / Expert 只是陪跑，让整张计算图能跑通、dump 点能触发。

产出在**板子**上：

```text
/root/calibration_data/pi0_stack3_040000_siglip_hbm_real50/<id>/paligemma_inputs_embeds.bin
```

（约 `1×768×2048` FP16 ≈ 3MB / 条，含 2 真相机 + 1 empty 槽）

---

### 第 5 步 — 板 → PC：拉回 dump

| | |
|--|--|
| **机器** | **在 PC 上执行** rsync；**从板子拉回** |
| **干什么** | 把 50 个 `paligemma_inputs_embeds.bin` 拷到量化机 |
| **然后** | 本机量化正式 PaliGemma 时用 `--vision-embeddings-dir` 指向这份目录 |

含义：后面校准 PaliGemma **不再用 PC 上浮点 SigLIP 假特征**，改用板上真实 HBM 输出。

---

## 总览图（机器视角）

```text
┌──────────────────────────── PC ────────────────────────────┐
│ 0. 设 SSH / 测通                                             │
│ 1. rsync 临时 PaliGemma + Expert + embedding  ─────────┐    │
│ 2. 改 dump 脚本(wrist) → rsync 工具仓           ───────┤    │
│ 3. 写/scp stage JSON                            ───────┤    │
│ 5. rsync 拉回 siglip_hbm_real50  ←──────────────────┐  │    │
│    之后：用该目录重编正式 PaliGemma                     │  │    │
└─────────────────────────────────────────────────────│──│────┘
                                                      │  │
┌──────────────────────────── 板子 S600 ──────────────│──│────┐
│ 1–3. 接收文件 / 存放 JSON / validate（经 SSH）   ←──┘  │    │
│                                                      │    │
│ 4A. dump 脚本：听 30001，发 50 张图，收集 embedding     │    │
│ 4B. standalone：加载 3×HBM，连 A，跑推理并 dump ────────┘    │
│     （真正跑的是正品 SigLIP）                                │
└────────────────────────────────────────────────────────────┘
```

---

## 别混的两件事

| | dump 阶段（本步） | 正式部署（之后） |
|--|------------------|------------------|
| PaliGemma / Expert | **临时**垫脚，能跑即可 | 用真实 dump **重编** |
| 关心什么 | 板上 **SigLIP 输出**是否采全 | 三段都是正品，真机控制 |
| 主要机器 | 板子跑推理；PC 传文件 | PC 再量化；板子再部署 |

---

## 和文档 10 的关系

| 文档 | 内容 |
|------|------|
| **本文 10b** | 讲清楚：PC vs 板、每步在干什么 |
| **[10](./10-board-siglip-dump.md)** | 可复制命令、JSON、校验、勾选 |

实操时打开 [10](./10-board-siglip-dump.md) 敲命令；卡壳时回本文看「这一步本该在哪台机器做什么」。
