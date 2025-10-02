#!/bin/bash
# =======================================================
# 多IP代理服务器一键部署脚本（完整版）
# 支持: L2TP/IPSec, SOCKS5, Shadowsocks
# 系统: CentOS 7
# 版本: 3.0
# 日期: 2025-10-02
# =======================================================

set -e

# ==================== 配置参数 ====================
PSK="111111"
L2TP_USER="vip1"
L2TP_PASS="111111"
SOCKS_USER="vip1"
SOCKS_PASS="111111"
SS_PASS="111111"
SS_METHOD="chacha20-ietf-poly1305"
BASE_SOCKS_PORT=18889
BASE_SS_PORT=2080

# 服务器的5个IP地址
IP_LIST=(
  "59.38.142.139"   # 主IP
  "121.12.74.10"
  "59.38.141.255"
  "125.94.150.178"
  "125.94.151.107"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}[====]${NC} $1"; }

IFACE=$(ip route | awk '/default/ {print $5; exit}')

# ==================== 检查Root权限 ====================
if [[ $EUID -ne 0 ]]; then
   log_error "此脚本需要root权限运行！请使用: sudo bash $0"
fi

echo ""
log_step "=========================================="
log_step "   多IP代理服务器一键部署"
log_step "=========================================="
echo ""
log_info "系统: $(cat /etc/redhat-release)"
log_info "网卡: $IFACE"
log_info "IP数量: ${#IP_LIST[@]}"
echo ""

# ==================== 1. 安装基础依赖 ====================
log_step "步骤1: 安装基础依赖包"
yum install -y epel-release wget curl gcc make cmake autoconf libtool \
               ppp libreswan xl2tpd iptables-services dante-server \
               c-ares libev yum-utils 2>&1 | grep -E "(已安装|Complete|完毕)" || true
log_info "基础依赖安装完成"
echo ""

# ==================== 2. 安装libsodium ====================
log_step "步骤2: 安装 libsodium"
if rpm -qa | grep -q libsodium; then
    log_info "libsodium 已安装，跳过"
else
    cd /tmp
    wget -q http://mirrors.aliyun.com/epel/7/x86_64/Packages/l/libsodium-1.0.18-1.el7.x86_64.rpm
    rpm -ivh libsodium-1.0.18-1.el7.x86_64.rpm
    log_info "libsodium 安装完成"
fi
echo ""

# ==================== 3. 编译安装mbedtls ====================
log_step "步骤3: 编译安装 mbedtls（约5分钟）"
if ldconfig -p | grep -q libmbedcrypto.so.2; then
    log_info "mbedtls 已安装，跳过"
else
    cd /tmp
    if [ ! -f mbedtls-2.16.12.tar.gz ]; then
        log_info "下载 mbedtls 源码..."
        wget --no-check-certificate -q https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/mbedtls-2.16.12.tar.gz -O mbedtls-2.16.12.tar.gz || \
        curl -k -L -o mbedtls-2.16.12.tar.gz https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/mbedtls-2.16.12.tar.gz
    fi

    tar -xzf mbedtls-2.16.12.tar.gz
    cd mbedtls-mbedtls-2.16.12
    mkdir -p build && cd build

    log_info "编译 mbedtls..."
    cmake -DUSE_SHARED_MBEDTLS_LIBRARY=ON .. >/dev/null 2>&1
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null 2>&1

    # 创建版本兼容软链接
    cd /usr/local/lib
    ln -sf libmbedcrypto.so.2.16.12 libmbedcrypto.so.2
    ln -sf libmbedtls.so.2.16.12 libmbedtls.so.10
    ln -sf libmbedx509.so.2.16.12 libmbedx509.so.0

    # 配置动态库路径
    echo '/usr/local/lib' > /etc/ld.so.conf.d/mbedtls.conf
    ldconfig

    # 永久设置环境变量
    if ! grep -q "LD_LIBRARY_PATH=/usr/local/lib" /etc/profile; then
        echo 'export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH' >> /etc/profile
    fi
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

    log_info "mbedtls 编译安装完成"
fi
echo ""

# ==================== 4. 安装shadowsocks-libev ====================
log_step "步骤4: 安装 shadowsocks-libev"
if rpm -qa | grep -q shadowsocks-libev; then
    log_info "shadowsocks-libev 已安装，跳过"
else
    cd /tmp
    yumdownloader shadowsocks-libev 2>&1 | grep -v "warning" || true
    rpm -ivh --nodeps shadowsocks-libev-*.rpm 2>&1 | grep -v "warning" || true
    log_info "shadowsocks-libev 安装完成"
fi

# 验证shadowsocks
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
if ss-server --help >/dev/null 2>&1; then
    log_info "shadowsocks-libev 验证成功"
