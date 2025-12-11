#!/bin/bash

# ==========================================
# 脚本名称: XanMod Kernel + BBRv3 一键安装脚本
# 适用系统: Debian / Ubuntu
# 功能: 升级内核并开启 BBRv3 及网络优化
# ==========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为 Root 用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}错误: 必须使用 root 用户运行此脚本！${PLAIN}" 
   exit 1
fi

echo -e "${YELLOW}正在检查系统环境...${PLAIN}"

# 检查是否为 Debian/Ubuntu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
        echo -e "${RED}错误: 本脚本仅支持 Debian 或 Ubuntu 系统。${PLAIN}"
        exit 1
    fi
else
    echo -e "${RED}错误: 无法检测操作系统版本。${PLAIN}"
    exit 1
fi

echo -e "${GREEN}系统检测通过: $PRETTY_NAME${PLAIN}"
echo -e "${YELLOW}注意: 安装 BBRv3 需要更换内核(XanMod)，脚本运行结束后需要重启服务器。${PLAIN}"
read -p "按回车键继续，或按 Ctrl+C 取消..."

# 1. 更新系统并安装必要组件
echo -e "${GREEN}[1/4] 更新系统组件...${PLAIN}"
apt-get update -y
apt-get install -y wget gnupg lsb-release ca-certificates

# 2. 添加 XanMod 源并安装内核
echo -e "${GREEN}[2/4] 添加 XanMod 内核源...${PLAIN}"
# 注册 GPG Key
wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

# 添加源列表
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

# 更新源并安装最新稳定版 XanMod 内核
echo -e "${GREEN}[3/4] 正在安装 XanMod Kernel (这可能需要几分钟)...${PLAIN}"
apt-get update -y
apt-get install -y linux-xanmod-x64v3

# 3. 配置 BBRv3 和 VPN 网络优化参数
echo -e "${GREEN}[4/4] 写入网络优化配置...${PLAIN}"

cat > /etc/sysctl.d/99-xanmod-bbr.conf << EOF
# --- BBRv3 & Network Optimization ---

# 开启 BBR 拥塞控制 (XanMod 内核中，设置 bbr 即自动启用 bbrv3 逻辑)
net.core.default_qdisc = fq_pie
net.ipv4.tcp_congestion_control = bbr

# TCP 窗口优化 (针对大带宽 VPS 优化)
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432

# 开启 IP 转发 (VPN 必备)
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# 增加连接追踪上限 (防止大量连接导致丢包)
net.netfilter.nf_conntrack_max = 1048576

# 优化 TCP 连接
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_mtu_probing = 1

EOF

# 应用配置
sysctl --system

echo -e "------------------------------------------------"
echo -e "${GREEN}安装完成！${PLAIN}"
echo -e "请务必${RED}重启服务器${PLAIN}以加载新内核。"
echo -e "重启后，输入命令 ${YELLOW}uname -r${PLAIN} 查看内核，应包含 'xanmod' 字样。"
echo -e "输入命令 ${YELLOW}modinfo tcp_bbr${PLAIN} 查看版本，version 应显示 3.x。"
echo -e "------------------------------------------------"

read -p "是否立即重启服务器? [y/n] " verify
if [[ "$verify" == "y" || "$verify" == "Y" ]]; then
    reboot
else
    echo -e "请稍后手动执行 reboot 命令重启。"
fi
