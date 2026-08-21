# deploy/

RDK S600 真机推理：加载三段 HBM，接 SO-101 与 `front`/`wrist`。

## 上板顺序

1. 拷贝 HBM + prompt embedding + norm_stats 到版本目录（不要覆盖旧 bundle）
2. 写 / 更新 deployment JSON 与 SHA256
3. `validate_pi0_config.py`
4. `pi0_standalone_offline.py` smoke（期望 `[50,6]`）
5. 只读真机 → 再执行动作
6. [`run_live_stack3_readonly.sh`](./run_live_stack3_readonly.sh) / [`run_live_stack3.sh`](./run_live_stack3.sh)

## 脚本 / 配置

- [`run_on_s600.sh`](./run_on_s600.sh)：板端启动模板
- [`pi0_stack3_bootstrap_siglip_dump.json`](./pi0_stack3_bootstrap_siglip_dump.json)：SigLIP dump 用
- [`pi0_stack3_formal_paligemma_kv_dump.json`](./pi0_stack3_formal_paligemma_kv_dump.json)：KV dump 用
- [`pi0_stack3_final.json`](./pi0_stack3_final.json)：三段正式 HBM
- [`run_live_stack3_readonly.sh`](./run_live_stack3_readonly.sh) / [`run_live_stack3.sh`](./run_live_stack3.sh)：真机只读 / 执行（`--relative-actions`、`--record-video`）
- [`replay/`](./replay/)：dataset teleop 回放 + 录像（不是 π0 inference）

## 参考

- 真机实验总结：[docs/17-live-experiments-summary.md](../docs/17-live-experiments-summary.md)
- 真机收尾：[docs/16-live-robot.md](../docs/16-live-robot.md)
- 板上 dump：[docs/10-board-siglip-dump.md](../docs/10-board-siglip-dump.md)
- 正文：[docs/05-deploy.md](../docs/05-deploy.md)
- 官方：`rdk_LeRobot_tools/models/pi0/`