else
    log_warn "shadowsocks 可能需要手动配置环境变量"
fi
echo ""

# ==================== 5. 配置多IP ====================
log_step "步骤5: 配置多IP绑定"
for i in "${!IP_LIST[@]}"; do
    [ $i -eq 0 ] && continue
    ip="${IP_LIST[$i]}"
    if ip addr show "$IFACE" | grep -q "$ip"; then
        echo "  - $ip (已存在)"
    else
        ip addr add "$ip/24" dev "$IFACE" 2>/dev/null && echo "  ✓ $ip" || echo "  ✗ $ip (失败)"
    fi
done
echo ""

# ==================== 6. 配置L2TP/IPSec ====================
log_step "步骤6: 配置 L2TP/IPSec"
cat > /etc/ipsec.conf << 'EOFIPSEC'
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
  pfs=no
EOFIPSEC

cat > /etc/ipsec.secrets << EOFSECRET
%any %any : PSK "$PSK"
EOFSECRET

cat > /etc/xl2tpd/xl2tpd.conf << EOFXL2TPD
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
EOFXL2TPD

cat > /etc/ppp/options.xl2tpd << 'EOFPPP'
require-mschap-v2
ms-dns 8.8.8.8
ms-dns 8.8.4.4
auth
crtscts
lock
name l2tpd
proxyarp
lcp-echo-interval 30
lcp-echo-failure 4
EOFPPP

cat > /etc/ppp/chap-secrets << EOFCHAP
"$L2TP_USER"    *    "$L2TP_PASS"    *
EOFCHAP

systemctl enable ipsec xl2tpd 2>/dev/null
systemctl restart ipsec
systemctl restart xl2tpd

if systemctl is-active ipsec >/dev/null && systemctl is-active xl2tpd >/dev/null; then
    log_info "L2TP/IPSec 启动成功"
else
    log_warn "L2TP/IPSec 可能启动失败，请检查日志"
fi
echo ""

# ==================== 7. 配置SOCKS5 ====================
log_step "步骤7: 配置 SOCKS5"
cat > /etc/danted.conf << EOFDANTED
logoutput: syslog
internal: 0.0.0.0 port = $BASE_SOCKS_PORT
external: $IFACE
socksmethod: username
clientmethod: none
user.privileged: root
user.unprivileged: nobody

client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  log: error
}

socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  command: bind connect udpassociate
  log: error
  socksmethod: username
}
EOFDANTED

if ! id "$SOCKS_USER" >/dev/null 2>&1; then
    useradd -M -s /sbin/nologin "$SOCKS_USER"
    echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd
fi

systemctl enable sockd 2>/dev/null
systemctl restart sockd

if systemctl is-active sockd >/dev/null; then
    log_info "SOCKS5 启动成功"
else
    log_warn "SOCKS5 可能启动失败，请检查日志"
fi
echo ""

# ==================== 8. 配置Shadowsocks ====================
log_step "步骤8: 配置 Shadowsocks（5个实例）"
mkdir -p /etc/shadowsocks-libev

ss_success=0
for i in "${!IP_LIST[@]}"; do
    ip="${IP_LIST[$i]}"
    port=$((BASE_SS_PORT + i))

    cat > /etc/shadowsocks-libev/config-$i.json << EOFSS
{
  "server": "$ip",
  "server_port": $port,
  "password": "$SS_PASS",
  "timeout": 300,
  "method": "$SS_METHOD",
  "fast_open": false
}
EOFSS

    cat > /etc/systemd/system/shadowsocks-libev@$i.service << EOFSERVICE
[Unit]
Description=Shadowsocks-Libev Server ($ip:$port)
After=network.target

[Service]
Type=simple
User=nobody
Group=nobody
LimitNOFILE=32768
Environment="LD_LIBRARY_PATH=/usr/local/lib"
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config-$i.json -u
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOFSERVICE

    systemctl daemon-reload
    systemctl enable shadowsocks-libev@$i 2>/dev/null
    systemctl restart shadowsocks-libev@$i

    sleep 1
    if systemctl is-active shadowsocks-libev@$i >/dev/null; then
        echo "  ✓ SS实例 $((i+1)): $ip:$port"
        ((ss_success++))
    else
        echo "  ✗ SS实例 $((i+1)): $ip:$port (启动失败)"
    fi
done

log_info "Shadowsocks: $ss_success/${#IP_LIST[@]} 个实例运行中"
echo ""

