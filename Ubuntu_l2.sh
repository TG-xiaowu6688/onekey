#!/usr/bin/env bash

psk="111111"
username="vip1"
password="111111"
iprange="192.168.18"

# 公网 IP 获取
IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)

# 安装依赖
rm -rf /etc/yum.repos.d/* 
sudo curl -O http://8.138.120.72/kuyuan/epel.repo 
sudo mv epel.repo /etc/yum.repos.d/ 
sudo curl -O http://8.138.120.72/kuyuan/CentOS7-ctyun.repo 
sudo mv CentOS7-ctyun.repo /etc/yum.repos.d/ 
sudo curl -O http://8.138.120.72/kuyuan/epel-testing.repo 
sudo mv epel-testing.repo /etc/yum.repos.d/ 
sudo curl -O http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7 
sudo mv RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/ 
yum install -y epel-release yum-utils wget ppp libreswan xl2tpd iptables-services iptables-devel pptpd

# 配置文件写入
cat > /etc/ipsec.conf <<EOF
config setup
    protostack=netkey
    interfaces=%defaultroute
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
    left=%defaultroute
    leftid=${IP}
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    sha2-truncbug=yes
EOF

cat > /etc/ipsec.secrets <<EOF
%any %any : PSK "${psk}"
EOF

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
# client  server  secret  IP addresses
${username} l2tpd ${password} *
EOF

# 启动服务并设置开机启动
sysctl -w net.ipv4.ip_forward=1
systemctl enable ipsec xl2tpd
systemctl restart ipsec xl2tpd

# 配置防火墙
cat > /etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p udp --dport 500 -j ACCEPT
-A INPUT -p udp --dport 4500 -j ACCEPT
-A INPUT -p udp --dport 1701 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp --dport 22 -j ACCEPT
-A FORWARD -s ${iprange}.0/24 -j ACCEPT
-A FORWARD -d ${iprange}.0/24 -j ACCEPT
COMMIT
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${iprange}.0/24 -o eth0 -j MASQUERADE
COMMIT
EOF

systemctl stop firewalld
systemctl disable firewalld
systemctl enable iptables
systemctl restart iptables

# 输出结果
echo
echo "------------------------------------------------------"
echo "----安装完毕,联系人@jz168689----"
echo "------------------------------------------------------"
echo "L2TP VPN 安装完成"
echo "公网ip：${IP}"
echo "PSK：${psk}"
echo "账号：${username}"
echo "密码：${password}"
