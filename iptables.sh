#!/bin/bash

IPT=/sbin/iptables
WGET=/usr/bin/wget
EGREP=/bin/egrep
TOUCH=/bin/touch
MKDIR=/bin/mkdir

# Set your IP to be and you will be whitelisted so you don't get blocked
MYIP=''

# Server IP
SERVER_IP=''

if [ "$SERVER_IP" == "" ]; then
    echo "Set IP address of server, here is a possible list"
    /sbin/ifconfig |grep -B1 "inet addr" |awk '{ if ( $1 == "inet" ) { print $2 } else if ( $2 == "Link" ) { printf "%s:" ,$1 } }' |awk -F: '{ print $1 ": " $3 }'
    exit
fi

ZONEROOT="/tmp/iptables"
DLROOT="http://www.ipdeny.com/ipblocks/data/countries"
TORURL="https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$SERVER_IP"

# Block Tor ?
BLOCKTOR=1

# Blocked Countries
ISO="af cn"

# Ethernet Interfaces, PUB=Public  PRI=Private
PUB='eth0'
PRI=''

# Name servers, delimit each with space (IP ADDRESS)
NAMESERVERS=''

# Clean old rules
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X
$IPT -P INPUT ACCEPT
$IPT -P OUTPUT ACCEPT
$IPT -P FORWARD ACCEPT

# create a dir
[ ! -d $ZONEROOT ] && $MKDIR -p $ZONEROOT

# create chain names
$IPT -N WHITELIST
$IPT -N SPAM
$IPT -N WEB
$IPT -N BLOCKHOSTS
$IPT -N BLACKLIST
$IPT -N THRU
$IPT -N LOGDROP
$IPT -N COUNTRY
$IPT -N TOR

# Accept already established/related connections
$IPT -A INPUT -i $PUB -m state --state RELATED,ESTABLISHED -j ACCEPT

# Let me talk to myself
$IPT -A INPUT -i lo -j ACCEPT

# Accept traffic from $PRI (intranet)
if [ "$PRI" -ne "" ]; then
    $IPT -A INPUT -i $PRI -s 0/0 -d 0/0 -j ACCEPT
fi

# Deny any packet coming in on the public internet interface $PUB
# which has a spoofed source address from our local networks:
$IPT -A INPUT -i $PUB -s 192.168.0.0/24 -j DROP
$IPT -A INPUT -i $PUB -s 127.0.0.0/8 -j DROP


# Drop unclean packets
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
$IPT -A INPUT -i $PUB -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP


$IPT -A INPUT -j WHITELIST

$IPT -A INPUT -i $PUB -p tcp -m tcp --dport 25 -j SPAM

$IPT -A INPUT -i $PUB -p tcp -m tcp --dport 80 --tcp-flags SYN,RST,ACK SYN -j WEB

$IPT -A INPUT -j BLOCKHOSTS
$IPT -A INPUT -j BLACKLIST
$IPT -A INPUT -j COUNTRY
$IPT -A INPUT -j TOR
$IPT -A INPUT -j THRU



# START WHITELIST ###########################################
$TOUCH $ZONEROOT/whitelist.zone
tDB=$ZONEROOT/whitelist.zone

GOODIPS=$(egrep -v "^#|^$" $tDB)
for ip in $GOODIPS
do
    $IPT -A WHITELIST -s $ip -j ACCEPT
done

if [ "$MYIP" -ne "" ]; then
    $IPT -A WHITELIST -s $MYIP -j ACCEPT
fi
# END WHITELIST ##############################################

# START THRU #################################################
$IPT -A THRU -p icmp -m limit --limit 1/sec -m icmp --icmp-type 8 -j ACCEPT
$IPT -A THRU -i $PUB -p tcp -m tcp --dport 22 -j ACCEPT
$IPT -A THRU -i $PUB -p tcp -m tcp --dport 25 -j ACCEPT
$IPT -A THRU -i $PUB -p tcp -m tcp --dport 80 -j ACCEPT
$IPT -A THRU -i $PUB -p tcp -m tcp --dport 443 -j ACCEPT

