#!/usr/bin/env bash

psk="111111"
username="vip1"
password="111111"
iprange="59.38.142"

# 定义要绑定的5个公网IP地址
ip1="59.38.142.139"
ip2="121.12.74.10"
ip3="59.38.141.255"
ip4="125.94.150.178"
ip5="125.94.151.107"

# 公网 IP 获取
IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)

echo "绑定公网IP别名到网卡..."
ifconfig eth0:1 ${ip1} netmask 255.255.255.255 up
ifconfig eth0:2 ${ip2} netmask 255.255.255.255 up
ifconfig eth0:3 ${ip3} netmask 255.255.255.255 up
ifconfig eth0:4 ${ip4} netmask 255.255.255.255 up
ifconfig eth0:5 ${ip5} netmask 255.255.255.255 up

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

# 配置 IPsec
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

# 配置 xl2tpd
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

# 配置 PPP 选项
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

# chap-secrets 中映射 5 个 IP
cat > /etc/ppp/chap-secrets <<EOF
# client  server  secret  IP addresses
vip1    *    111111       ${ip1}
vip2    *    111111       ${ip2}
vip3    *    111111       ${ip3}
vip4    *    111111       ${ip4}
vip5    *    111111       ${ip5}
EOF

# 启动并设为开机自启
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

# 保存 IP 别名
cat > /etc/sysconfig/network-scripts/ifcfg-eth0:1 <<EOF
DEVICE=eth0:1
BOOTPROTO=static
ONBOOT=yes
IPADDR=${ip1}
NETMASK=255.255.255.255
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0:2 <<EOF
DEVICE=eth0:2
BOOTPROTO=static
ONBOOT=yes
IPADDR=${ip2}
NETMASK=255.255.255.255
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0:3 <<EOF
DEVICE=eth0:3
BOOTPROTO=static
ONBOOT=yes
IPADDR=${ip3}
NETMASK=255.255.255.255
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0:4 <<EOF
DEVICE=eth0:4
BOOTPROTO=static
ONBOOT=yes
IPADDR=${ip4}
NETMASK=255.255.255.255
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0:5 <<EOF
DEVICE=eth0:5
BOOTPROTO=static
ONBOOT=yes
IPADDR=${ip5}
NETMASK=255.255.255.255
EOF

# 输出结果
```bash
echo "安装完成，支持多IP: ${ip1}, ${ip2}, ${ip3}, ${ip4}, ${ip5}"
```
