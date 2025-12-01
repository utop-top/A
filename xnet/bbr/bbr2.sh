#!/bin/bash

# 确保 root 权限
[ "$(id -u)" != "0" ] && { echo "需 root 权限运行"; exit 1; }

# 检查并加载 BBR 模块
modprobe tcp_bbr || { echo "BBR 模块加载失败，需内核 4.9+"; exit 1; }

# 核心优化：启用 BBR 和 FQ 队列
sysctl -w net.core.default_qdisc=fq_codel
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 极致 TCP 和网络参数优化
cat << EOF > /etc/sysctl.d/99-bbr-optimize.conf
# BBR 和队列
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr

# TCP 缓冲区优化（高带宽延迟网络）
net.ipv4.tcp_rmem=4096 131072 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.rmem_default=8388608
net.core.wmem_default=8388608

# 网络队列和吞吐量
net.core.netdev_max_backlog=10000
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15

# TCP 性能增强
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_ecn=1
net.ipv4.tcp_no_metrics_save=1

# 优化连接处理
net.ipv4.ip_local_port_range=1024 65535
net.core.optmem_max=81920
EOF

# 应用配置
sysctl -p /etc/sysctl.d/99-bbr-optimize.conf

# 验证 BBR 是否启用
[ "$(sysctl -n net.ipv4.tcp_congestion_control)" = "bbr" ] && echo "BBR 已启用，极致优化完成！" || { echo "BBR 启用失败"; exit 1; }

# 检查可用拥塞控制算法
echo "可用算法：$(sysctl -n net.ipv4.tcp_available_congestion_control)"

# 建议重启网络服务（可选）
echo "建议重启网络服务以确保所有设置生效：sudo systemctl restart networking || sudo service networking restart"

exit 0