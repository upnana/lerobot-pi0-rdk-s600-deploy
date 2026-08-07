# 05 · RDK S600 真机部署

> 状态：待填。

## 本章目标

板上加载三段 HBM，接上相机和机械臂，跑通同步推理闭环。

## 上板前检查

- [ ] HBM 与校准/stats 已拷到板端约定目录  
- [ ] `rdk_LeRobot_tools/models/pi0` runtime 可用  
- [ ] 臂端口、相机、标定文件正确  
- [ ] 先只读推理（不发动作），确认输出 shape（例如 `[50, 6]`）  

## 启动

模板脚本：[`../deploy/run_on_s600.sh`](../deploy/run_on_s600.sh)

```bash
# 在板端
export RDK_TOOLS_PI0=/path/to/rdk_LeRobot_tools/models/pi0
bash run_on_s600.sh
```

跑通后把**真实启动命令、配置文件路径、相机名**写回这里。

## 对比实验（建议）

| 对比 | 观察 |
|------|------|
| 服务器 BF16 vs 板端 HBM | 成功率、轨迹是否偏、夹爪是否抖 |
| 同步策略是否与训练一致 | chunk 长度、是否每 chunk 重规划 |

差的时候按这个顺序查：输入预处理 → position/mask → 三段 HBM 是否配错 → 控制与标定。

## 本章完成标准

- [ ] 真机任务至少稳定跑通一次并留视频  
- [ ] 在 [踩坑本](../notes/pitfalls.md) 写下和官方流程的差异  

## 做完之后

回 [README 进度表](../README.md) 把勾打上；以后换数据/换任务，从第 02 章重新开分支记录即可。
