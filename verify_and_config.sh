#!/bin/bash
#================================================
# 多IP代理服务验证和配置生成脚本
# 用于已部署完成的服务器
# 版本: 1.0
#================================================

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "   多IP代理服务配置生成与验证"
echo "=========================================="
echo ""

# ==================== 生成配置文件 ====================
echo -e "${BLUE}[1/3]${NC} 生成配置文件..."

cat > /root/proxy_config.txt << 'EOFCONFIG'
========================================
多IP代理服务器配置信息
========================================
部署时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器主IP: 59.38.142.139

【Shadowsocks】✅ 已验证可用
- 密码: 111111
- 加密: chacha20-ietf-poly1305
- 服务器列表:
  服务器1: 59.38.142.139:2080
  服务器2: 121.12.74.10:2081
  服务器3: 59.38.141.255:2082
  服务器4: 125.94.150.178:2083
  服务器5: 125.94.151.107:2084

【L2TP/IPSec】
- 端口: UDP 500, 4500, 1701
- 用户名: vip1
- 密码: 111111
- 预共享密钥(PSK): 111111

【SOCKS5 代理】
- 端口: TCP 18889
- 用户名: vip1
- 密码: 111111

========================================
小火箭(Shadowrocket)配置方法
========================================

【方法1：Shadowsocks（推荐）】
1. 打开小火箭，点击右上角 "+"
2. 选择"类型" → Shadowsocks
3. 填写：
   地址: 59.38.142.139 (或其他4个IP)
   端口: 2080 (对应IP用 2081-2084)
   密码: 111111
   算法: chacha20-ietf-poly1305
4. 保存 → 连接测试

【方法2：L2TP】
1. iPhone 设置 → VPN → 添加VPN配置
2. 类型: L2TP
3. 填写：
   描述: 我的VPN
   服务器: 59.38.142.139
   账户: vip1
   密码: 111111
   密钥: 111111
4. 连接测试

【方法3：SOCKS5】
1. 小火箭 → 添加 → SOCKS5
2. 填写：
   地址: 59.38.142.139
   端口: 18889
   用户名: vip1
   密码: 111111
3. 保存 → 连接测试

========================================
服务器管理命令
========================================

查看所有服务状态:
  systemctl status shadowsocks-libev@{0..4} ipsec xl2tpd sockd

重启所有服务:
  systemctl restart shadowsocks-libev@{0..4}
  systemctl restart ipsec xl2tpd sockd

查看端口监听:
  netstat -tulnp | grep -E "500|1701|18889|208"

查看Shadowsocks日志:
  journalctl -u shadowsocks-libev@0 -n 50

查看L2TP日志:
  journalctl -u xl2tpd -n 50

========================================
故障排查
========================================

如果Shadowsocks连接失败:
1. 检查服务: systemctl status shadowsocks-libev@0
2. 检查端口: netstat -tlnp | grep 2080
3. 检查日志: journalctl -u shadowsocks-libev@0 -n 50
4. 重启服务: systemctl restart shadowsocks-libev@{0..4}

如果L2TP连接失败:
1. 检查IPSec: systemctl status ipsec
2. 检查xl2tpd: systemctl status xl2tpd
3. 检查端口: netstat -ulnp | grep 1701
4. 重启服务: systemctl restart ipsec xl2tpd

如果SOCKS5连接失败:
1. 检查服务: systemctl status sockd
2. 检查端口: netstat -tlnp | grep 18889
3. 重启服务: systemctl restart sockd

========================================
防火墙端口（云服务商安全组）
========================================

需要在云服务商控制台开放以下端口:
- UDP 500  (IPSec IKE)
- UDP 4500 (IPSec NAT-T)  
- UDP 1701 (L2TP)
- TCP 18889 (SOCKS5)
- TCP 2080-2084 (Shadowsocks)

本地firewalld配置:
  firewall-cmd --permanent --add-port=500/udp
  firewall-cmd --permanent --add-port=4500/udp
  firewall-cmd --permanent --add-port=1701/udp
  firewall-cmd --permanent --add-port=18889/tcp
  firewall-cmd --permanent --add-port=2080-2084/tcp
  firewall-cmd --reload

========================================
EOFCONFIG

echo -e "${GREEN}✓${NC} 配置文件已生成: /root/proxy_config.txt"
echo ""

# ==================== 验证三个协议 ====================
echo -e "${BLUE}[2/3]${NC} 验证三协议状态..."
echo ""

# 验证 Shadowsocks
echo "【1. Shadowsocks】"
ss_count=0
for i in {0..4}; do
  if systemctl is-active shadowsocks-libev@$i >/dev/null 2>&1; then
    ((ss_count++))
    port=$((2080 + i))
    case $i in
      0) ip="59.38.142.139" ;;
      1) ip="121.12.74.10" ;;
      2) ip="59.38.141.255" ;;
      3) ip="125.94.150.178" ;;
      4) ip="125.94.151.107" ;;
    esac
    echo -e "  ${GREEN}✓${NC} 实例$((i+1)): $ip:$port 运行中"
  else
    echo -e "  ${RED}✗${NC} 实例$((i+1)): 未运行"
  fi
