#!/bin/bash
# deploy_all.sh
# 一键部署多IP代理服务（L2TP + SOCKS5 + Shadowsocks）
# 适用 CentOS 7+
# 服务器: 121.12.74.120
# 弹性IP列表（包含主IP）：121.12.74.120,121.12.74.177,121.12.74.114,183.60.221.112,183.60.221.190,183.60.221.58,183.60.221.253,183.60.221.42,183.60.221.178,183.60.221.74

set -e

# 参数配置
PSK="111111"
L2TP_USER="vip1"
L2TP_PASS="111111"
SOCKS_USER="vip1"
SOCKS_PASS="111111"
SS_PASS="111111"
SS_METHOD="chacha20-ietf-poly1305"
BASE_SOCKS_PORT=18889
BASE_SS_PORT=2080

IP_LIST=(
  "121.12.74.120"
  "121.12.74.177"
  "121.12.74.114"
  "183.60.221.112"
  "183.60.221.190"
  "183.60.221.58"
  "183.60.221.253"
  "183.60.221.42"
  "183.60.221.178"
  "183.60.221.74"
)

# 取默认网卡
IFACE=$(ip route | awk '/default/ {print $5; exit}')

echo "开始部署："
echo "网卡: $IFACE"
echo "IP总数: ${#IP_LIST[@]}"

# 安装依赖
echo "安装依赖..."
yum install -y epel-release wget curl ppp libreswan xl2tpd iptables-services dante-server shadowsocks-libev

# 配置多IP网卡绑定
echo "配置多IP网卡绑定..."
for i in "${!IP_LIST[@]}"; do
  [ $i -eq 0 ] && continue
  ip addr add "${IP_LIST[$i]}/24" dev "$IFACE" || true
done

# --- L2TP/IPSec 配置 ---
echo "配置 L2TP/IPSec..."
cat > /etc/ipsec.conf << EOF
config setup
  nat_traversal=yes
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16

conn L2TP-PSK
  authby=secret
  type=transport
  left=%defaultroute
  leftprotoport=17/1701
  right=%any
  rightprotoport=17/%any
  auto=add
EOF

# 预共享密钥
cat > /etc/ipsec.secrets << EOF
%any %any : PSK "$PSK"
EOF

# xl2tpd 配置
cat > /etc/xl2tpd/xl2tpd.conf << EOF
[global]
listen-addr = 0.0.0.0
port = 1701

[lns default]
ip range = 192.168.18.10-192.168.18.250
local ip = 192.168.18.1
require chap = yes
refuse pap = yes
require authentication = yes
name = L2TP-VPN
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

# PPP 选项
cat > /etc/ppp/options.xl2tpd << EOF
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
asyncmap 0
auth
crtscts
lock
hide-password
modem
debug
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOF

# CHAP 密码
cat > /etc/ppp/chap-secrets << EOF
# client    server    secret            IP addresses
"$L2TP_USER"    *    "$L2TP_PASS"    *
EOF

systemctl enable ipsec xl2tpd
systemctl start ipsec xl2tpd

# --- SOCKS5 配置 (Dante) ---
echo "配置 SOCKS5..."
cat > /etc/danted.conf << EOF
logoutput: stderr
internal: 0.0.0.0 port = $BASE_SOCKS_PORT
external: $IFACE
method: username
user.privileged: root
user.unprivileged: nobody

client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: error
}

socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  protocol: tcp udp
  log: error
}
EOF

systemctl enable sockd
systemctl start sockd

# --- Shadowsocks 配置 ---
echo "配置 Shadowsocks..."
mkdir -p /etc/shadowsocks-libev
for i in "${!IP_LIST[@]}"; do
  port=$((BASE_SS_PORT + i))
  cat > /etc/shadowsocks-libev/config-$i.json << EOF
{
  "server":"${IP_LIST[$i]}",
  "server_port":$port,
  "password":"$SS_PASS",
  "timeout":300,
  "method":"$SS_METHOD",
  "fast_open":false
}
EOF
  systemctl enable shadowsocks-libev\@$i
  systemctl start shadowsocks-libev\