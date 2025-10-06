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