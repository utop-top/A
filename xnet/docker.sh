#!/bin/bash

# 一键安装/升级 Docker 的交互脚本 - 适用于 Debian 系统 (官方最新版)
# 作者: Grok (基于官方 Docker 文档 2025)
# 使用方法: sudo bash <script_name>.sh
# 注意: 必须以 root 或 sudo 权限运行

set -e  # 遇到错误时退出

# 颜色输出函数
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

echo "${green}=== Docker 一键安装/升级脚本 (Debian 系统 - 官方最新版) ===${reset}"
echo "当前系统: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# 检查是否已安装 Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo "${yellow}检测到已安装 Docker 版本: $DOCKER_VERSION${reset}"
    HAS_DOCKER=true
else
    echo "${yellow}未检测到 Docker，已准备安装最新版。${reset}"
    HAS_DOCKER=false
fi

# 交互菜单
show_menu() {
    echo "${green}请选择操作:${reset}"
    if [ "$HAS_DOCKER" = true ]; then
        echo "1) 升级到最新版 Docker"
    else
        echo "1) 安装官方最新版 Docker"
    fi
    echo "2) 卸载 Docker (谨慎使用)"
    echo "3) 退出"
    echo ""
}

# 安装函数
install_docker() {
    echo "${yellow}开始安装官方最新版 Docker...${reset}"
    
    # 更新包索引
    apt-get update
    
    # 安装依赖
    apt-get install -y ca-certificates curl
    
    # 卸载旧版 (官方列表，忽略不存在的包错误)
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        apt-get remove -y $pkg || true
    done
    
    # 添加 Docker 官方 GPG 密钥 (官方方式)
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    
    # 添加 Docker 仓库 (使用 VERSION_CODENAME 以兼容衍生版)
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包索引并安装最新版
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # 启动并启用 Docker 服务
    systemctl start docker
    systemctl enable docker
    
    # 添加当前用户到 docker 组 (可选，非 root 用户)
    if [ "$EUID" -ne 0 ]; then
        echo "${yellow}警告: 以非 root 用户运行，需手动执行: sudo usermod -aG docker $USER${reset}"
        echo "然后注销并重新登录以生效。"
    fi
    
    echo "${green}安装完成! Docker 版本: $(docker --version)${reset}"
    echo "测试: sudo docker run hello-world"
}

# 升级函数
upgrade_docker() {
    echo "${yellow}开始升级到官方最新版 Docker...${reset}"
    
    # 更新包索引
    apt-get update
    
    # 升级 Docker 相关包 (忽略不存在的包错误)
    apt-get upgrade -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    
    # 重启 Docker 服务
    systemctl restart docker
    
    echo "${green}升级完成! 新版本: $(docker --version)${reset}"
}

# 卸载函数
uninstall_docker() {
    echo "${red}确认卸载 Docker? (y/N): ${reset}"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
        rm -rf /var/lib/docker /etc/docker
        rm -rf /var/lib/containerd
        systemctl daemon-reload
        echo "${green}卸载完成。${reset}"
    else
        echo "${yellow}取消卸载。${reset}"
    fi
}

# 主循环
while true; do
    show_menu
    read -r choice
    case $choice in
        1)
            if [ "$HAS_DOCKER" = true ]; then
                upgrade_docker
            else
                install_docker
            fi
            HAS_DOCKER=true  # 更新状态
            ;;
        2)
            uninstall_docker
            HAS_DOCKER=false  # 更新状态
            ;;
        3)
            echo "${green}脚本结束。再见!${reset}"
            exit 0
            ;;
        *)
            echo "${red}无效选项，请重试。${reset}"
            ;;
    esac
    echo ""
done