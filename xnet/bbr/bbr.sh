#!/bin/bash

# BBR 加速脚本 - 性能强健版 (Linux 系统，适用于 Debian/Ubuntu 等)
# 作者: Grok (基于官方内核文档)
# 功能: 一键启用 TCP BBR 拥塞控制算法，提高网络传输性能
# 要求: 内核版本 >= 4.9 (推荐 5.x+)
# 使用: sudo bash bbr-enable.sh
# 注意: 运行后重启网络服务或系统以生效

set -e  # 遇到错误时退出

# 颜色输出函数
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

echo "${green}=== BBR 加速脚本 (性能强健版) ===${reset}"
echo "当前系统: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# 检查内核版本
KERNEL_VERSION=$(uname -r | cut -d. -f1-2)
MIN_KERNEL="4.9"
if [[ $(echo "$KERNEL_VERSION >= $MIN_KERNEL" | bc -l 2>/dev/null) -ne 1 ]]; then
    echo "${red}错误: 内核版本 $KERNEL_VERSION < $MIN_KERNEL，不支持 BBR。${reset}"
    echo "建议: 更新内核 (apt install linux-generic-hwe-$(lsb_release -rs))"
    exit 1
fi
echo "${green}内核版本 $KERNEL_VERSION 支持 BBR。${reset}"

# 检查是否已启用 BBR
if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo "${yellow}BBR 已启用，无需操作。当前设置: $(sysctl net.ipv4.tcp_congestion_control)${reset}"
    exit 0
fi

# 交互确认
echo "${yellow}即将启用 BBR 加速 (会修改 sysctl.conf)。确认? (y/N): ${reset}"
read -r confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "${yellow}取消操作。${reset}"
    exit 0
fi

echo "${yellow}开始启用 BBR...${reset}"

# 加载 BBR 模块
modprobe tcp_bbr || echo "${yellow}警告: tcp_bbr 模块加载失败 (可能已内置)。${reset}"

# 设置临时 sysctl 参数
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 持久化设置 (追加到 sysctl.conf，避免覆盖)
cat >> /etc/sysctl.conf << EOF
# BBR 加速设置 (启用 FQ + BBR 以优化 TCP 性能)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF

# 应用持久化设置
sysctl -p

# 验证
if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo "${green}BBR 启用成功!${reset}"
    echo "当前拥塞控制: $(sysctl net.ipv4.tcp_congestion_control)"
    echo "当前队列规则: $(sysctl net.core.default_qdisc)"
    echo ""
    echo "${yellow}建议: 重启系统或运行 'systemctl restart networking' 以完全生效。${reset}"
    echo "测试性能: 使用 iperf3 或 speedtest-cli (apt install iperf3 speedtest-cli)"
else
    echo "${red}启用失败，请检查日志。${reset}"
    exit 1
fi

echo "${green}脚本完成。网络性能已优化!${reset}"