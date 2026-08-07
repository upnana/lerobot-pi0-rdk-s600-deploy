#!/usr/bin/env bash
# S600 真机启动模板。默认假定板端已按 rdk_LeRobot_tools 放好 models/pi0。
set -euo pipefail

RDK_TOOLS_PI0="${RDK_TOOLS_PI0:-/root/rdk_LeRobot_tools/models/pi0}"

cd "${RDK_TOOLS_PI0}"

# 先确认脚本存在再跑；实际入口名以官方仓为准
if [[ -x ./run_live_sync.sh ]]; then
  ./run_live_sync.sh
else
  echo "未找到 ${RDK_TOOLS_PI0}/run_live_sync.sh"
  echo "请设置 RDK_TOOLS_PI0，或对照论坛附录 A.7 更新本脚本。"
  exit 1
fi
