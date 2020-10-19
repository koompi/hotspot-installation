#!/bin/bash

##This script run for install hotspot

aonther(){
    rfkill unblock all
    apt-get update
}

##Color
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'

WIRE=$(ls /sys/class/net/ | grep eth | awk 'NR==1')
WIRELESS=$(ls /sys/class/net/ | grep wl | awk 'NR==1')

##banner
banner(){
    echo
    BANNER_NAME=$1
    echo -e "${YELLOW}[+] ${BANNER_NAME}"
    echo -e "--------------------------------------${NC}"
}

##run as root
check_root(){
    if [[ $(id -u) != 0 ]]; then
        echo "This script run as root."
        exit;
    fi
}

##Install package
package_install(){
banner "Install Package"

    for PKG in $(cat $(pwd)/package_x86_64)
    do
        dpkg -s ${PKG} &> /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[ OK ] Package ${PKG} is installed!${NC}"
        else
            echo -e "${GREEN}[ Check ] Installing ${PKG}...!${NC}"
            apt-get install -y ${PKG}
            echo -e "${GREEN}[ OK ] Package ${PKG} is installed!${NC}"
        fi
    done

    sudo dpkg -i $(pwd)/package/coova-chilli_1.4_armhf.deb
}

##default
default_config(){
banner "Configure Default"

    cp -r $(pwd)/default /etc
    echo -e "${GREEN}[ OK ] Configure Default config!${NC}"
}

##static ip address
static_ip_config(){
banner "Configure static ip address"

    echo -e "You are have interfaces wan and lan!"
    #input wan ip
    echo "[${WIRE}]: is WAN interface"
    read -p "IP Address[]: " WANIP
    read -p "Netmask[]: " WANNETMASK
    read -p "Gateway[]: " WANGATEWAY


    #input lan ip
    echo -e "\n[${WIRELESS}]: is LAN interface"
    read -p "IP Address[]: " LANIP
    read -p "Netmask[]: " LANNETMASK
    read -p "Gateway[]: " LANGATEWAY    

    #copy config to /etc/network
    cp -r $(pwd)/staticIP/network /etc/

    #replace name in config file
    #wan interface
    grep -rli WANIP /etc/network/interfaces.d/eth0-wan | xargs -i@ sed -i s+WANIP+${WANIP}+g @
    grep -rli WANNETMASK /etc/network/interfaces.d/eth0-wan | xargs -i@ sed -i s+WANNETMASK+${WANNETMASK}+g @
    grep -rli WANGATEWAY /etc/network/interfaces.d/eth0-wan | xargs -i@ sed -i s+WANGATEWAY+${WANGATEWAY}+g @
    echo -e "${GREEN}[ OK ] Configure wan interface!${NC}"

    #lan interface
    grep -rli LANIP /etc/network/interfaces.d/wlan0-lan | xargs -i@ sed -i s+LANIP+${LANIP}+g @
    grep -rli LANNETMASK /etc/network/interfaces.d/wlan0-lan | xargs -i@ sed -i s+LANNETMASK+${LANNETMASK}+g @
    grep -rli LANGATEWAY /etc/network/interfaces.d/wlan0-lan | xargs -i@ sed -i s+LANGATEWAY+${LANGATEWAY}+g @    
    echo -e "${GREEN}[ OK ] Configure lan interface!${NC}"

    #start service
    ifconfig wlan0 up
    ifconfig eth0 up
    systemctl restart networking
}

##dhcp
dhcp_config(){
banner "Configure dhcp"

    PREFIX1=$(echo ${LANIP} | awk -F'.' '{print $1}')
    PREFIX2=$(echo ${LANIP} | awk -F'.' '{print $2}')
    PREFIX3=$(echo ${LANIP} | awk -F'.' '{print $3}')

    NETWORK="${PREFIX1}.${PREFIX2}.${PREFIX3}.0"
    SUBNET="${LANNETMASK}"
    GATEWAY="${LANGATEWAY}"

    echo "Network[]: ${NETWORK}"
    echo "Subnet[]: ${SUBNET}"
    echo "Gateway[]: ${GATEWAY}"

    read -p "We recommended use range (10-254) [Y\n]: " YN
    if [[ "${YN}" == "Y" || "${YN}" == "y" || -z "${YN}" ]];then
        RANK="${PREFIX1}.${PREFIX2}.${PREFIX3}.10 ${PREFIX1}.${PREFIX2}.${PREFIX3}.254"
        echo "Rank[]: ${RANK}"
    else
        read -p "Rank start from[]: " START
        read -p "To[]: " END
        RANK="${PREFIX1}.${PREFIX2}.${PREFIX3}.${START} ${PREFIX1}.${PREFIX2}.${PREFIX3}.${END}"
        echo "Rank[]: ${RANK}"
    fi

    cp $(pwd)/dhcp/dhcpd.conf /etc/dhcp/
    echo -e "${GREEN}[ OK ] Copy dhcp config${NC}"

    grep -rli IPNETWORK /etc/dhcp/dhcpd.conf | xargs -i@ sed -i s+IPNETWORK+${NETWORK}+g @
    grep -rli IPSUBNET /etc/dhcp/dhcpd.conf | xargs -i@ sed -i s+IPSUBNET+${SUBNET}+g @
    grep -rli IPRANK /etc/dhcp/dhcpd.conf | xargs -i@ sed -i s+IPRANK+"${RANK}"+g @
    grep -rli IPGATEWAY /etc/dhcp/dhcpd.conf | xargs -i@ sed -i s+IPGATEWAY+${GATEWAY}+g @
    grep -rli LANINTERFACE /etc/default/isc-dhcp-server | xargs -i@ sed -i s+LANINTERFACE+${WIRELESS}+g @
    echo -e "${GREEN}[ OK ] Configure dhcp${NC}"

    systemctl disable dhcpcd
    systemctl enable isc-dhcp-server
    systemctl start isc-dhcp-server
    echo -e "${GREEN}[ OK ] Start service dhcp!${NC}"
}

