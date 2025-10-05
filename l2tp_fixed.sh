#!/bin/bash

#Check System
source /etc/os-release

system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        sysA=$(more /etc/redhat-release | awk '{print $1$4}' |cut -c1-9)
        # if [ "$sysA" != "CentOS7.6" ]; then
        #     if [ "$sysA" != "CentOS8.2" ]; then
        #         echo "请将云服务器的系统版本切换成CentOS 7.6 或者 Ubuntu 22.04 再尝试运行代码。"
        #         exit 1
        #     fi
        # fi
        INS="yum"
rm -rf /etc/yum.repos.d/* 
curl -O http://8.138.120.72/kuyuan/epel.repo 
mv epel.repo /etc/yum.repos.d/ 
curl -O http://8.138.120.72/kuyuan/CentOS7-ctyun.repo 
mv CentOS7-ctyun.repo /etc/yum.repos.d/ 
curl -O http://8.138.120.72/kuyuan/epel-testing.repo 
mv epel-testing.repo /etc/yum.repos.d/ 
curl -O http://mirrors.aliyun.com/epel/RPM-GPG-KEY-EPEL-7 
mv RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/
        $INS update
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        INS="apt"
        $INS update -y >/dev/null 2>&1
        mkdir -p /etc/rc.d/init.d
    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 18 ]]; then
        INS="apt"
        $INS update -y >/dev/null 2>&1
        mkdir -p /etc/rc.d/init.d
    else
        echo -e "${Red}目前仅支持Centos 7+，Debian 9+，Ubuntu 18+系统，安装退出${Font}"
        exit 1
    fi
}

system

quickhttp() {
    ping1=$(ping -c 1 www.bt.cn | grep "time=" | awk '{print $7}' | cut -f2 -d=)
    ping2=$(ping -c 1 ipv4.icanhazip.com | grep "time=" | awk '{print $7}' | cut -f2 -d=)
    ping3=$(ping -c 1 ifconfig.me | grep "time=" | awk '{print $7}' | cut -f2 -d=)

    if [ -n "$ping1" ]; then
        num1=$ping1
    else
        num1=500
    fi

    if [ -n "$ping2" ]; then
        num2=$ping2
    else
        num2=600
    fi

    if [ -n "$ping3" ]; then
        num3=$ping3
    else
        num3=700
    fi

    if (( $(echo "$num1 < $num2" | bc -l) )); then
        if (( $(echo "$num1 < $num3" | bc -l) )); then
            min="num1"
            Ahttp=https://www.bt.cn/api/getipaddress
            if (( $(echo "$num2 < $num3" | bc -l) )); then
                mid="num2"
                Bhttp=ipv4.icanhazip.com
                max="num3"
                Chttp=https://ifconfig.me/ip
            else
                mid="num3"
                Bhttp=https://ifconfig.me/ip
                max="num2"
                Chttp=ipv4.icanhazip.com
            fi
        else
            min="num3"
            Ahttp=https://ifconfig.me/ip
            mid="num1"
            Bhttp=https://www.bt.cn/api/getipaddress
            max="num2"
            Chttp=ipv4.icanhazip.com
        fi
    else
        if (( $(echo "$num2 < $num3" | bc -l) )); then
            min="num2"
            Ahttp=ipv4.icanhazip.com
            if (( $(echo "$num1 < $num3" | bc -l) )); then
                mid="num1"
                Bhttp=https://www.bt.cn/api/getipaddress
                max="num3"
                Chttp=https://ifconfig.me/ip
            else
                mid="num3"
                Bhttp=https://ifconfig.me/ip
                max="num1"
                Chttp=https://www.bt.cn/api/getipaddress
            fi
        else
            min="num3"
            Ahttp=https://ifconfig.me/ip
            mid="num2"
            Bhttp=ipv4.icanhazip.com
            max="num1"
            Chttp=https://www.bt.cn/api/getipaddress
        fi
    fi
}

# Color variables
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"

# Check motd and determine begin values
if [ -e /etc/motd ]; then
    if grep -q "Huawei" /etc/motd; then
        begin1=11
        begin2=12
    elif grep -q "Alibaba" /etc/motd; then
        touch ip.txt
    elif [ "$(dmidecode -s system-Manufacturer | awk '{print $1}')" == "Tencent" ]; then
        touch ip.txt
    elif [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "OpenStack" ]; then
        begin1=11
        begin2=19
    elif [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "GoStack" ]; then
        begin1=11
        begin2=19
    elif [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "Gostack" ]; then
        begin1=11
        begin2=19
    else
        touch ip.txt
    fi
else
    if [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "OpenStack" ]; then
        begin1=11
        begin2=19
    elif [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "GoStack" ]; then
        begin1=11
        begin2=19
    elif [ "$(dmidecode -t 1 | grep 'Product Name:'| awk '{print $3}')" == "Gostack" ]; then
        begin1=11
        begin2=19
    else
        touch ip.txt
    fi
fi

# Display ads
clear
adsyx=$(cat <<EOF
|
|              一键映射 多弹性IP/虚拟子网设置 作为 本机L2TP拔号服务         
|  步骤：服务器后台预先申请好弹性IP，脚本将从本机第一条为10开始+1的内网号IP开始映射9次
|
EOF
)
if [ "$adsyx" != "" ]; then
    echo -e "-----------------------------------------------------------------------------"
    echo -e "${Green_font_prefix}$adsyx${Font_color_suffix}"
    echo -e "-----------------------------------------------------------------------------"
fi

echo "一键脚本正在执行中，预计用时3-5分钟，请耐心等待。"

# Install required packages
$INS install -y epel-release
$INS install -y xl2tpd lsof

# Get IP address segments
Aduan=$(ip addr show | grep inet | grep -v inet6 | awk '{print $2}' | awk -F'.' '$1 != "127" {print $1}' | head -1)
Bduan=$(ip addr show | grep inet | grep -v inet6 | awk '{print $2}' | awk -F'.' '$1 != "127" {print $2}' | head -1)
Cduan=$(ip addr show | grep inet | grep -v inet6 | awk '{print $2}' | awk -F'.' '$1 != "127" {print $3}' | head -1)

# Get first IP address
zhengduan=$(ip a | grep -o -e 'inet [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' | grep -v "127.0.0" | awk '{print $2}' | head -n 1)

# Set virtual IP
virtual_ip="${zhengduan}"

echo "服务器主子网IP地址为: $virtual_ip"

# Handle IP file creation
if [ ! -e /root/ip.txt ]; then
    echo "$zhengduan" > ip.txt
    
    for ((i=begin1;i<=begin2;i++)); do
        echo "${Aduan}.${Bduan}.${Cduan}.${i}" >> ip.txt
    done
    
    echo "已生成从${Aduan}.${Bduan}.${Cduan}.${begin1}到${Aduan}.${Bduan}.${Cduan}.${begin2}的连续IP地址，请确保你在后台添加的子网IP地址是从${begin1}到${begin2}。"
    
    mask=255.255.255.0
else
    if [ $(du -b /root/ip.txt | awk '{print $1}') -gt 0 ]; then
        sed -i '1i\'$virtual_ip'' ip.txt
    else
        echo "$zhengduan" > ip.txt
    fi
    awk '!seen[$0]++' ip.txt > tempfile.txt && mv tempfile.txt ip.txt
fi

# Clean up and prepare environment
rm -f /etc/rc.d/init.d/mask.sh

# Install required packages if not present
if [ ! -e /usr/bin/curl ]; then
    $INS install -y curl
fi

if [ ! -e "/usr/bin/bc" ]; then
    $INS install -y bc
fi

if [ ! -e /usr/bin/mkpasswd ]; then
    $INS install -y expect
fi

if [ ! -e /usr/bin/expr ]; then
    $INS install -y coreutils
fi

if [ ! -e /dev/random ]; then
    mknod /dev/random c 1 9
fi

# Check for ip.txt
if [ ! -e ./ip.txt ]; then
    echo "ip.txt ip文件不存在"
    exit
fi

# Configure yum and system settings
yum_start() {
    cp -pf /etc/sysctl.conf /etc/sysctl.conf.bak
    echo "# Added by pptp VPN" >> /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_ignore_bogus_error_responses=1" >> /etc/sysctl.conf
    
    for each in `ls /proc/sys/net/ipv4/conf/`; do
        echo "net.ipv4.conf.${each}.accept_source_route=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.accept_redirects=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.send_redirects=0" >> /etc/sysctl.conf
        echo "net.ipv4.conf.${each}.rp_filter=0" >> /etc/sysctl.conf
    done
    
    nohup sysctl -p >/dev/null 2>&1 &
    sleep 3
}

# Execute main functions
yum_start
quickhttp

# Configure mask.sh if not exists
if [ ! -e /etc/rc.d/init.d/mask.sh ]; then
    cat /dev/null > /etc/rc.d/init.d/mask.sh
    
    cat << EOF > /etc/rc.d/init.d/mask.sh
#!/bin/bash
# chkconfig
# chkconfig: 2345 80 90
#decription:autostart
EOF
    
    chmod +x /etc/rc.d/init.d/mask.sh
    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        chkconfig --add mask.sh
    else
        echo "/etc/rc.d/init.d/mask.sh" >> /etc/rc.local
        chmod +x /etc/rc.local
    fi
    

echo "----------------------------------------"    
    start=1
    
    sed 1d ip.txt | while read line || [[ -n ${line} ]]; do
        echo "正在创建虚拟IP $line"
        ifconfig eth0:$start $line netmask $mask up
        echo "ifconfig eth0:$start $line netmask $mask up" >> /etc/rc.d/init.d/mask.sh
        start=`expr $start + 1`
    done
fi

# Collect and process IP addresses
ip -4 a | grep -v eth0 | grep inet | grep -v "127.0.0.1" | grep -v "172.17.0.1" | awk '{print $2,$NF}' | sed "s/\/[0-9]\{1,2\}//g" | awk '{print $1}' >> ip.txt
sleep 3

# Update IP file
sed -i "1i\\$Lip" ip.txt
awk '!seen[$0]++' ip.txt > tempfile.txt && mv tempfile.txt ip.txt

# Add dynamic route tables function
add_dynamic_route_tables() {
    local start_id=101
    local table_id=$start_id
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep '^eth')
    
    for iface in $interfaces; do
        table_name="${iface}_table"
        if ! grep -q "$table_name" /etc/iproute2/rt_tables; then
            echo "$table_id $table_name" >> /etc/iproute2/rt_tables
        else
            table_id=$(grep "$table_name" /etc/iproute2/rt_tables | awk '{print $1}')
        fi
        table_id=$((table_id + 1))
    done
}

add_dynamic_route_tables

# Add dynamic route function
add_dynamic_route() {
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep '^eth')
    existing_ips=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')
    eth0_gateway=$(ip route show dev eth0 | grep -oP '(?<=via\s)\d+\.\d+\.\d+\.\d+' | head -1)
    
    for iface in $interfaces; do
        ip_addr=$(ip -4 addr show $iface | grep -v "secondary" | grep -v "eth0:" | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+')
        if [[ -n $ip_addr ]]; then
            table_id=$(grep "${iface}_table" /etc/iproute2/rt_tables | awk '{print $1}')
            if [ -n "$table_id" ]; then
                if ! ip rule show | grep -q "from $ip_addr"; then
                    ip rule add from $ip_addr table $table_id || echo "添加路由规则失败，检查表 ID 是否有效"
                fi
                if ! grep -q "ip rule add from $ip_addr table $table_id" /etc/rc.d/init.d/mask.sh; then
                    echo "ip rule add from $ip_addr table $table_id" >> /etc/rc.d/init.d/mask.sh
                fi
            else
                echo "未找到有效的表 ID，跳过..."
            fi
            
            if [ "$iface" != "eth0" ]; then
                if ! ip route show table $table_id | grep -q "default via $eth0_gateway"; then
                    ip route add default via $eth0_gateway dev $iface table $table_id || echo "添加默认路由失败，检查表 ID 是否有效"
                fi
                if ! grep -q "ip route add default via $eth0_gateway dev $iface table $table_id" /etc/rc.d/init.d/mask.sh; then
                    echo "ip route add default via $eth0_gateway dev $iface table $table_id" >> /etc/rc.d/init.d/mask.sh
                fi
            fi
        else
            echo "$iface 未找到有效的网卡IP 地址，跳过..."
        fi
    done
}

add_dynamic_route

# Get available network IPs
echo "正在获取可联网IP"
start3=0

while read line; do
    public_ip1=`curl -s --connect-timeout 5 --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Ahttp`
    
    if [ -z "$public_ip1" ]; then
        public_ip1=`curl -s --connect-timeout 5 --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Bhttp`
    fi
    
    if [ -z "$public_ip1" ]; then
        public_ip1=`curl -s --connect-timeout 5 --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Chttp`
    fi
    
    if [ ! -z "$public_ip1" ]; then
        echo $line >> system_ip.txt
        start3=`expr $start3 + 1`
        echo "已获取第 $start3 条可联网IP"
    fi
done < ip.txt

echo "共获取 $start3 条IP，若与弹性IP数量不符，请检查虚拟IP是否按要求配置"
echo "----------------------------------------"

# Clean up duplicates in system_ip.txt
awk '!seen[$0]++' system_ip.txt > tempfile.txt && mv tempfile.txt system_ip.txt

# Remove current script
rm -f $0

# Set PATH
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Root check function
rootness() {
    if [[ $EUID -ne 0 ]]; then
        echo "必须使用root账号运行!" 1>&2
        exit 1
    fi
}

# TUN device check function
tunavailable() {
    if [[ ! -e /dev/net/tun ]]; then
        echo "TUN/TAP设备不可用!" 1>&2
        exit 1
    fi
}

# SELinux disable function
disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Get OS info function
get_os_info() {
    IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^192\.169|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
    [ -z ${IP} ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    if [ -z ${IP} ]; then
        IP=$(wget -qO- -t1 -T2 https://ifconfig.me/ip)
    fi
    if [ -z ${IP} ]; then
        IP=$(wget -qO- -t1 -T2 https://www.bt.cn/api/getipaddress)
    fi
}

# Random string generator function
rand() {
    index=0
    str=""
    for i in {a..z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {A..Z}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {0..9}; do arr[index]=${i}; index=`expr ${index} + 1`; done
    for i in {1..10}; do str="$str${arr[$RANDOM%$index]}"; done
    echo ${str}
}

# L2TP preinstall function
preinstall_l2tp() {
    if [ -d "/proc/vz" ]; then
        echo -e "\033[41;37m WARNING: \033[0m Your VPS is based on OpenVZ, and IPSec might not be supported by the kernel."
        echo "Continue installation? (y/n)"
        read -p "(Default: n)" agree
        [ -z ${agree} ] && agree="n"
        if [ "${agree}" == "n" ]; then
            echo
            echo "L2TP installation cancelled."
            echo
            exit 0
        fi
    fi
    
    # Fixed interaction information
    iprange="172.16.0"
    mypsk="111111"
}

# L2TP installation function
install_l2tp() {
    $INS install -y ppp libreswan iptables iptables-services
    yum_install
}

# Configuration installation function
config_install() {
    cat > /etc/ipsec.conf<<EOF
version 2.0

config setup
    protostack=netkey
    nhelpers=0
    uniqueids=no
#    interfaces=%defaultroute
    virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:!${iprange}.0/24

conn l2tp-psk
    rightsubnet=vhost:%priv
    also=l2tp-psk-nonat

conn l2tp-psk-nonat
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%any
#    leftid=${IP}
    leftprotoport=17/1701
    right=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
    sha2-truncbug=yes
EOF

    cat > /etc/ipsec.secrets<<EOF
%any %any : PSK "${mypsk}"
EOF

    cat > /etc/xl2tpd/xl2tpd.conf<<EOF
[global]
ipsec saref = yes
listen-addr = 0.0.0.0
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

    cat > /etc/ppp/options.xl2tpd<<EOF
ipcp-accept-local
ipcp-accept-remote
require-mschap-v2
ms-dns 119.29.29.29
ms-dns 223.5.5.5
noccp
auth
hide-password
idle 1800
mtu 1400
mru 1400
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF

    cat >> /etc/ppp/chap-secrets<<EOF
# Secrets for authentication using CHAP
# client    server    secret    IP addresses
EOF

    sed -i '/l2tpd/d' /etc/ppp/chap-secrets
}

# Yum installation function
yum_install() {
    config_install
    systemctl enable ipsec
    systemctl enable xl2tpd
    systemctl restart ipsec
    systemctl restart xl2tpd
}

# Final setup function
finally() {
    echo "验证安装"
    ipsec verify
    systemctl stop firewalld
    systemctl disable firewalld
    systemctl start iptables
    systemctl enable iptables
    echo "安装完成"
}

# L2TP main function
l2tp() {
    echo "开始安装"
    rootness
    tunavailable
    disable_selinux
    get_os_info
    preinstall_l2tp
    install_l2tp
    finally
}

# SELinux configuration
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi

# Install required packages
if [ ! -e "/usr/bin/wget" ]; then
    $INS install -y wget >/dev/null 2>&1
fi

if [ ! -e "/usr/bin/netstat" ]; then
    $INS install -y net-tools >/dev/null 2>&1
fi

if [ ! -e /usr/bin/mkpasswd ]; then
    $INS install -y expect >/dev/null 2>&1
fi

if [ ! -e /usr/bin/expr ]; then
    $INS install -y coreutils >/dev/null 2>&1
fi

# Random password generation function
if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    function rand_pass() {
        pass=`mkpasswd -l 5 -s 0 -c 1 -C 0 -d 4`
        echo $pass
    }
else
    function rand_pass() {
        pass=$(echo $(( RANDOM % 65535 + 1024 )))
        echo $pass
    }
fi

# Execute L2TP setup
l2tp

# Configure iptables
iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT

iptables -t nat -L -v -n

# Initialize variables
start_num=2
rm -f ./l2tp.txt
psk=`cat /etc/ipsec.secrets | awk '{print $5}' | sed 's/"//g'`
ip=`cat /etc/ipsec.conf | grep leftid | awk -F "=" '{print $2}'`

echo "----------------------------------------"
# Generate password
password1="111111"
read -e -p "请输入您需要自定义设置的l2tp密码(默认:$password1):" password
[[ -z "${password}" ]] && password=$password1


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
# 这里不放 MASQUERADE，后面用精细 SNAT
-A POSTROUTING -s ${iprange}.0/24 -o eth0 -j MASQUERADE
COMMIT
EOF
iptables-restore < /etc/sysconfig/iptables

# Process IP addresses from system_ip.txt
while read line || [[ -n ${line} ]]; do
    nic_ip=`echo $line | awk '{print $1}'`
    echo "创建第" `expr $start_num - 1` "个"
    echo "vip`expr $start_num - 1`     l2tpd     $password     $iprange.$start_num" >> /etc/ppp/chap-secrets
    
    iptables -t nat -A POSTROUTING -s $iprange.$start_num -j SNAT --to-source $nic_ip

    public_ip=`curl -s --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Ahttp`
    
    if [ -z "$public_ip" ]; then
        public_ip=`curl -s --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Bhttp`
    fi
    
    if [ -z "$public_ip" ]; then
        public_ip=`curl -s --interface $line -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.114 Safari/537.36 Edg/103.0.1264.62" $Chttp`
    fi
    
    echo "对应公网ip  $public_ip 虚拟ip地址  $nic_ip  用户名 vip`expr $start_num - 1` 密码  $password  预共享秘钥  $psk  " >> ./l2tp.txt
    start_num=`expr $start_num + 1`
done < system_ip.txt

rm -f system_ip.txt

# Save iptables rules and restart services
if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    iptables-save > /etc/sysconfig/iptables
    systemctl restart xl2tpd
    systemctl restart ipsec
else
    iptables-save > /etc/iptables.up.rules
    systemctl restart xl2tpd
fi

# Check if system is Ubuntu
if grep -q "Ubuntu" /etc/os-release; then
    if [ ! -f /etc/systemd/system/iptables.service ]; then
        cat > /etc/systemd/system/iptables.service <<EOF
[Unit]
Description=Restore network interface configuration
After=network.target NetworkManager.service
Requires=NetworkManager.service

[Service]
ExecStartPre=/bin/sleep 5
ExecStartPre=/etc/rc.d/init.d/mask.sh
ExecStart=/bin/bash -c 'iptables-restore < /etc/iptables.up.rules'

User=root
Type=oneshot
RemainAfterExit=yes
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    fi
    sudo systemctl daemon-reload
    systemctl enable iptables.service
else
    systemctl restart iptables
fi
iptables -t nat -L -v -n

# Print configuration information
echo -e "配置文件路径/etc/ppp/chap-secrets，修改此文件可改变帐号密码等信息，修改完成后重启服务生效systemctl restart xl2tpd"
echo -e "登陆服务器后，输入lsof -i | grep l2tp 可查看当前服务器所有l2tp连接。"

echo ""

echo "----------------------------------------"
# Check system type and display appropriate message
if [ -e /etc/motd ]; then
    if grep -q "Huawei" /etc/motd; then
        echo -e "${Green_font_prefix}搭建成功,ip信息已放入l2tp.txt。${Font_color_suffix}"
    elif grep -q "Alibaba" /etc/motd; then
        echo -e "${Green_font_prefix}搭建成功,ip信息已放入l2tp.txt。${Font_color_suffix}"
    elif [ "$(dmidecode -s system-Manufacturer | awk '{print $1}')" == "Tencent" ]; then
        echo -e "${Green_font_prefix}搭建成功,ip信息已放入l2tp.txt。${Font_color_suffix}"
    else
        echo -e "${Green_font_prefix}搭建成功,ip信息已放入l2tp.txt。${Font_color_suffix}"
    fi
else
    echo -e "${Green_font_prefix}搭建成功,ip信息已放入l2tp.txt。${Font_color_suffix}"
fi

cat l2tp.txt
rm ip.txt

if [ "$ads" != "" ]; then
    echo "------------------------------------------------------------------------------------"
    echo -e "${Green_font_prefix}$ads${Font_color_suffix}"
fi