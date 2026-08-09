# 踩坑记录

## 模板

### YYYY-MM-DD — 标题

- **现象：**
- **环境：**
- **原因：**
- **处理：**
- **是否量化相关：** 是 / 否

---

## 已知 / 已踩

### 2026-08-07 — checkpoint 只有半截权重

- **现象：** `/home/rxn/models/pi0_stack_white_blue_black_040000` 里只有 `config.json` 和 `.model.safetensors.4Z7Iqx`（约 53MB），没有完整 `model.safetensors`。
- **环境：** 训练机 `rxn`
- **原因：** 权重仍在写入/下载/复制未完成（临时文件后缀）。
- **处理：** 等落盘完成或重新导出 checkpoint；完整 π0 权重通常是数 GB。未完成前不做 BF16，更不要量化。
- **是否量化相关：** 否（阻塞前置）

### 2026-08-07 — 相机名与官方示例不一致

- **现象：** 官方教程命令大量使用 `front` + `side`。
- **环境：** 数据集 `stack_3blocks_white_blue_black`
- **原因：** 我采集用的是 `front` + `wrist`。
- **处理：** 校准脚本 `--camera-keys front wrist`；部署 JSON / 第二路相机参数全部按 wrist 理解。不要直接复用官方双相机成品 HBM。
- **是否量化相关：** 是（schema / position）

### 2026-08-07 — relative actions vs 板上绝对角

- **现象：** 训练 `config.json` 含 `use_relative_actions: true`。
- **环境：** π0 post-training
- **原因：** 论坛 SO100 示例偏绝对关节角控制；若板上 runtime 按绝对角写，语义不一致会整体偏。
- **处理：** BF16 基线阶段先确认相对动作解码正确；板上部署前核对 `rdk_LeRobot_tools` 是否支持同一套 relative 语义，必要时在控制环换算。
- **是否量化相关：** 间接（前后处理 / 控制）

### 2026-08-07 — empty camera 槽位数

- **现象：** 训练 `empty_cameras=0`；官方 S600 图常见 3 物理槽（2 真 + 1 mask）。
- **环境：** 训练 config vs 编译 ABI
- **原因：** HBM 固定 shape / mask / position；JSON 改不了已编译 ABI。
- **处理：** 训练 schema 与编译图对齐后再量化；相机数或槽位变了就整条重做校准与三份 HBM。
- **是否量化相关：** 是

---

### 2026-08-07 — 抽校准集视频时间戳容差过严

- **现象：** `FrameTimestampError`，`0.0006 > tolerance_s=0.0001`
- **环境：** `prepare_pi0_calibration_v5_2cam.py` + 本数据集 pyav 解码
- **原因：** 数据集默认 `tolerance_s=1e-4` 过严
- **处理：** 脚本增加 `--tolerance-s 0.04`，并对坏帧尝试邻近 index；校准输出在 `.../pi0_stack3_040000_real50_v2`
- **是否量化相关：** 否（校准前置）

### 2026-08-08 — 量化环境必须单独用 Python 3.10

- **现象：** `hbdk4` / `leap_llm` wheel 是 `cp310`，无法装进 `lerobot_alohamini`（3.12）。
- **环境：** 训练机
- **原因：** SDK `oellm_build` 只提供 py310 包。
- **处理：** 新建 conda `oellm_s600`（Python 3.10），详见 `quantize/ENV.md`。
- **是否量化相关：** 是（环境）

### 2026-08-08 — USB-A 当调试口 / Type-C 插错

- **现象：** 电脑不出 CH340，或串口完全无回显。
- **环境：** S600 整机
- **原因：** USB-A 是 Host；调试要用板上 **Type-C 闪连口**（两颗 CH340）。J16 是 CAN 12 针，不是 Type-C。
- **处理：** 改插调试 Type-C；详见 `docs/06-board-access.md`。
- **是否量化相关：** 否（接入）

### 2026-08-08 — brltty 抢走 ttyUSB1

- **现象：** `ttyUSB1` 出现后几秒消失；`minicom: 没有那个文件或目录`；dmesg 有 `brltty sets config #1`。
- **环境：** Ubuntu PC
- **原因：** 盲文服务 `brltty` 抢 CH340。
- **处理：** `systemctl mask brltty brltty-udev` 或 `apt remove brltty`。
- **是否量化相关：** 否（接入）

### 2026-08-08 — minicom 硬件流控默认开着

- **现象：** 921600 开着口但只有乱码/无 `login:`。
- **环境：** minicom 2.8
- **原因：** 串口设置里「硬件流控制=是」。
- **处理：** `Ctrl-A O` → 串口设置 → `F` 改为否，保存 dfl。
- **是否量化相关：** 否（接入）

### 2026-08-08 — 局域网扫到的 SSH 不是本板

- **现象：** `192.168.54.5` / `.13` 开 22 端口，但 `sunrise`/`root` 默认密码全拒。
- **环境：** 同 WiFi
- **原因：** 那些是别的机器或密码已改；本板实际在 `wlan0` = **`192.168.54.29`**，且 `eth0..3` 全 DOWN。
- **处理：** 串口 `ip -br a` 再 SSH；不要盲试默认密码。
- **是否量化相关：** 否（接入）

### 2026-08-08 — dump 缺 PaliGemma/Expert 无法起 engine

- **现象：** 只有 SigLIP HBM；`validate_pi0_config.py` 要求三段路径 + `fixed_prompt_embedding.bin`。
- **环境：** 板端 standalone
- **原因：** cascade 的第一次 dump 仍要完整 engine 才能跑；SDK 自带 hammer-beat Pi0 HBM 与 leap_llm 图不兼容。
- **处理：** 本机先 bootstrap 浮点中间量的 PaliGemma（+ embedding）/Expert，再 dump 真实 SigLIP；见 `docs/07` / `08` / `09`。
- **是否量化相关：** 是

### 2026-08-08 — PaliGemma bootstrap：transformers 5.x / 无 tokenizer

- **现象：** `GemmaConfig` 无 `rope_theta`；`AutoTokenizer` 报 LeRobot `config.json` 无 `model_type`。
- **环境：** `oellm_s600`
- **原因：** transformers 升到 5.14；ckpt 目录不是 HF 格式。
- **处理：** `transformers==4.57.6`；`export PI0_TOKENIZER_DIR=/home/rxn/models/paligemma-3b-pt-224`（脚本读该环境变量）。详见 `docs/08-paligemma-float-bootstrap.md`。
- **是否量化相关：** 是

### 2026-08-09 — Expert 浮点垫脚编译完成

- **现象：** 需要第三段 HBM 才能起 `pi0_standalone`。
- **环境：** `oellm_s600`，未传 `--paligemma-kv-dir`
- **处理：** `quantize_expert_real_calib.py` → `expert_float_bootstrap/pi0_gemma_expert_ptq.hbm`（~329MB，`float_paligemma`）；详见 `docs/09-expert-float-bootstrap.md`。
- **是否量化相关：** 是

## 待填

### YYYY-MM-DD — （标题）

- **现象：**
- **环境：**
- **原因：**
- **处理：**
- **是否量化相关：**
