#!/usr/bin/env bash

#====================================================
#   System Request:Centos 7+ or Ubuntu 20.4+
#   Author: 张三封
#   Dscription: Socks5 Installation
#   Version: 1.0
#   email: 111111111@gmail.com
#   TG: @Coffee_Yu
#====================================================

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cd "$(
    cd "$(dirname "$0")" || exit
    pwd
)" || exit

#fonts color
Green="\033[32m"
Red="\033[31m"
# Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"
source '/etc/os-release'
#notification information
# Info="${Green}[信息]${Font}"
OK="${Green}[OK]${Font}"
error="${Red}[错误]${Font}"
check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Centos ${VERSION_ID} ${VERSION} ${Font}"
        INS="yum"
#	$INS update -y
	yum remove firewalld -y ; yum install -y iptables-services ; iptables -F ; iptables -t filter -F ; systemctl enable iptables.service ; service iptables save ; systemctl start iptables.service

    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Debian ${VERSION_ID} ${VERSION} ${Font}"
        INS="apt"
        $INS update -y
        ## 添加 apt源
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        echo -e "${OK} ${GreenBG} 当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME} ${Font}"
        INS="apt"
        $INS update 
	systemctl disable ufw.service ; systemctl stop ufw.service
    else
        echo -e "${Error} ${RedBG} 当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内，安装中断 ${Font}"
        exit 1
    fi

	$INS -y install lsof wget curl
}


is_root() {
    if [ 0 == $UID ]; then
        echo -e "${OK} ${GreenBG} 当前用户是root用户，进入安装流程 ${Font}"
        sleep 3
    else
        echo -e "${Error} ${RedBG} 当前用户不是root用户，请切换到使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
        exit 1
    fi
}

judge() {
    if [[ 0 -eq $? ]]; then
        echo -e "${OK} ${GreenBG} $1 完成 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 失败${Font}"
        exit 1
    fi
}
apt-get update;
sudo apt install -y shadowsocks-libev;

/etc/init.d/shadowsocks-libev start;
systemctl start shadowsocks-libev;   

echo '{
    "server":["::0", "0.0.0.0"],
    "mode":"tcp_and_udp",
    "server_port":2080,
    "local_port":10810,
    "password":"111111",
    "timeout":86400,
    "method":"chacha20-ietf-poly1305"
}' > /etc/shadowsocks-libev/config.json;

systemctl restart shadowsocks-libev;
