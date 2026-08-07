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

## 待填（上板后追加）

### YYYY-MM-DD — （标题）

- **现象：**
- **环境：**
- **原因：**
- **处理：**
- **是否量化相关：**
