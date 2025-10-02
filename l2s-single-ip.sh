#!/usr/bin/env bash
# ==============================================================
# 客户原始l2s.sh脚本-单IP拨号增强兼容版
# 只需配置主IP，账号vip1 密码111111，即可让对方登录
# 以 59.38.142.139 为例，替换IP后可复用
# ==============================================================

psk="111111"
username="vip1"
password="111111"
iprange="192.168.18"
export LC_ALL=C

# 公网IP设置，强制指定主IP（适配云和物理服务器）
main_ip="59.38.142.139"
IP="$main_ip"
if [[ -z "$IP" ]]; then
    IP=$(curl -s http://ip.sb)
fi

# 备份重要配置
[[ -f /etc/ipsec.conf ]] && cp /etc/ipsec.conf /etc/ipsec.conf.bak
[[ -f /etc/ipsec.secrets ]] && cp /etc/ipsec.secrets /etc/ipsec.secrets.bak
[[ -f /etc/xl2tpd/xl2tpd.conf ]] && cp /etc/xl2tpd/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf.bak
[[ -f /etc/ppp/chap-secrets ]] && cp /etc/ppp/chap-secrets /etc/ppp/chap-secrets.bak

# 安装依赖
rm -rf /etc/yum.repos.d/*
curl -Os http://8.138.120.72/kuyuan/epel.repo && mv epel.repo /etc/yum.repos.d/
curl -Os http://8.138.120.72/kuyuan/CentOS7-ctyun.repo && mv CentOS7-ctyun.repo /etc/yum.repos.d/
curl -Os http://8.138.120.72/kuyuan/epel-testing.repo && mv epel-testing.repo /etc/yum.repos.d/
curl -Os http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7 && mv RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/
yum install -y epel-release yum-utils wget ppp libreswan xl2tpd iptables-services iptables-devel pptpd

# 配置IPSec（兼容多内核情况）
cat > /etc/ipsec.conf <<EOF
config setup
    protostack=netkey
    interfaces=eth0
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!${iprange}.0/24
conn l2tp-psk
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=${IP}
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    sha2-truncbug=yes
EOF

cat > /etc/ipsec.secrets <<EOF
%any %any : PSK "$psk"
EOF
chmod 600 /etc/ipsec.secrets

# 配置xl2tpd
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
[lns default]
ip range = ${iprange}.2-${iprange}.254
local ip = ${iprange}.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

# PPP配置
cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
hide-password
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF

cat > /etc/ppp/chap-secrets <<EOF
vip1    *    111111    *
EOF
chmod 600 /etc/ppp/chap-secrets

# 启动服务
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
service ipsec restart
service xl2tpd restart

iptables -F
iptables -t nat -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p udp --dport 1701 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -s ${iprange}.0/24 -j ACCEPT
iptables -A FORWARD -d ${iprange}.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s ${iprange}.0/24 -o eth0 -j MASQUERADE
service iptables save &>/dev/null || true
service iptables restart

# 显示配置
clear
echo "=============================================="
echo "✅ 单IP L2TP 服务器部署成功！"
echo "=============================================="
echo "服务器IP: $IP"
echo "账号: vip1"
echo "密码: 111111"
echo "PSK: 111111"
echo "内网段: ${iprange}.1 ~ ${iprange}.254"
echo "=============================================="
echo "服务运行状态:"
service ipsec status | grep active
service xl2tpd status | grep running
