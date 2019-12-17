#!/bin/bash
#
# This is a script which configure iptables
# You could use it for:
#  - home-pc
#  - server-pc
# DRAFT
IPT="/sbin/iptables"
IPT6="/sbin/ip6tables"
HOSTTYPE=""
TCP_SERVICES=""
UDP_SERVICES=""
REMOTE_TCP_SERVICES='80 443 22'
REMOTE_UDP_SERVICES='53'
SERVICE_TYPE="standard"
REGEX_NET='([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/([0-9]{1,2})'
SSH_PORT='22'
TORRENTS='52740:56850'

TORRENTS_LISTEN='8999'
# Check iptables permissions
if [ ! -x $IPT ]; then
    exit 0; echo "You have not permissions to set up iptables"
fi

while [[ $# > 0 ]];do
case $1 in
--help)
 echo " This is script configures iptables
 ! Block ipv6 traffic
 You should use sudo or run as root for using it

 Usage:
    iptables.setup.sh -h home-pc -p standard -u users
    iptables.setup.sh -h server -p web-server -n 10.0.0.0/24
    
    
 Options:
    -h | --host-type [ home-pc | server ]
                     home-pc - block all input traffic, block output traffic
                     -p options could specify services set, which enable some output traffic
                     -u allow only http/https traffic from specific users
    -p | --ports [ standard | web-server | full ]
                    standard - dns, icmp,
                    web-server - allow http/https
                    full - you could specify services in FULL_TCP, FULL_UDP variable
    -u | --users \"user1 user2\"     
                Specify specific users which could use http/https traffic
    -n | --nets \"192.168.1.1/32 10.0.0.0/8\"
                Specify managment networks for an ssh access
 "
 exit 0
;;

-h|--host-type)
    HOSTTYPE=$2
    if [ $HOSTTYPE == "home-pc" ] || [ $HOSTTYPE == "server" ]; then
        echo "Host type is $HOSTTYPE"
    else
        echo "You should specify the host-type: home-pc or server"
    fi
    shift
;;
-p|--ports)
    SERVICE_TYPE=$2
    if [ $SERVICE_TYPE == "standard" ] || [ $SERVICE_TYPE == "web-server" ] || [ $SERVICE_TYPE == "full" ]; then
        echo "Service type is $SERVICE_TYPE"
    else
        echo "You should specify the ports [ standard | web-server | full ]"
    fi
    shift
;;
-u)
    USERS=$2
    echo "USER: $USERS"
    shift
;;
--users)
    USERS=$2
    echo "USERS: $USERS"
    shift
;;
-n)
    NETWORKS_MGMT=$2
    if [[ "$NETWORKS_MGMT" =~ $REGEX_NET ]]; then
        echo "Managment network: $NETWORKS_MGMT"
    else
        echo "You should specify correct network address 
        You use: $NETWORKS_MGMT
        But should: X.X.X.X/X IP/mask
        "
        exit 2
    fi
    shift
;;
--nets)
    NETWORKS_MGMT=$2
    for NET in $NETWORKS_MGMT; do
        if [[ "$NET" =~ $REGEX_NET ]]; then
        echo "Managment network: $NET"
    else
        echo "You should specify correct network address 
        You use: $NET
        But should: X.X.X.X/X IP/mask
        "
        exit 2
    fi
    done        
    shift
;;
*)
    echo "Try iptables.setup.sh --help for more information "
    exit 0
;;
esac
shift
done

# Service Type and services
case $SERVICE_TYPE in
standard)
TCP_SERVICE='8999'
UDP_SERVICE=''
# REMOTE SERVICES:
# 80, 443 - web
# 5222 - JABBER
# 8010 - JABBER FT
# 53 - DNS
REMOTE_TCP_SERVICES='80 443 5222 8010 53 22'
REMOTE_UDP_SERVICES='53'
TORRENTS_LISTEN='8999'
TORRENTS='52740:56850'
;;
web-server)
TCP_SERVICE='22 443 80'
UDP_SERVICE=''
REMOTE_TCP_SERVICES='80 443'
REMOTE_UDP_SERVICES='53'
;;

full)
TCP_SERVICE='22 443 80'
UDP_SERVICE=''
REMOTE_TCP_SERVICES='80 443 3306'
REMOTE_UDP_SERVICES='53'
TORRENTS_LISTEN='8999'
TORRENTS='52740:56850'

;;
esac


#################################
#        IPTABLES RULES SET     # 
#################################

