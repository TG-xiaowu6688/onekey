#!/bin/bash


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

ip -4 a | grep -v eth0 | grep inet | grep -v "127.0.0.1" | grep -v "172.17.0.1" | awk '{print $2,$NF}' | sed "s/\/[0-9]\{1,2\}//g" | awk '{print $1}' >> ip.txt
sleep 3

sed -i "1i\\$Lip" ip.txt
awk '!seen[$0]++' ip.txt > tempfile.txt && mv tempfile.txt ip.txt


E="mcedit"
PM="apt"
ipsec="strongswan"
l2tp="xl2tpd"

cf_ppp_secrets="/etc/ppp/chap-secrets"
cf_l2tp="/etc/xl2tpd/xl2tpd.conf"
cf_l2tp_options="/etc/ppp/options.xl2tpd"
cf_ipsec="/etc/ipsec.conf"
cf_ipsec_secrets="/etc/ipsec.secrets"
cf_sysctl="/etc/sysctl.conf"

cfurl_ppp_secrets="# Secrets for authentication using CHAP
# client	server	secret			IP addresses

testvpnuser * testvpnpassword * "
cfurl_l2tp="[global]
ipsec saref = yes
listen-addr = yourip

[lns default]
ip range = 10.19.rangestart.2-10.19.rangestart.254
local ip = 10.19.rangestart.1

refuse chap = yes
refuse pap = yes
require authentication = yes
ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes"
cfurl_l2tp_options="#debug
name l2tp_ipsec_vpn
auth
lock
modem
noipx
crtscts
proxyarp
multilink
mppe-stateful
hide-password
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
mtu 1400
asyncmap 0
lcp-echo-failure 4
lcp-echo-interval 30
ms-dns 8.8.8.8
ms-dns 1.1.1.1
ms-dns 77.88.8.8"
cfurl_ipsec="conn rw-base
    fragmentation=yes
    dpdaction=clear
    dpdtimeout=120s
    dpddelay=60s

conn l2tp-vpn
    also=rw-base
    auto=add
    rekey=no
    reauth=no
    type=transport
    left=%defaultroute
    right=%any
    leftsubnet=%dynamic[/1701]
    rightsubnet=%dynamic
    leftprotoport=udp/1701
    rightprotoport=udp/%any
    leftauth=psk
    rightauth=psk
    keylife=24h
    ikelifetime=24h
    keyingtries=3
    keyexchange=ikev1
    ike=aes256-aes128-sha256-sha1-modp3072-modp2048-modp1024-3des
    esp=aes256-aes128-sha256-sha1-modp3072-modp2048-modp1024-3des"
cfurl_ipsec_secrets="# This file holds shared secrets or RSA private keys for authentication.

# RSA private key for this host, authenticating it to any other host
# which knows the public part.

# this file is managed with debconf and will contain the automatically created private key
include /var/lib/strongswan/ipsec.secrets.inc

&any %any : PSK \"PUT_YOUR_PSK_HERE\""

msg_cmd_control="$0 control start|stop|restart|status"
msg_cmd_editconfig="$0 edit-config secrets|l2tp|l2tp-options|ipsec|ipsec-secrets|sysctl"
msg_cmd_installconfigs="$0 install-config all|secrets|l2tp|l2tp-options|ipsec|ipsec-secrets"
msg_cmd_server="$0 server install|reinstall|remove|purge"

function showAreYouShure() {
    read -p "Are you sure? [y/n] " -n 1 -r </dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
	exit 1
    fi
}

function doControl(){
    case $1 in
        start)
	    echo "Trying to start ${ipsec}-starter & $l2tp"
	    eval "systemctl start ${ipsec}-starter $l2tp"
	;;
	stop)
	    echo "Trying to stop ${ipsec}-starter & $l2tp"
	    eval "systemctl stop ${ipsec}-starter $l2tp"
	;;
	restart)
	    echo "Trying to restart ${ipsec}-starter & $l2tp"
	    eval "systemctl restart ${ipsec}-starter $l2tp"
	;;
	status)
	    echo "Services status:"
	    eval "systemctl status ${ipsec}-starter $l2tp"
	;;
	*)
	    echo "Usage: $msg_cmd_control"
	;;
    esac
}


