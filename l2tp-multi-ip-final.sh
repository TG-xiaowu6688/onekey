#!/usr/bin/env bash
#================================================
# 多 IP L2TP 服务器一键部署脚本
# 基于原始 l2s.sh，支持 5 个公网 IP
# 让客户端连接成功并实现 IP 对应
#================================================

# 配置参数
PSK="111111"
PASSWORD="111111"

# 5 个公网 IP（客户提供）
IPS=(
    "59.38.142.139"
    "121.12.74.10"
    "59.38.141.255"
    "125.94.150.178"
    "125.94.151.107"
)

# 对应的内网 IP 段
IPRANGES=(
    "192.168.18"
    "192.168.19"
    "192.168.20"
    "192.168.21"
    "192.168.22"
)

echo "=========================================="
echo "   多 IP L2TP 服务器部署"
echo "=========================================="
echo "配置 5 个公网 IP 为 L2TP 服务器："
for i in "${!IPS[@]}"; do
    echo "  IP $((i+1)): ${IPS[$i]} → 内网段: ${IPRANGES[$i]}.0/24"
done
echo "=========================================="
echo ""

# 安装依赖（使用原始脚本的仓库源）
echo "[1/6] 配置仓库源..."
rm -rf /etc/yum.repos.d/*
curl -O http://8.138.120.72/kuyuan/epel.repo && mv epel.repo /etc/yum.repos.d/
curl -O http://8.138.120.72/kuyuan/CentOS7-ctyun.repo && mv CentOS7-ctyun.repo /etc/yum.repos.d/
curl -O http://8.138.120.72/kuyuan/epel-testing.repo && mv epel-testing.repo /etc/yum.repos.d/
curl -O http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7 && mv RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/

echo "[2/6] 安装依赖包..."
yum install -y epel-release yum-utils wget ppp libreswan xl2tpd iptables-services iptables-devel pptpd

# 配置 IPSec（为每个 IP 创建连接）
echo "[3/6] 配置 IPSec..."
cat > /etc/ipsec.conf <<EOF
config setup
    protostack=netkey
    interfaces=%defaultroute
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12
EOF

# 为每个 IP 创建 IPSec 连接配置
for i in "${!IPS[@]}"; do
    IP="${IPS[$i]}"
    IPRANGE="${IPRANGES[$i]}"
    
    cat >> /etc/ipsec.conf <<EOF

conn l2tp-psk-${i}
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
done

cat > /etc/ipsec.secrets <<EOF
%any %any : PSK "${PSK}"
EOF
chmod 600 /etc/ipsec.secrets

# 配置 xl2tpd（为每个 IP 创建服务）
echo "[4/6] 配置 xl2tpd..."
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701
EOF

# 为每个 IP 创建 xl2tpd 配置
for i in "${!IPS[@]}"; do
    IPRANGE="${IPRANGES[$i]}"
    
    cat >> /etc/xl2tpd/xl2tpd.conf <<EOF

[lns default${i}]
ip range = ${IPRANGE}.2-${IPRANGE}.254
local ip = ${IPRANGE}.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd${i}
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
done

# 配置 PPP
echo "[5/6] 配置 PPP..."
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

# 创建账号（每个 IP 10 个账号）
cat > /etc/ppp/chap-secrets <<EOF
# L2TP VPN 账号配置
# 每个 IP 对应 10 个账号
EOF

for i in "${!IPS[@]}"; do
    IPRANGE="${IPRANGES[$i]}"
    IP_NUM=$((i+1))
    
    cat >> /etc/ppp/chap-secrets <<EOF

# 服务器 ${IP_NUM}: ${IPS[$i]}
vip${IP_NUM}1    *    ${PASSWORD}    ${IPRANGE}.201
vip${IP_NUM}2    *    ${PASSWORD}    ${IPRANGE}.202
vip${IP_NUM}3    *    ${PASSWORD}    ${IPRANGE}.203
vip${IP_NUM}4    *    ${PASSWORD}    ${IPRANGE}.204
vip${IP_NUM}5    *    ${PASSWORD}    ${IPRANGE}.205
vip${IP_NUM}6    *    ${PASSWORD}    ${IPRANGE}.206
vip${IP_NUM}7    *    ${PASSWORD}    ${IPRANGE}.207
vip${IP_NUM}8    *    ${PASSWORD}    ${IPRANGE}.208
vip${IP_NUM}9    *    ${PASSWORD}    ${IPRANGE}.209
vip${IP_NUM}0    *    ${PASSWORD}    ${IPRANGE}.210
EOF
done

chmod 600 /etc/ppp/chap-secrets

# 启动服务并设置开机启动
echo "[6/6] 启动服务..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

systemctl enable ipsec xl2tpd
systemctl restart ipsec xl2tpd

# 配置防火墙（使用原始脚本的配置）
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
EOF

# 为每个 IP 段添加转发规则
for IPRANGE in "${IPRANGES[@]}"; do
    cat >> /etc/sysconfig/iptables <<EOF
-A FORWARD -s ${IPRANGE}.0/24 -j ACCEPT
-A FORWARD -d ${IPRANGE}.0/24 -j ACCEPT
EOF
done

cat >> /etc/sysconfig/iptables <<EOF
COMMIT
*nat
:POSTROUTING ACCEPT [0:0]
EOF

# 为每个 IP 段添加 NAT 规则
for IPRANGE in "${IPRANGES[@]}"; do
    cat >> /etc/sysconfig/iptables <<EOF
-A POSTROUTING -s ${IPRANGE}.0/24 -o eth0 -j MASQUERADE
EOF
done

cat >> /etc/sysconfig/iptables <<EOF
COMMIT
EOF

systemctl stop firewalld 2>/dev/null
systemctl disable firewalld 2>/dev/null
systemctl enable iptables
systemctl restart iptables

# 输出结果
echo ""
echo "=========================================="
echo "   ✅ 多 IP L2TP 服务器部署成功！"
echo "=========================================="
echo ""
echo "📋 连接信息汇总："
echo "=========================================="
for i in "${!IPS[@]}"; do
    IP="${IPS[$i]}"
    IP_NUM=$((i+1))
    echo ""
    echo "🔹 服务器 ${IP_NUM}: ${IP}"
    echo "   PSK: ${PSK}"
    echo "   账号: vip${IP_NUM}1 ~ vip${IP_NUM}0 (10个)"
    echo "   密码: ${PASSWORD}"
    echo "   内网段: ${IPRANGES[$i]}.201 ~ ${IPRANGES[$i]}.210"
done
echo ""
echo "=========================================="
echo "   ROS/手机连接配置示例"
echo "=========================================="
echo "类型：L2TP"
echo "服务器：选择任意一个 IP"
echo "账户：对应的 vip 账号"
echo "密码：${PASSWORD}"
echo "密钥：${PSK}"
echo ""
echo "账号 → IP 对应关系："
echo "vip11~vip10 → 出口 IP: ${IPS[0]}"
echo "vip21~vip20 → 出口 IP: ${IPS[1]}"
echo "vip31~vip30 → 出口 IP: ${IPS[2]}"
echo "vip41~vip40 → 出口 IP: ${IPS[3]}"
echo "vip51~vip50 → 出口 IP: ${IPS[4]}"
echo "=========================================="
echo ""
echo "服务运行状态："
systemctl is-active ipsec >/dev/null 2>&1 && echo "✅ IPSec 运行中" || echo "❌ IPSec 未运行"
systemctl is-active xl2tpd >/dev/null 2>&1 && echo "✅ xl2tpd 运行中" || echo "❌ xl2tpd 未运行"
echo "=========================================="