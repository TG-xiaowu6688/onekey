#!/usr/bin/env bash

#====================================================
#   系统要求: CentOS 7+ / Debian 8+ / Ubuntu 16.04+
#   作者: 九州科技@xiaowu6688
#   描述: 安装 Shadowsocks-libev
#   版本: 1.1
#====================================================

set -e

#设置ss软件
cd /etc/yum.repos.d/
curl -O https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo

# 获取公网 IP
IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)

# 字体颜色
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

# 当前路径
cd "$(cd "$(dirname "$0")" && pwd)" || exit

# 系统判断
check_system() {
    source /etc/os-release
    if [[ "${ID}" == "centos" && ${VERSION_ID%%.*} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 CentOS ${VERSION_ID} ${Font}"
        PM="yum"
        $PM install -y epel-release
    elif [[ "${ID}" == "debian" && ${VERSION_ID%%.*} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${Font}"
        PM="apt"
        $PM update -y
    elif [[ "${ID}" == "ubuntu" && ${VERSION_ID%%.*} -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${Font}"
        PM="apt"
        $PM update -y
    else
        echo -e "${Error} ${RedBG} 不支持的系统：${ID} ${VERSION_ID}，安装中断 ${Font}"
        exit 1
    fi
}

# 判断是否 root 用户
is_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${Error} ${RedBG} 当前非 root 用户，请使用 sudo 或切换为 root 后执行 ${Font}"
        exit 1
    fi
    echo -e "${OK} ${GreenBG} 当前为 root 用户 ${Font}"
}

# 安装 Shadowsocks-libev
# 安装 Shadowsocks-libev（支持 yum/apt）
install_shadowsocks() {
    if [[ "$PM" == "yum" ]]; then
#        yum install -y yum-plugin-copr
#        judge "安装 Copr 插件"
#        yum copr enable -y librehat/shadowsocks
#        judge "启用 Shadowsocks COPR 源"
        yum install -y shadowsocks-libev
    elif [[ "$PM" == "apt" ]]; then
        apt install -y shadowsocks-libev
    fi
    judge "安装 Shadowsocks-libev"
}


# 判断命令执行成功
judge() {
    if [[ $? -eq 0 ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
    else
        echo -e "${Error} ${RedBG} $1 失败，脚本中止 ${Font}"
        exit 1
    fi
}

# 配置 Shadowsocks
configure_shadowsocks() {
    mkdir -p /etc/shadowsocks-libev
    cat > /etc/shadowsocks-libev/config.json <<EOF
{
    "server":["::0", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":2080,
    "local_port":10810,
    "password":"111111",
    "timeout":86400,
    "method":"chacha20-ietf-poly1305"
}
EOF
    judge "配置文件写入"
}

# 启动服务
start_shadowsocks() {
    if command -v systemctl &>/dev/null; then
        systemctl restart shadowsocks-libev
        systemctl enable shadowsocks-libev
    else
        /etc/init.d/shadowsocks-libev restart
    fi
    judge "Shadowsocks-libev 启动"
}

# 关闭防火墙
disable_firewall() {
    if [[ "$PM" == "yum" ]]; then
        systemctl stop firewalld &>/dev/null || true
        systemctl disable firewalld &>/dev/null || true
        yum install -y iptables-services
        systemctl enable iptables
        service iptables save
    elif [[ "$PM" == "apt" ]]; then
        systemctl stop ufw &>/dev/null || true
        systemctl disable ufw &>/dev/null || true
    fi
    judge "防火墙配置"
}

# 主流程
main() {
    is_root
    check_system
    disable_firewall
    $PM install -y wget curl lsof
    install_shadowsocks
    configure_shadowsocks
    start_shadowsocks
    echo "----------------------------------------------------"
    echo "----安装完毕,by 九州科技@xiaowu6688-----------------"
    echo "----------------------------------------------------"
    echo "----SS安装完成，配置信息如下------------------------"
    echo "-----------------------------------------------------"
    echo " IP地址    ：$IP"
    echo " 端口      ：2080"
    echo " 密码      ：111111"
    echo " 加密方式  ：chacha20-ietf-poly1305"
    echo "-------------------------------------------"
}

main
