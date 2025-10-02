#!/bin/bash
# deploy_all_v2.sh
# 多IP代理服务一键部署脚本（带验证功能）
# 版本: 2.0
# 更新: 2025-10-02

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

# 新服务器的5个IP地址
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

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# 取默认网卡
IFACE=$(ip route | awk '/default/ {print $5; exit}')

# ==================== 部署前验证 ====================
pre_deployment_check() {
  log_step "==============================================="
  log_step "         部署前环境检查"
  log_step "==============================================="
  echo ""

  log_info "系统信息："
  echo "  操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
  echo "  内核版本: $(uname -r)"
  echo "  网卡设备: $IFACE"
  echo ""

  log_info "当前IP配置："
  ip -4 addr show $IFACE | grep "inet " | awk '{print "  " $2}'
  echo ""

  log_info "检查必要命令是否存在："
  local missing_cmds=()
  for cmd in yum systemctl ip iptables; do
    if command -v $cmd >/dev/null 2>&1; then
      echo "  ✓ $cmd"
    else
      echo "  ✗ $cmd (缺失)"
      missing_cmds+=($cmd)
    fi
  done

  if [ ${#missing_cmds[@]} -gt 0 ]; then
    log_error "缺少必要命令，无法继续"
    exit 1
  fi
  echo ""

  log_info "IP地址列表（共 ${#IP_LIST[@]} 个）："
  for i in "${!IP_LIST[@]}"; do
    if [ $i -eq 0 ]; then
      echo "  IP$((i+1)): ${IP_LIST[$i]} (主IP)"
    else
      echo "  IP$((i+1)): ${IP_LIST[$i]}"
    fi
  done
  echo ""

  log_warn "准备开始部署，请确认以上信息无误"
  read -p "按回车继续，或 Ctrl+C 取消..."
  echo ""
}

# ==================== 安装依赖 ====================
install_dependencies() {
  log_step "安装依赖包..."

  # 安装 EPEL 源
  yum install -y epel-release

  # 添加 Shadowsocks 源
  if [ ! -f /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo ]; then
    curl -o /etc/yum.repos.d/librehat-shadowsocks-epel-7.repo \
      https://copr.fedorainfracloud.org/coprs/librehat/shadowsocks/repo/epel-7/librehat-shadowsocks-epel-7.repo \
      2>/dev/null || log_warn "Shadowsocks 官方源添加失败，尝试使用系统源"
  fi

  # 安装所有依赖
  yum install -y wget curl ppp libreswan xl2tpd iptables-services \
                 dante-server shadowsocks-libev net-tools

  if [ $? -eq 0 ]; then
    log_info "依赖包安装成功 ✓"
  else
    log_error "依赖包安装失败"
    exit 1
  fi
  echo ""
}

# ==================== 配置多IP ====================
configure_multi_ip() {
  log_step "配置多IP绑定..."

  local success=0
  local failed=0

  for i in "${!IP_LIST[@]}"; do
    [ $i -eq 0 ] && continue  # 跳过主IP

    ip="${IP_LIST[$i]}"
    echo -n "  绑定 $ip ... "

    if ip addr add "$ip/24" dev "$IFACE" 2>/dev/null; then
      echo -e "${GREEN}成功${NC}"
      ((success++))
    else
      # 检查是否已存在
      if ip addr show "$IFACE" | grep -q "$ip"; then
        echo -e "${YELLOW}已存在${NC}"
        ((success++))
      else
        echo -e "${RED}失败${NC}"
        ((failed++))
      fi
    fi
  done

  echo ""
  log_info "IP绑定结果: 成功 $success, 失败 $failed"

  # 验证绑定
  echo ""
  log_info "验证IP绑定状态："
  for i in "${!IP_LIST[@]}"; do
    ip="${IP_LIST[$i]}"
    if ip addr show "$IFACE" | grep -q "$ip"; then
      echo "  ✓ $ip"
    else
      echo "  ✗ $ip (未绑定)"
    fi
  done
  echo ""
}

# ==================== L2TP/IPSec 配置 ====================
configure_l2tp() {
  log_step "配置 L2TP/IPSec..."

  # IPSec 配置
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
  pfs=no
  rekey=no
  keyingtries=3
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
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

  # 启动服务
  systemctl enable ipsec xl2tpd 2>/dev/null
  systemctl restart ipsec
  systemctl restart xl2tpd

  sleep 2

  if systemctl is-active ipsec >/dev/null && systemctl is-active xl2tpd >/dev/null; then
    log_info "L2TP/IPSec 服务启动成功 ✓"
  else
    log_warn "L2TP/IPSec 服务启动可能有问题"
  fi
  echo ""
}

# ==================== SOCKS5 配置 ====================
configure_socks5() {
  log_step "配置 SOCKS5..."

  cat > /etc/danted.conf << EOF
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
EOF

  # 创建SOCKS5用户（使用系统用户认证）
  if ! id "$SOCKS_USER" >/dev/null 2>&1; then
    useradd -M -s /sbin/nologin "$SOCKS_USER"
    echo "$SOCKS_USER:$SOCKS_PASS" | chpasswd
  fi

  # 启动服务
  systemctl enable sockd 2>/dev/null
  systemctl restart sockd

  sleep 2

  if systemctl is-active sockd >/dev/null; then
    log_info "SOCKS5 服务启动成功 ✓"
  else
    log_warn "SOCKS5 服务启动可能有问题"
  fi
  echo ""
}

# ==================== Shadowsocks 配置 ====================
configure_shadowsocks() {
  log_step "配置 Shadowsocks..."

  mkdir -p /etc/shadowsocks-libev

  local success=0
  local failed=0

  for i in "${!IP_LIST[@]}"; do
    ip="${IP_LIST[$i]}"
    port=$((BASE_SS_PORT + i))

    # 创建配置文件
    cat > /etc/shadowsocks-libev/config-$i.json << EOF
{
  "server": "$ip",
  "server_port": $port,
  "password": "$SS_PASS",
  "timeout": 300,
  "method": "$SS_METHOD",
  "fast_open": false,
  "workers": 1
}
EOF

    # 创建 systemd 服务
    cat > /etc/systemd/system/shadowsocks-libev@$i.service << EOF
[Unit]
Description=Shadowsocks-Libev Server ($ip:$port)
After=network.target

[Service]
Type=simple
User=nobody
Group=nobody
LimitNOFILE=32768
ExecStart=/usr/bin/ss-server -c /etc/shadowsocks-libev/config-$i.json -u
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable shadowsocks-libev@$i 2>/dev/null
    systemctl restart shadowsocks-libev@$i

    sleep 1

    if systemctl is-active shadowsocks-libev@$i >/dev/null; then
      echo "  ✓ SS实例 $((i+1)): $ip:$port"
      ((success++))
    else
      echo "  ✗ SS实例 $((i+1)): $ip:$port (启动失败)"
      ((failed++))
    fi
  done

  echo ""
  log_info "Shadowsocks 启动结果: 成功 $success/${#IP_LIST[@]}, 失败 $failed"
  echo ""
}

# ==================== 部署后验证 ====================
post_deployment_verify() {
  log_step "==============================================="
  log_step "         部署后验证"
  log_step "==============================================="
  echo ""

  log_info "1. 服务状态检查："

  # 检查 L2TP
  if systemctl is-active ipsec >/dev/null 2>&1; then
    echo "  ✓ IPSec: 运行中"
  else
    echo "  ✗ IPSec: 未运行"
  fi

  if systemctl is-active xl2tpd >/dev/null 2>&1; then
    echo "  ✓ XL2TPD: 运行中"
  else
    echo "  ✗ XL2TPD: 未运行"
  fi

  # 检查 SOCKS5
  if systemctl is-active sockd >/dev/null 2>&1; then
    echo "  ✓ SOCKS5: 运行中"
  else
    echo "  ✗ SOCKS5: 未运行"
  fi

  # 检查 Shadowsocks
  local ss_count=0
  for i in "${!IP_LIST[@]}"; do
    if systemctl is-active shadowsocks-libev@$i >/dev/null 2>&1; then
      ((ss_count++))
    fi
  done
  echo "  ✓ Shadowsocks: $ss_count/${#IP_LIST[@]} 个实例运行中"

  echo ""
  log_info "2. 端口监听检查："

  # 检查 L2TP 端口
  if netstat -ulnp 2>/dev/null | grep -q ":1701 "; then
    echo "  ✓ UDP 1701 (L2TP)"
  else
    echo "  ✗ UDP 1701 未监听"
  fi

  if netstat -ulnp 2>/dev/null | grep -q ":500 "; then
    echo "  ✓ UDP 500 (IPSec)"
  else
    echo "  ✗ UDP 500 未监听"
  fi

  # 检查 SOCKS5 端口
  if netstat -tlnp 2>/dev/null | grep -q ":$BASE_SOCKS_PORT "; then
    echo "  ✓ TCP $BASE_SOCKS_PORT (SOCKS5)"
  else
    echo "  ✗ TCP $BASE_SOCKS_PORT 未监听"
  fi

  # 检查 Shadowsocks 端口
  local ss_port_count=0
  for i in "${!IP_LIST[@]}"; do
    port=$((BASE_SS_PORT + i))
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
      ((ss_port_count++))
    fi
  done
  echo "  ✓ Shadowsocks: $ss_port_count/${#IP_LIST[@]} 个端口监听中"

  echo ""
  log_info "3. IP绑定验证："
  for ip in "${IP_LIST[@]}"; do
    if ip addr show "$IFACE" | grep -q "$ip"; then
      echo "  ✓ $ip"
    else
      echo "  ✗ $ip (未绑定)"
    fi
  done

  echo ""
}

# ==================== 生成配置文件 ====================
generate_config_summary() {
  log_step "生成配置信息文件..."

  local config_file="/root/proxy_config_info.txt"

  cat > "$config_file" << EOF
======================================================
       多IP代理服务器配置信息
======================================================
生成时间: $(date)
服务器IP: ${IP_LIST[0]} (主IP)
IP总数: ${#IP_LIST[@]}

======================================================
1. L2TP/IPSec VPN
======================================================
协议: L2TP over IPSec
端口: UDP 500, 4500, 1701
用户名: $L2TP_USER
密码: $L2TP_PASS
预共享密钥(PSK): $PSK

支持的IP地址: 所有 ${#IP_LIST[@]} 个IP均可连接

======================================================
2. SOCKS5 代理
======================================================
协议: SOCKS5
端口: TCP/UDP $BASE_SOCKS_PORT
用户名: $SOCKS_USER
密码: $SOCKS_PASS

支持的IP地址: 所有 ${#IP_LIST[@]} 个IP均可连接

======================================================
3. Shadowsocks
======================================================
协议: Shadowsocks
密码: $SS_PASS
加密方式: $SS_METHOD

服务器列表:
EOF

  for i in "${!IP_LIST[@]}"; do
    port=$((BASE_SS_PORT + i))
    echo "  服务器$((i+1)): ${IP_LIST[$i]}:$port" >> "$config_file"
  done

  cat >> "$config_file" << EOF

======================================================
小火箭(Shadowrocket)配置指南
======================================================

L2TP配置:
- 类型: L2TP
- 服务器: 任选一个IP
- 账号: $L2TP_USER
- 密码: $L2TP_PASS
- 密钥: $PSK

SOCKS5配置:
- 类型: SOCKS5
- 服务器: 任选一个IP
- 端口: $BASE_SOCKS_PORT
- 用户名: $SOCKS_USER
- 密码: $SOCKS_PASS

Shadowsocks配置:
- 类型: Shadowsocks
- 服务器: 对应IP
- 端口: 对应端口
- 密码: $SS_PASS
- 加密: $SS_METHOD

======================================================
管理命令
======================================================

查看服务状态:
  systemctl status ipsec xl2tpd sockd
  systemctl status shadowsocks-libev@{0..4}

重启服务:
  systemctl restart ipsec xl2tpd sockd
  systemctl restart shadowsocks-libev@{0..4}

查看端口监听:
  netstat -tlnup | grep -E "1701|500|$BASE_SOCKS_PORT|$BASE_SS_PORT"

查看IP绑定:
  ip addr show $IFACE

查看日志:
  journalctl -u ipsec -f
  journalctl -u xl2tpd -f
  journalctl -u sockd -f
  journalctl -u shadowsocks-libev@0 -f

======================================================
故障排查
======================================================

1. 服务无法启动:
   - 检查日志: journalctl -xe
   - 检查端口占用: netstat -tlnup

2. 客户端无法连接:
   - 检查服务器防火墙
   - 检查云服务商安全组规则
   - 验证IP地址是否正确绑定

3. IP绑定失败:
   - 确认IP在云控制台已分配
   - 检查网络配置: ip addr show
   - 手动绑定测试: ip addr add <IP>/24 dev $IFACE

======================================================
EOF

  log_info "配置文件已保存到: $config_file"
  echo ""

  # 显示配置摘要
  log_info "配置摘要:"
  echo "  L2TP用户: $L2TP_USER / $L2TP_PASS"
  echo "  SOCKS5: 端口 $BASE_SOCKS_PORT"
  echo "  Shadowsocks: 端口 $BASE_SS_PORT-$((BASE_SS_PORT + ${#IP_LIST[@]} - 1))"
  echo "  详细信息请查看: $config_file"
  echo ""
}

# ==================== 主函数 ====================
main() {
  echo ""
  echo "=========================================================="
  echo "         多IP代理服务器一键部署脚本 v2.0"
  echo "=========================================================="
  echo ""

  # 检查root权限
  if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要root权限运行"
    echo "请使用: sudo bash $0"
    exit 1
  fi

  # 部署前检查
  pre_deployment_check

  # 安装依赖
  install_dependencies

  # 配置多IP
  configure_multi_ip

  # 配置各项服务
  configure_l2tp
  configure_socks5
  configure_shadowsocks

  # 部署后验证
  post_deployment_verify

  # 生成配置文件
  generate_config_summary

  echo ""
  log_step "=========================================================="
  log_step "         部署完成！"
  log_step "=========================================================="
  echo ""
  log_info "下一步操作:"
  echo "  1. 查看配置信息: cat /root/proxy_config_info.txt"
  echo "  2. 检查服务状态: systemctl status ipsec xl2tpd sockd"
  echo "  3. 配置客户端连接"
  echo ""
  log_warn "请确保云服务器安全组已开放以下端口:"
  echo "  - UDP: 500, 4500, 1701 (L2TP/IPSec)"
  echo "  - TCP: $BASE_SOCKS_PORT (SOCKS5)"
  echo "  - TCP: $BASE_SS_PORT-$((BASE_SS_PORT + ${#IP_LIST[@]} - 1)) (Shadowsocks)"
  echo ""
}

# 执行主函数
main