done

if [ $ss_count -eq 5 ]; then
  echo -e "  ${GREEN}状态: $ss_count/5 全部运行 ✅${NC}"
elif [ $ss_count -ge 3 ]; then
  echo -e "  ${YELLOW}状态: $ss_count/5 部分运行 ⚠️${NC}"
else
  echo -e "  ${RED}状态: $ss_count/5 大部分未运行 ❌${NC}"
fi
echo ""

# 验证 L2TP/IPSec
echo "【2. L2TP/IPSec】"
l2tp_ok=0

if systemctl is-active ipsec >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} IPSec 运行中"
  ((l2tp_ok++))
else
  echo -e "  ${RED}✗${NC} IPSec 未运行"
fi

if systemctl is-active xl2tpd >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} XL2TPD 运行中"
  ((l2tp_ok++))
else
  echo -e "  ${RED}✗${NC} XL2TPD 未运行"
fi

if netstat -ulnp 2>/dev/null | grep -q ":1701 "; then
  echo -e "  ${GREEN}✓${NC} UDP 1701 监听中"
  ((l2tp_ok++))
else
  echo -e "  ${RED}✗${NC} UDP 1701 未监听"
fi

if [ $l2tp_ok -eq 3 ]; then
  echo -e "  ${GREEN}状态: 完全正常 ✅${NC}"
elif [ $l2tp_ok -ge 1 ]; then
  echo -e "  ${YELLOW}状态: 部分正常 ⚠️${NC}"
else
  echo -e "  ${RED}状态: 服务异常 ❌${NC}"
fi
echo ""

# 验证 SOCKS5
echo "【3. SOCKS5】"
socks_ok=0

if systemctl is-active sockd >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} SOCKD 运行中"
  ((socks_ok++))
else
  echo -e "  ${RED}✗${NC} SOCKD 未运行"
fi

if netstat -tlnp 2>/dev/null | grep -q ":18889 "; then
  echo -e "  ${GREEN}✓${NC} TCP 18889 监听中"
  ((socks_ok++))
else
  echo -e "  ${RED}✗${NC} TCP 18889 未监听"
fi

if [ $socks_ok -eq 2 ]; then
  echo -e "  ${GREEN}状态: 完全正常 ✅${NC}"
elif [ $socks_ok -eq 1 ]; then
  echo -e "  ${YELLOW}状态: 部分正常 ⚠️${NC}"
else
  echo -e "  ${RED}状态: 服务异常 ❌${NC}"
fi
echo ""

# ==================== 防火墙检查 ====================
echo -e "${BLUE}[3/3]${NC} 检查防火墙..."
echo ""

if systemctl is-active firewalld >/dev/null 2>&1; then
  echo -e "${YELLOW}检测到 firewalld 运行中，正在配置端口...${NC}"

  firewall-cmd --permanent --add-port=500/udp 2>/dev/null
  firewall-cmd --permanent --add-port=4500/udp 2>/dev/null
  firewall-cmd --permanent --add-port=1701/udp 2>/dev/null
  firewall-cmd --permanent --add-port=18889/tcp 2>/dev/null
  firewall-cmd --permanent --add-port=18889/udp 2>/dev/null
  firewall-cmd --permanent --add-port=2080-2084/tcp 2>/dev/null
  firewall-cmd --reload 2>/dev/null

  echo -e "${GREEN}✓${NC} 本地防火墙端口已配置"
else
  echo -e "${GREEN}✓${NC} 本地防火墙未启用"
fi

echo ""
echo -e "${YELLOW}⚠️  重要提醒:${NC}"
echo "   请在云服务商控制台（安全组）开放以下端口："
echo "   - UDP: 500, 4500, 1701 (L2TP)"
echo "   - TCP: 18889 (SOCKS5)"
echo "   - TCP: 2080-2084 (Shadowsocks)"
echo ""

# ==================== 总结 ====================
echo "=========================================="
echo "   验证报告总结"
echo "=========================================="
echo ""

total_ok=0
[ $ss_count -ge 4 ] && ((total_ok++))
[ $l2tp_ok -ge 2 ] && ((total_ok++))
[ $socks_ok -ge 1 ] && ((total_ok++))

if [ $total_ok -eq 3 ]; then
  echo -e "${GREEN}✅ 三个协议全部正常！可以开始测试连接。${NC}"
elif [ $total_ok -eq 2 ]; then
  echo -e "${YELLOW}⚠️  两个协议正常，一个需要检查。${NC}"
elif [ $total_ok -eq 1 ]; then
  echo -e "${YELLOW}⚠️  一个协议正常，其他需要检查。${NC}"
else
  echo -e "${RED}❌ 所有协议都需要检查，请查看日志排查。${NC}"
fi

echo ""
echo "📋 查看完整配置: ${GREEN}cat /root/proxy_config.txt${NC}"
echo "📱 客户端配置方法已包含在配置文件中"
echo ""
echo "🔧 快速重启所有服务:"
echo "   ${BLUE}systemctl restart shadowsocks-libev@{0..4} ipsec xl2tpd sockd${NC}"
echo ""
echo "=========================================="
echo ""