##postgresql
postgresql_config(){
banner "Install Postgresql"

    systemctl enable docker
    sudo systemctl start docker
    echo -e "${GREEN}[ OK ] Start service docker!${NC}"

    read -p "Postgresql Username[]: " USERNAME
    read -p "Postgresql Password[]: " PASSWORD

    cp -r postgresql /opt/
    echo -e "${GREEN}[ OK ] Copy docker compose!${NC}"

    grep -rli USERNAME /opt/postgresql/docker-compose.yml | xargs -i@ sed -i s+USERNAME+"${USERNAME}"+g @
    grep -rli PASSWD /opt/postgresql/docker-compose.yml | xargs -i@ sed -i s+PASSWD+${PASSWORD}+g @
    echo -e "${GREEN}[ OK ] Configure docker-compose!${NC}"

    docker-compose -f /opt/postgresql/docker-compose.yml down
    docker-compose -f /opt/postgresql/docker-compose.yml up -d
    echo -e "${GREEN}[ OK ] Start docker-compose!${NC}"

}

##hostapd
hostapd_config(){
banner "Configure hostapd"

    read -p "SSID Name[]: " SSID
    cp -r hostapd /etc
    echo -e "${GREEN}[ OK ] Copy config!${NC}"

    grep -rli LANINTERFACE /etc/hostapd/hostapd.conf | xargs -i@ sed -i s+LANINTERFACE+${WIRELESS}+g @
    grep -rli WIFINAME /etc/hostapd/hostapd.conf | xargs -i@ sed -i s+WIFINAME+${SSID}+g @
    echo -e "${GREEN}[ OK ] Configure hostapd!${NC}"

    systemctl enable hostapd
    systemctl start hostapd
    echo -e "${GREEN}[ OK ] Start service hostapd!${NC}"
    
}

##freeradius
freeradius_config(){
banner "Configure freeradius"

    #sql Connection info
    echo "Connection info sql"
    read -p "Server[]: " IPSERVER
    read -p "Port[]: " PORT
    read -p "Radius password[]: " RADIUSPASSWD

    cp -r $(pwd)/freeradius /etc/
    echo -e "${GREEN}[ OK ] Copy config.${NC}"

    grep -rli IPSERVER /etc/freeradius/3.0/mods-available/sql | xargs -i@ sed -i s+IPSERVER+${IPSERVER}+g @
    grep -rli PORTNUMBER /etc/freeradius/3.0/mods-available/sql | xargs -i@ sed -i s+PORTNUMBER+${PORT}+g @
    grep -rli USERNAME /etc/freeradius/3.0/mods-available/sql | xargs -i@ sed -i s+USERNAME+${USERNAME}+g @
    grep -rli PASSWORDLOGIN /etc/freeradius/3.0/mods-available/sql | xargs -i@ sed -i s+PASSWORDLOGIN+${PASSWORD}+g @
    echo -e "${GREEN}[ OK ] Configure freeradius sql!${NC}"

    ln -s /etc/freeradius/3.0/sites-avaiable/default /etc/freeradius/3.0/sites-enabled/default
    ln -s /etc/freeradius/3.0/sites-available/inner-tunner /etc/freeradius/3.0/sites-enabled/inner-tunner
    ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
    echo -e "${GREEN}[ OK ] Link configure freeradius!${NC}"

    #secret
    grep -rli RADIUSSECRET /etc/freeradius/3.0/client.conf | xargs -i@ sed -i s+RADIUSSECRET+${RADIUSPASSWD}+g @

    systemctl enable freeradius
    systemctl start freeradius
    echo -e "${GREEN}[ OK ] Start service freeradius!${NC}"

}

##coovachilli
coovachilli_config(){
banner "Configure coovachilli"

    cp -r $(pwd)/coovachilli/* /
    echo -e "${GREEN}[ OK ] Copy config!${NC}"

    grep -rli INTERFACEWAN /etc/chilli/config | xargs -i@ sed -i s+INTERFACEWAN+${WIRE}+g @
    grep -rli INTERFACELAN /etc/chilli/config | xargs -i@ sed -i s+INTERFACELAN+${WIRELESS}+g @
    grep -rli IPNETWORK /etc/chilli/config | xargs -i@ sed -i s+IPNETWORK+${NETWORK}+g @
    grep -rli IPSUBNET /etc/chilli/config | xargs -i@ sed -i s+IPSUBNET+${SUBNET}+g @
    grep -rli IPGATEWAY /etc/chilli/config | xargs -i@ sed -i s+IPGATEWAY+${GATEWAY}+g @
    grep -rli SSIDNAME /etc/chilli/config | xargs -i@ sed -i s+SSIDNAME+${SSID}+g @
    grep -rli PASSRAD /etc/chilli/config | xargs -i@ sed -i s+PASSRAD+${RADIUSPASSWD}+g @
    echo -e "${GREEN}[ OK ] Configure coova!${NC}"

    systemctl enable chilli
    systemctl start chilli
    echo -e "${GREEN}[ OK ] Start service chilli"

}

##Service status
# server_status(){
#     systemctl status dhcpd.service hostapd.service freeradius.service docker.service 
# }

##call function
check_root
aonther
package_install
default_config
static_ip_config
dhcp_config
postgresql_config
hostapd_config
freeradius_config
coovachilli_config
# service_status