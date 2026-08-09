# deploy/

RDK S600 真机推理：加载三段 HBM，接 SO-101 与 `front`/`wrist`。

## 上板顺序

1. 拷贝 HBM + prompt embedding + norm_stats 到版本目录（不要覆盖旧 bundle）
2. 写 / 更新 deployment JSON 与 SHA256
3. `validate_pi0_config.py`
4. `pi0_standalone_offline.py` smoke（期望 `[50,6]`）
5. 只读真机 → 再执行动作
6. `./run_on_s600.sh` 或官方 `run_live_sync.sh`

## 脚本 / 配置

- [`run_on_s600.sh`](./run_on_s600.sh)：板端启动模板
- [`pi0_stack3_bootstrap_siglip_dump.json`](./pi0_stack3_bootstrap_siglip_dump.json)：临时三份 HBM 起 engine，专用于板上 SigLIP dump（见 [docs/10](../docs/10-board-siglip-dump.md)）

## 参考

- 板上 dump 操作：[docs/10-board-siglip-dump.md](../docs/10-board-siglip-dump.md)
- 正文：[docs/05-deploy.md](../docs/05-deploy.md)
- 官方：`rdk_LeRobot_tools/models/pi0/`