# DNS
for ip in $DNS_SERVER
do
$IPT -A OUTPUT -p udp -s $SERVER_IP --sport 1024:65535 -d $ip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -p udp -s $ip --sport 53 -d $SERVER_IP --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -p tcp -s $SERVER_IP --sport 1024:65535 -d $ip --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -p tcp -s $ip --sport 53 -d $SERVER_IP --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
done

if [ "$NS1" -ne "" ]; then
    $IPT -A THRU -p udp -s $NS1/32 --source-port 53 -d 0/0 -j ACCEPT
fi
if [ "$NS2" -ne "" ]; then
    $IPT -A THRU -p udp -s $NS2/32 --source-port 53 -d 0/0 -j ACCEPT
fi

# Privoxy
#$IPT -A THRU -i $PUB -p tcp -m tcp --dport 8118 -j ACCEPT

# Vent
#$IPT -A THRU -m state --state NEW -m tcp -p tcp --dport 3784 -j ACCEPT
#$IPT -A THRU -m state --state NEW -m udp -p udp --dport 3784 -j ACCEPT

# L4D
#$IPT -A THRU -p tcp -s 0/0 -d 0/0 --dport 27015 -j ACCEPT
#$IPT -A THRU -p udp -s 0/0 -d 0/0 --dport 27015 -j ACCEPT

#$IPT -A THRU -p tcp -s 0/0 -d 0/0 --dport 27016 -j ACCEPT
#$IPT -A THRU -p udp -s 0/0 -d 0/0 --dport 27016 -j ACCEPT

#$IPT -A THRU -p tcp -s 0/0 -d 0/0 --dport 27006 -j ACCEPT
#$IPT -A THRU -p udp -s 0/0 -d 0/0 --dport 27006 -j ACCEPT

# ZNC
#$IPT -A THRU -p tcp -s 0/0 -d 0/0 --dport 27500 -j ACCEPT
#$IPT -A THRU -p udp -s 0/0 -d 0/0 --dport 27500 -j ACCEPT

# theplanet 
#$IPT -A THRU -p tcp -s 74.54.240.36 -d 0/0 --dport 2049 -j ACCEPT
#$IPT -A THRU -p udp -s 74.54.240.36 -d 0/0 --dport 2049 -j ACCEPT


# END THRU ###################################################


# START COUNTRY ##############################################
for c in $ISO
do
	# local zone file
	tDB=$ZONEROOT/$c.zone

	#get fresh zone file
	$WGET --no-check-certificate -O $tDB $DLROOT/$c.zone

	BADIPS=$(egrep -v "^#|^$" $tDB)
	for ipblock in $BADIPS
	do
		$IPT -A COUNTRY -s $ipblock -j DROP
	done
done
# END COUNTRY ################################################

# START BLACKLIST ###########################################
$TOUCH $ZONEROOT/blacklist.zone
tDB=$ZONEROOT/blacklist.zone

BADIPS=$(egrep -v "^#|^$" $tDB)
for ipblock in $BADIPS
do
	$IPT -A BLACKLIST -s $ipblock -j DROP
done
# END BLACKLIST ##############################################

# START TORLIST ###########################################
if [ $BLOCKTOR == 1 ]; then
    $TOUCH $ZONEROOT/tor.zone
    tDB=$ZONEROOT/tor.zone

    #get fresh zone file
    $WGET --no-check-certificate -O $tDB $TORURL

    BADIPS=$(egrep -v "^#|^$" $tDB)
    for ipblock in $BADIPS
    do
        $IPT -A TOR -s $ipblock -j DROP
    done
fi
# END TORLIST ##############################################


$IPT -A INPUT -j DROP
$IPT -P INPUT DROP