# FLUSH IPTABLES
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X


# DROP BY DEFAULT POLICY
$IPT -P INPUT DROP
$IPT -P OUTPUT DROP
$IPT -P FORWARD DROP

# ALLOW LOOPBACK
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
# ALLOW NTP
$IPT -A OUTPUT -p udp --dport 123 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT  -p udp --sport 123 -m state --state ESTABLISHED     -j ACCEPT

# DNS for ROOT USER

$IPT -A OUTPUT -p udp  --dport 53 -m state --state NEW,ESTABLISHED -m owner --uid-owner root -j ACCEPT
$IPT -A INPUT  -p udp  --sport 53 -m state --state ESTABLISHED     -j ACCEPT
$IPT -A OUTPUT -p tcp  --dport 53 -m state --state NEW,ESTABLISHED -m owner --uid-owner root -j ACCEPT
$IPT -A INPUT  -p tcp  --sport 53 -m state --state ESTABLISHED     -j ACCEPT

# APT 
$IPT -A OUTPUT -p tcp --dport 21  -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT  -p tcp  --sport 21  -m state --state ESTABLISHED     -j ACCEPT
$IPT -A OUTPUT -p tcp  --dport 80 -m state --state NEW,ESTABLISHED -m owner --uid-owner root -j ACCEPT
$IPT -A OUTPUT -p tcp  --dport 443 -m state --state NEW,ESTABLISHED -m owner --uid-owner root -j ACCEPT
$IPT -A INPUT  -p tcp  --sport 80 -m state --state ESTABLISHED     -j ACCEPT
$IPT -A INPUT  -p tcp  --sport 443 -m state --state ESTABLISHED     -j ACCEPT

# SSH REMOTE MANAGMENT
if [ -n "$NETWORKS_MGMT" ]; then
for NETWORK_MGMT in $NETWORKS_MGMT; do
    $IPT -A INPUT -p tcp --src ${NETWORK_MGMT} --dport ${SSH_PORT} -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
    $IPT -A INPUT -p tcp --src ${NETWORK_MGMT} --dport ${SSH_PORT} -m conntrack --ctstate NEW,ESTABLISHED -j LOG  --log-level 4 --log-prefix 'SSH: ' 
    $IPT -A OUTPUT -p tcp --src ${NETWORK_MGMT} --sport ${SSH_PORT} -m conntrack --ctstate ESTABLISHED -j ACCEPT

done
fi

$IPT -A OUTPUT -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT  -p tcp --sport 22 -m state --state ESTABLISHED     -j ACCEPT
# OUTPUT
if [ -n "$REMOTE_TCP_SERVICES" ]; then
    if [ -n "$USERS" ]; then
    for USER in $USERS; do
    for REMOTE_TCP_SERVICE in $REMOTE_TCP_SERVICES; do
        $IPT -A OUTPUT -p tcp --dport $REMOTE_TCP_SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p tcp --sport $REMOTE_TCP_SERVICE -m state --state ESTABLISHED -j ACCEPT
    done 
    done
    else
    for REMOTE_TCP_SERVICE in $REMOTE_TCP_SERVICES; do
        $IPT -A OUTPUT -p tcp --dport $REMOTE_TCP_SERVICE -m state --state NEW,ESTABLISHED  -m owner --uid-owner $USER  -j ACCEPT
        $IPT -A INPUT  -p tcp --sport $REMOTE_TCP_SERVICE -m state --state ESTABLISHED -j ACCEPT
        
    done 
    fi
fi
if [ -n "$REMOTE_UDP_SERVICES" ]; then
    if [ -n "$USERS" ]; then
    for USER in $USERS; do
    for REMOTE_UDP_SERVICE in $REMOTE_UDP_SERVICES; do
        $IPT -A OUTPUT -p udp --dport $REMOTE_UDP_SERVICE -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p udp --sport $REMOTE_UDP_SERVICE -m state --state ESTABLISHED -j ACCEPT
    done      
    done
    else
    for REMOTE_UDP_SERVICE in $REMOTE_UDP_SERVICES; do
        $IPT -A OUTPUT -p udp --dport $REMOTE_UDP_SERVICE -m state --state NEW,ESTABLISHED -m owner --uid-owner $USER -j ACCEPT
        $IPT -A INPUT  -p udp --sport $REMOTE_UDP_SERVICE -m state --state ESTABLISHED -j ACCEPT
    done    
    fi
