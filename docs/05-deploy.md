# 05 · RDK S600 真机部署

> 状态：离线 smoke 已过；真机步骤见 **[16 真机收尾](./16-live-robot.md)**。

## 本章目标

板上加载三段 HBM，接上 `front`/`wrist` 和 SO-101，跑通同步推理闭环。

## 上板前检查

- [ ] HBM、`fixed_prompt_embedding.bin`、`norm_stats` 已拷到板端版本目录  
- [ ] deployment JSON + manifest 的 SHA256 与文件一致  
- [ ] `rdk_LeRobot_tools/models/pi0` runtime 用 SDK 1.0.2 编过  
- [ ] 臂端口、两路相机、标定文件正确  
- [ ] 先离线 smoke：双图 + state → 输出 shape `[50, 6]`  
- [ ] 再只读真机，最后才发力矩  

## Artifact 布局（建议）

```text
/root/pi0_models/versions/<BUNDLE_NAME>/
  siglip/pi0_siglip_ptq.hbm
  paligemma/pi0_gemma_llm_ptq.hbm
  paligemma/fixed_prompt_embedding.bin
  expert/pi0_gemma_expert_ptq.hbm
```

`norm_stats` 必须来自**这次训练对应的数据集**，换数据集就换 stats。

## 启动

模板脚本：[`../deploy/run_on_s600.sh`](../deploy/run_on_s600.sh)

```bash
# 板端
export RDK_TOOLS_PI0=/root/rdk_LeRobot_tools/models/pi0
export LD_LIBRARY_PATH=/root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib:$LD_LIBRARY_PATH
export HB_DNN_USER_DEFINED_L2M_SIZES=6:6:6:6

# 校验配置
/home/sunrise/lerobot/.venv/bin/python validate_pi0_config.py \
  configs/deployments/<YOUR_CONFIG>.json

# 离线 smoke
/home/sunrise/lerobot/.venv/bin/python -u pi0_standalone_offline.py \
  --config configs/deployments/<YOUR_CONFIG>.json \
  --front /path/to/front.jpg \
  --side /path/to/wrist.jpg \
  --state 0 0 0 0 0 0 \
  --output-dir diagnostics/offline_smoke_$(date +%Y%m%d_%H%M%S)

# 真机（官方入口名以仓内为准）
bash /path/to/lerobot-pi0-rdk-s600-deploy/deploy/run_on_s600.sh
```

说明：官方参数/文件名里可能仍出现 `side`，对我来说第二路就是 **wrist** 图像。

跑通后把**真实启动命令、配置文件路径、相机设备号**写回本章。

## 对比实验（建议）

| 对比 | 观察 |
|------|------|
| 服务器 BF16 vs 板端 HBM | 成功率、落点是否偏、夹爪是否抖 |
| 同步策略是否与训练一致 | chunk=50、是否整 chunk 执行完再重规划 |
| relative vs absolute | 若 BF16 相对正常而板端偏，优先查动作语义 |

差的时候按这个顺序查：输入预处理 → position/mask → 三段 HBM 是否配错 → norm_stats → 控制与标定。

## 本章完成标准

- [ ] 真机任务至少稳定跑通一次并留视频  
- [ ] 在 [踩坑本](../notes/pitfalls.md) 写下和官方流程的差异  

## 做完之后

回 [README 进度表](../README.md) 把勾打上；以后换数据/换任务，从第 02 章重新开一节记录即可。
