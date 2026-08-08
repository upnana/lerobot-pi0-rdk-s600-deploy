# 06 · S600 板端接入（串口 + SSH）详细步骤

> 状态：**已走通**（2026-08-08）  
> 目标：第一次连上板子，拿到 IP，打通 SSH，为 SigLIP 板上 dump 做准备。

本机 PC：`192.168.54.7`（WiFi）  
板子最终 IP：`192.168.54.29`（`wlan0`）  
串口登录：`root` / `root`（也可用 `sunrise` / `sunrise`）

---

## 0. 先分清口：调试 Type-C ≠ CAN，也不是 USB-A Host

| 你看到的 | 实际是什么 | 干什么 |
|----------|------------|--------|
| **USB Type-C（椭圆 C 口）** | 烧录 + 调试口（手册里常叫「闪连」；S600 位号多为 **J4**） | 插电脑 → 出 **2 个 CH340** 串口 |
| **J16** | **12 针 CAN 座**，不是 Type-C | MCU CAN，Type-C 线插不进去 |
| **USB-A** | Host 口 | 接 U 盘/相机/键鼠，**不能当调试串口** |
| **供电口 J1** | DC 电源 | **整板上电靠它**，不要指望 Type-C 给整板供电 |

手册里偶发写成 `USB Type-C(J16)`，那是编号混用；**以接口形状为准**：能插 Type-C 且出现两个 CH340 = 调试口。

Type-C 上有 **两颗 CH340**：

- `/dev/ttyUSB0` ↔ 一个域（Main 或 MCU）
- `/dev/ttyUSB1` ↔ 另一个域

我们要的是 **Main 域 Linux 控制台**（会出现 `Ubuntu ... login:`）。

---

## 1. 上电：先看灯，再谈串口

### 1.1 电源

1. 用套件适配器接到 **J1**（正规供电口）。
2. **不要**只用 PC 的 USB/Type-C 给整板供电。
3. 找到丝印 **`SW3`**（拨动开关，常在供电口附近、网口下方白板边缘）。
4. 拨到标 **`ON`** 的一侧。

### 1.2 指示灯（整机外壳可能挡住）

| 灯 | 名称 | 含义 |
|----|------|------|
| D60 | Power | 常亮 = 有电 |
| D59 | System | 闪烁 = Main 系统在跑 |
| D61 | Flash | 亮 = DFU 烧录模式 |

整机金属盖会挡住 D59/D60/D61；从外面「看不见灯」≠ 没电。  
可看：网口里是否有链路灯、侧板缝隙是否有绿灯。

本次实操：Power 亮、网口侧有绿灯 → 板子有电。

### 1.3 烧录开关 SW2

日常启动应在 **正常启动**（非 DFU）。SW2 是跳帽，别和 SW3 搞混。

---

## 2. 串口：minicom 逐步设置

### 2.1 确认设备节点

```bash
ls -l /dev/ttyUSB* /dev/serial/by-id/
lsusb | grep -i 7523
```

期望：两个 `1a86:7523`（CH340），以及 `/dev/ttyUSB0`、`/dev/ttyUSB1`。

### 2.2 必杀：停掉 brltty（否则 ttyUSB1 几秒就消失）

本机 Ubuntu 上 **`brltty`** 会抢第二个 CH340，内核日志类似：

```text
usbfs: interface 0 claimed by ch341 while 'brltty' sets config #1
ch341-uart ttyUSB1: ... disconnected from ttyUSB1
```

处理（做一次即可）：

```bash
sudo systemctl stop brltty brltty-udev
sudo systemctl disable brltty brltty-udev
sudo systemctl mask brltty brltty-udev
# 或：sudo apt remove -y brltty
```

若 `ttyUSB1` 仍缺，可再绑驱动：

```bash
echo '1-5.1.2:1.0' | sudo tee /sys/bus/usb/drivers/ch341/bind
ls -l /dev/ttyUSB*
```

（USB 拓扑号以你机器 `sysfs` 为准；重新插拔后路径可能变。）

### 2.3 打开 minicom

官方参数：**921600 8N1，无流控**。

