# deploy/

RDK S600 真机推理：加载三段 HBM，接 SO-101 与 `front`/`wrist`。

## 上板顺序

1. 拷贝 HBM + prompt embedding + norm_stats 到版本目录（不要覆盖旧 bundle）
2. 写 / 更新 deployment JSON 与 SHA256
3. `validate_pi0_config.py`
4. `pi0_standalone_offline.py` smoke（期望 `[50,6]`）
5. 只读真机 → 再执行动作
6. `./run_on_s600.sh` 或官方 `run_live_sync.sh`

## 脚本

- [`run_on_s600.sh`](./run_on_s600.sh)：板端启动模板

## 参考

- 正文：[docs/05-deploy.md](../docs/05-deploy.md)
- 官方：`rdk_LeRobot_tools/models/pi0/`