# ==================== 9. 生成配置文件 ====================
log_step "步骤9: 生成配置信息"
cat > /root/proxy_config.txt << EOFCONFIG
========================================
多IP代理服务器配置信息
========================================
部署时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器主IP: ${IP_LIST[0]}
总IP数: ${#IP_LIST[@]}

【L2TP/IPSec VPN】
- 协议: L2TP over IPSec
- 端口: UDP 500, 4500, 1701
- 用户名: $L2TP_USER
- 密码: $L2TP_PASS
- 预共享密钥(PSK): $PSK
- 支持IP: 所有 ${#IP_LIST[@]} 个IP均可连接

【SOCKS5 代理】
- 协议: SOCKS5
- 端口: TCP/UDP $BASE_SOCKS_PORT
- 用户名: $SOCKS_USER
- 密码: $SOCKS_PASS
- 支持IP: 所有 ${#IP_LIST[@]} 个IP均可连接

【Shadowsocks】
- 密码: $SS_PASS
- 加密方式: $SS_METHOD
- 服务器列表:
EOFCONFIG

for i in "${!IP_LIST[@]}"; do
    port=$((BASE_SS_PORT + i))
    echo "  服务器$((i+1)): ${IP_LIST[$i]}:$port" >> /root/proxy_config.txt
done

cat >> /root/proxy_config.txt << 'EOFCONFIG2'

========================================
小火箭(Shadowrocket)配置示例
========================================

【L2TP配置】
- 类型: L2TP
- 服务器: 选择任一IP
- 账号: vip1
- 密码: 111111
- 密钥: 111111

【SOCKS5配置】
- 类型: SOCKS5
- 服务器: 选择任一IP
- 端口: 18889
- 用户名: vip1
- 密码: 111111

【Shadowsocks配置】
- 类型: Shadowsocks
- 服务器: 对应IP
- 端口: 对应端口
- 密码: 111111
- 加密: chacha20-ietf-poly1305

========================================
管理命令
========================================

查看服务状态:
  systemctl status ipsec xl2tpd sockd
  systemctl status shadowsocks-libev@{0..4}

重启服务:
  systemctl restart ipsec xl2tpd sockd
  systemctl restart shadowsocks-libev@{0..4}

查看端口监听:
  netstat -tlnup | grep -E "1701|18889|2080"

查看IP绑定:
  ip addr show eth0

查看日志:
  journalctl -u ipsec -n 50
  journalctl -u shadowsocks-libev@0 -n 50

========================================
防火墙设置（如果需要）
========================================

firewall-cmd --permanent --add-port=500/udp
firewall-cmd --permanent --add-port=4500/udp
firewall-cmd --permanent --add-port=1701/udp
firewall-cmd --permanent --add-port=18889/tcp
firewall-cmd --permanent --add-port=18889/udp
firewall-cmd --permanent --add-port=2080-2084/tcp
firewall-cmd --reload

========================================
EOFCONFIG2

log_info "配置文件已保存到: /root/proxy_config.txt"
echo ""

# ==================== 10. 验证部署 ====================
log_step "步骤10: 验证部署结果"
echo ""
echo "【服务状态】"
systemctl is-active ipsec >/dev/null && echo "  ✓ IPSec 运行中" || echo "  ✗ IPSec 未运行"
systemctl is-active xl2tpd >/dev/null && echo "  ✓ XL2TPD 运行中" || echo "  ✗ XL2TPD 未运行"
systemctl is-active sockd >/dev/null && echo "  ✓ SOCKS5 运行中" || echo "  ✗ SOCKS5 未运行"

ss_running=0
for i in "${!IP_LIST[@]}"; do
    systemctl is-active shadowsocks-libev@$i >/dev/null && ((ss_running++))
done
echo "  ✓ Shadowsocks: $ss_running/${#IP_LIST[@]} 个实例运行中"

echo ""
echo "【端口监听】"
netstat -tlnup 2>/dev/null | grep -E ":1701|:18889|:2080" | awk '{print "  "$4}' | sort -u || echo "  (请手动检查)"

echo ""
echo "【IP绑定】"
for ip in "${IP_LIST[@]}"; do
    if ip addr show "$IFACE" | grep -q "$ip"; then
        echo "  ✓ $ip"
    else
        echo "  ✗ $ip (未绑定)"
    fi
done

echo ""
log_step "=========================================="
log_step "   部署完成！"
log_step "=========================================="
echo ""
log_info "📋 配置信息: cat /root/proxy_config.txt"
log_info "🔍 查看日志: journalctl -u shadowsocks-libev@0"
log_info "🔄 重启服务: systemctl restart shadowsocks-libev@{0..4}"
echo ""
log_warn "⚠️  请确保云服务商安全组已开放以下端口:"
echo "     UDP: 500, 4500, 1701 (L2TP/IPSec)"
echo "     TCP: 18889 (SOCKS5)"
echo "     TCP: 2080-2084 (Shadowsocks)"
echo ""
log_info "✅ 部署脚本执行完毕！"
echo ""
