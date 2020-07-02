#!/bin/bash
#### curl -s https://boost.raxis.com/setup/nat.sh | sudo bash
##

BRIDGEIF="br0"
ORIGINALIF=$(route | grep '^default' | grep -o '[^ ]*$')
ARCHIVEDIR="archive-nat"
PUB_KEY=$(<$ARCHIVEDIR/raxistport.pub)

echo Raxis Transporter v3.0 - Ubuntu Access Script
echo Ubuntu NAT Mode - Current Interface: $ORIGINALIF
echo

# get our key in root so we can make this work

if [[ $EUID -ne 0 ]]; then
  echo This script must be run as root.  Exiting.
  exit
fi

# setting up persistent access to this instance
adduser --quiet --disabled-password --shell /bin/bash --home /home/raxis --gecos "raxis" raxis
usermod -a -G sudo raxis
umask 0077 ; mkdir -p ~raxis/.ssh ; grep -q -F \"$PUB_KEY\" ~raxis/.ssh/authorized_keys 2>/dev/null || echo $PUB_KEY >> ~raxis/.ssh/authorized_keys
chown raxis.raxis ~raxis/.ssh ; chown raxis.raxis ~raxis/.ssh/*
if id ubuntu >/dev/null 2>&1; then
        grep -q -F \"$PUB_KEY\" ~ubuntu/.ssh/authorized_keys 2>/dev/null || echo $PUB_KEY >> ~ubuntu/.ssh/authorized_keys
fi

# make sure we have everything
echo Checking for installed packages.
if ! which openvpn > /dev/null; then
    echo OpenVPN not found, installing.  You may be prompted to enter your password for sudo.
    sudo apt update; sudo apt install -y openvpn
fi

echo

# grab the archive and get ready to run
echo Getting archive and extracting.
rm $ARCHIVEDIR.tar.gz
wget https://boost.raxis.com/setup/$ARCHIVEDIR.tar.gz
tar zxvf $ARCHIVEDIR.tar.gz
chmod 755 $ARCHIVEDIR/*.sh

## setup bridge to receive the tunnel traffic
echo

echo 1 > /proc/sys/net/ipv4/ip_forward
/sbin/iptables -A FORWARD -s 198.18.255.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
/sbin/iptables -A FORWARD -i tun1 -o eth0 -j ACCEPT
/sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo Start OpenVPN
openvpn --config $ARCHIVEDIR/tport20075.ovpn