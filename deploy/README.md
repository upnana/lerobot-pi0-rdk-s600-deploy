# deploy/

RDK S600 真机推理：加载三段 HBM，接相机与 SO100，跑同步控制闭环。

## 前置条件

- [ ] `quantize/` 三段 HBM 与配套 stats 已拷到板端
- [ ] 板端 runtime / 依赖按 `rdk_LeRobot_tools` 装好
- [ ] 机械臂端口、相机、标定文件配置正确

## 建议流程

1. 先只读推理（不发动作），确认输入 shape / 输出 `[50, 6]` 正常
2. 再开同步真机控制（教程中的 `run_live_sync.sh` 一类入口）
3. 对比服务器 BF16 与板端 HBM 行为；差则回到量化/前后处理排查

## 本目录放什么

- 板端启动脚本副本或软链说明（`run_on_s600.sh`）
- 相机 / 机器人配置备忘
- 与官方 `models/pi0/` runtime 的路径对照

## 参考

- 论坛第四章「部署实操」
- `rdk_LeRobot_tools/models/pi0/`（如 `./run_live_sync.sh`）