```bash
minicom -D /dev/ttyUSB0 -b 921600
# 若无 Ubuntu 登录提示，换：
# minicom -D /dev/ttyUSB1 -b 921600
```

进入后：

1. `Ctrl-A` → `O` → **串口设置**
2. 按 **`F`**：硬件流控制 = **否**（非常关键，默认常常是「是」）
3. 软件流控制保持 **否**
4. 建议再选 **保存设置为 dfl**
5. 离开菜单后多按几次 Enter

状态栏显示「脱机」可以忽略：CH340 通常没有 DCD，minicom 几乎总显示 Offline。

### 2.4 复位抓日志（判断哪个口是 Main）

开着 minicom，按板上 **K1 RST**，或重新拨 SW3 上电。

- 刷出 U-Boot / Linux / `Ubuntu ... login:` → **Main 域**（就是这个口）
- 几乎没字或只有乱码 → 换另一个 `ttyUSB*`

本次实操：Main 控制台提示类似：

```text
Ubuntu 24.04.3 LTS ubuntu ttyS0
ubuntu login:
```

### 2.5 登录

```text
login: root
password: root
```

成功后应看到 `root@ubuntu:~#`。

---

## 3. 查 IP（串口里）

```bash
ip -br a
hostname
uname -a
```

本次结果摘要：

```text
eth0..eth3   DOWN          # 网线插着也没用，口没起来
wlan0        UP            192.168.54.29/23
```

所以局域网 SSH 用 **WiFi IP `192.168.54.29`**，不要死盯之前扫到的 `.5` / `.13`（那些机器开了 SSH 但默认 `sunrise/root` 密码不对，不是这台板或密码已改）。

静态直连备选（未使用）：手册写 eth1 默认 `192.168.127.10`；本次 `eth1` 是 DOWN。

---

## 4. SSH：密码登录 + 免密公钥

### 4.1 本机先试密码

```bash
ssh root@192.168.54.29
# 密码 root
```

### 4.2 安装本机公钥（推荐）

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.54.29
```

若提示 keys already exist 仍连不上，在串口检查权限：

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R root:root ~/.ssh
```

脚本/自动化建议显式指定密钥（避免 agent 干扰）：

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29 'hostname; ip -br a'
```

本次本机公钥：

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUKyIf1kt3ucaGycd9JOZLOU6XeC3oQ0eeFUh6gaod6 rxn@wenxingnan
```

---

## 5. 验证板端软件栈是否在

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@192.168.54.29 '
  uname -r
  ls /usr/hobot /opt/hobot | head
  ls /root/D-Robotics_LLM_S600_1.0.2_SDK/oellm_runtime/lib/libdnn.so
  df -h /
'
```

本次：内核 `6.1.158-rt58-DR-...`，已有 `/usr/hobot`、`/opt/hobot`，SDK runtime 在 `/root/D-Robotics_LLM_S600_1.0.2_SDK`，根分区约 45G（可用约 9G 级，够拷 SigLIP HBM）。

---

## 6. 常见失败对照

| 现象 | 原因 | 处理 |
|------|------|------|
| minicom 空白 / 只有 `- + \|` | 口不对、流控开着、或未复位 | 关硬件流控；换 `ttyUSB0/1`；RST 抓日志 |
| `ttyUSB1` 出现又消失 | `brltty` 抢口 | mask/remove `brltty` |
| 全板无灯 | 没上电 / SW3 OFF / 电源不对 | 查 J1 + SW3 ON |
| 扫到 `.5`/`.13` 密码全拒 | 不是这台板 | 串口查真实 IP |
| 网线插着仍无 eth IP | `eth*` DOWN | 用 `wlan0` 或起来网口 |
| SSH Permission denied（有密钥） | 权限/`IdentitiesOnly` | 修 `~/.ssh`；显式 `-i` |
| Type-C 插 USB-A 转接头无串口 | 插错成 Host 口 | 改插调试 Type-C |

---

## 7. 下一步

板子能 SSH 之后，继续：[07 板端准备与 SigLIP dump 前置](./07-board-prepare-siglip-dump.md)。