fi


if [ -n "$TORRENTS" ]; then
    if [ -n "$USERS" ]; then
    #TORRENTS LISTEN
    # TORRENTS
        $IPT -A INPUT  -p tcp --dport ${TORRENTS_LISTEN} -m state --state ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p tcp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j LOG  --log-level 4 --log-prefix 'TORRENTS: '
        $IPT -A INPUT  -p udp --dport ${TORRENTS_LISTEN} -m state --state ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p udp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j LOG  --log-level 4 --log-prefix 'TORRENTS: '
        $IPT -A OUTPUT -p tcp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -m owner --uid-owner $USER -j ACCEPT
        $IPT -A OUTPUT -p udp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -m owner --uid-owner $USER -j ACCEPT
    #TORRENTS CONNECTION
        $IPT -A INPUT -p tcp -m multiport --dports ${TORRENTS}  -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A OUTPUT  -p tcp -m multiport --sports ${TORRENTS} -m state --state ESTABLISHED -m owner --uid-owner $USER  -j ACCEPT
        $IPT -A INPUT -p udp -m multiport --dports ${TORRENTS}  -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A OUTPUT  -p udp -m multiport --sports ${TORRENTS} -m state --state ESTABLISHED -m owner --uid-owner $USER -j ACCEPT 
    else
    #TORRENTS LISTEN
    # TORRENTS
        $IPT -A INPUT  -p tcp --dport ${TORRENTS_LISTEN} -m state --state ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p tcp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j LOG  --log-level 4 --log-prefix 'TORRENTS: '
        $IPT -A INPUT  -p udp --dport ${TORRENTS_LISTEN} -m state --state ESTABLISHED -j ACCEPT
        $IPT -A INPUT  -p udp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j LOG  --log-level 4 --log-prefix 'TORRENTS: '
        $IPT -A OUTPUT -p tcp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A OUTPUT -p udp --sport ${TORRENTS_LISTEN} -m state --state NEW,ESTABLISHED -j ACCEPT
    #TORRENTS CONNECTION
        $IPT -A INPUT -p tcp -m multiport --dports ${TORRENTS}  -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A OUTPUT  -p tcp -m multiport --sports ${TORRENTS} -m state --state ESTABLISHED -j ACCEPT
        $IPT -A INPUT -p udp -m multiport --dports ${TORRENTS}  -m state --state NEW,ESTABLISHED -j ACCEPT
        $IPT -A OUTPUT  -p udp -m multiport --sports ${TORRENTS} -m state --state ESTABLISHED -j ACCEPT 
    fi
fi


iptables -L -v

/sbin/iptables-save > /etc/iptables.up.rules
echo '#!/bin/sh
/sbin/iptables-restore < /etc/iptables.up.rules
IPT="/sbin/iptables"
#repositories="security.debian.org deb.debian.org"

#for addr in $repositories;do
#    ips=$(host $addr | grep "has address" | sed "s/.*.has address //g") 
#    echo $ips
#    for ip in $ips; do
#    echo $ip
#        $IPT -A OUTPUT -p tcp -d $ip --dport 443 -m owner --uid-owner root -j ACCEPT
#        $IPT -A OUTPUT -p tcp -d $ip --dport 80 -m owner --uid-owner root -j ACCEPT
#    done
#done
exit 0' > /etc/network/if-pre-up.d/iptables
chmod +x /etc/network/if-pre-up.d/iptables


# start with a clean slate
ip6tables -F
ip6tables -X

ip6tables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate INVALID -j DROP
# allow icmpv6
ip6tables -I INPUT -p ipv6-icmp -j ACCEPT
ip6tables -I OUTPUT -p ipv6-icmp -j ACCEPT


# allow loopback
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# drop packets with a type 0 routing header
ip6tables -A INPUT -m rt --rt-type 0 -j DROP
ip6tables -A OUTPUT -m rt --rt-type 0 -j DROP

# default policy...
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP


ip6tables-save > /etc/ip6tables.up.rules
echo '#!/bin/sh
/sbin/ip6tables-restore < /etc/ip6tables.up.rules
exit 0' > /etc/network/if-pre-up.d/iptables6
chmod +x /etc/network/if-pre-up.d/iptables6



/etc/init.d/networking restart
/etc/init.d/network-manager restart

echo -e "
Set up outgoing(Min/Max) ports 
$TORRENTS
Set up port for incoming connection 
$TORRENTS_LISTEN
"