function clearFirewall(){
    echo "clearing firewall"
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
}


function setupFirewall(){
    echo "Allow nat and masquerading in firewall"
    iptables --table nat --append POSTROUTING --jump MASQUERADE
}

function allowIpForward(){
    echo "Allow ip forwarding"
    echo 1 > /proc/sys/net/ipv4/ip_forward
    for each in /proc/sys/net/ipv4/conf/* 
    do
	echo 0 > $each/accept_redirects
	echo 0 > $each/send_redirects
    done
}

function doSetupNetwork() {
    # ToDo
    # uncomment row "net.ipv4.ip_forward = 1" in /etc/sysctl.conf
    setupFirewall
    allowIpForward
}

function doAddStandip() {

  echo "switching to multiple ip and multiple process mode"
  eval "systemctl stop $l2tp"
  eval "systemctl disable $l2tp"
  xl2tpd -c /etc/xl2tpd/xl2tpd.conf -p /var/run/xl2tpd.pid

  lastfilenum=`echo $(find /etc/xl2tpd/xl2tpd*|while read LINE; do echo ${LINE%%.conf}|grep -Eo '[0-9]+$';done|sort -r|head -n1)`;
  [[ $lastfilenum == '' ]] && lastfilenum=0;
  lastfilenumadded=`expr $lastfilenum + 1`;
  cat > /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf <<EOF
$cfurl_l2tp
EOF
  read -p "give a newip:" myIP </dev/tty
  sed -e "s/yourip/$myIP/g" -e "s/rangestart/$lastfilenumadded/g" -i /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf
  xl2tpd -c /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf -p /var/run/xl2tpd"$lastfilenumadded".pid

  clearFirewall
  iptables -t nat -A POSTROUTING -s 10.19.0.0/24 -o eth0 -j SNAT --to-source `echo $(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|head -n1)`
  iptables -t nat -A POSTROUTING -s 10.19."$lastfilenumadded".0/24 -o eth0 -j SNAT --to-source $myIP

  #eval "systemctl restart ${ipsec}-starter"
}

function doEditConfig(){
    case $1 in
	secrets)
	    eval "$E $cf_ppp_secrets"
	;;
	l2tp)
	    eval "$E $cf_l2tp"
	;;
	l2tp-options)
	    eval "$E $cf_l2tp_options"
	;;
	ipsec)
	    eval "$E $cf_ipsec"
	;;
	ipsec-secrets)
	    eval "$E $cf_ipsec_secrets"
	;;
	sysctl)
	    eval "$E $cf_sysctl"
	;;
	*)
	    echo "Usage: $msg_cmd_editconfig"
	;;
    esac
}

function doInstallConfigAll(){
    doInstallConfig secrets
    #doInstallConfig l2tp
    doInstallConfig l2tp-options
    doInstallConfig ipsec
    doInstallConfig ipsec-secrets
}

function sayInstallConfig(){
    echo "Install preconfigured file: $1"
}

function doInstallConfig(){
    echo "Install wget if not installed"
    apt install -y wget
    case $1 in
	all)
	    doInstallConfigAll
	;;
	secrets)
	    sayInstallConfig $cf_ppp_secrets
        cat > $cf_ppp_secrets <<EOF
$cfurl_ppp_secrets
EOF
	;;
	l2tp)
	    sayInstallConfig $cf_l2tp
        cat > $cf_l2tp <<EOF
$cfurl_l2tp
EOF
	;;
	l2tp-options)
	    sayInstallConfig $cf_l2tp_options
        cat > $cf_l2tp_options <<EOF
$cfurl_l2tp_options
EOF
	;;
	ipsec)
	    sayInstallConfig $cf_ipsec
        cat > $cf_ipsec <<EOF
$cfurl_ipsec
EOF
	;;
	ipsec-secrets)
	    sayInstallConfig $cf_ipsec_secrets
        cat > $cf_ipsec_secrets <<EOF
$cfurl_ipsec_secrets
EOF
	;;
	*)
	    echo " "
	    echo "---------------------------------------------------------------------"
	    echo "| WARNING!!! This action replace all data in choosen config file!!! |"
	    echo "---------------------------------------------------------------------"
	    echo " "
	    echo "Usage: $msg_cmd_installconfigs"
	;;
    esac
}

function askInstallConfigs(){
    while true; do
	read -p "Do you want to install preconfigured config files? [y/n] " yn </dev/tty
	case $yn in
	    [Yy]* ) 
		doInstallConfigAll 
		break
	    ;;
	    [Nn]* ) 
		exit
	    ;;
	    * ) 
		echo "Please answer y - yes or n - no"
	    ;;
	esac
    done
}

function doServer(){
    case $1 in
	install)
            doSetupNetwork
	    eval "$PM install -y $ipsec $l2tp"
            rm -rf /etc/xl2tpd/xl2tpd.conf
            eval "systemctl stop $l2tp"
            eval "systemctl disable $l2tp"

	    doInstallConfigAll
            read -p "give a user:" myUser </dev/tty
            read -p "give a pass:" myPass </dev/tty
            sed -e "s/testvpnuser/$myUser/g" -e "s/testvpnpassword/$myPass/g" -i "$cf_ppp_secrets"
            read -p "give a sharedpsk:" myPSK </dev/tty
            sed -i "s/PUT_YOUR_PSK_HERE/$myPSK/g" "$cf_ipsec_secrets"
            eval "systemctl restart ${ipsec}-starter"

            clearFirewall
            ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}'|while read myIP; do

              lastfilenum=`echo $(find /etc/xl2tpd/xl2tpd*|while read LINE; do echo ${LINE%%.conf}|grep -Eo '[0-9]+$';done|sort -r|head -n1)`;
              [[ $lastfilenum == '' ]] && lastfilenum=0;
              lastfilenumadded=`expr $lastfilenum + 1`;
              cat > /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf <<EOF
$cfurl_l2tp
EOF
              sed -e "s/yourip/$myIP/g" -e "s/rangestart/$lastfilenumadded/g" -i /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf
              xl2tpd -c /etc/xl2tpd/xl2tpd"$lastfilenumadded".conf -p /var/run/xl2tpd"$lastfilenumadded".pid


              iptables -t nat -A POSTROUTING -s 10.19."$lastfilenumadded".0/24 -o eth0 -j SNAT --to-source $myIP

            done
	;;
	reinstall)
	    eval "$PM reinstall -y $ipsec $l2tp"
	    askInstallConfigs
	;;
	remove)
	    showAreYouShure
	    eval "$PM remove -y $ipsec $l2tp"
	;;
	purge)
	    showAreYouShure
	    eval "$PM purge -y $ipsec $l2tp"
            rm -rf /etc/xl2tpd/*
	;;
	*)
	    echo "Usage: $msg_cmd_server"
	;;
    esac
}

function showHelp(){
    echo "Usage:" 
    echo " "
    echo "- control your vpn server"
    echo "	$msg_cmd_control" 
    echo " "
    echo "- edit config files"
    echo "	$msg_cmd_editconfig" 
    echo " "
    echo "- install preconfigured config files (by iTeeLion)"
    echo "	$msg_cmd_installconfigs" 
    echo " "
    echo "- setup network (allow nat and masquerading in firewall and allow ip forwarding)"
    echo "	$0 setup-network" 
    echo " "
    echo "- Add standip (switch mode and add multiple standalone ip)"
    echo "	$0 add-standip" 
    echo " "
    echo "- install/remove server (Packages: $ipsec & $l2tp)"
    echo "	$msg_cmd_server" 
    echo " "
}

case $1 in
    control)
	doControl $2
    ;;
    setup-network)
	doSetupNetwork
    ;;
    add-standip)
	doAddStandip
    ;;
    edit-config)
	doEditConfig $2
    ;;
    install-configs)
	doInstallConfig $2
    ;;
    server)
	doServer $2
    ;;
    help)
	showHelp
    ;;
    *)
	showHelp
    ;;
esac
