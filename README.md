# iptables-script
A simple bash script which sets up iptables for diffirent type of hosts
Run bash iptables.setup.sh --help for more information

# How to use it?
``` bash
git clone git@github.com:nen-dev/iptables-script.git

cd iptables-script
Example:
bash iptables.setup.sh -h home-pc -p standard -u users
```

Help:

```bash
 ! But now only block ipv6 traffic
 
 You should use sudo or run as root for using it
 Usage:
    iptables.setup.sh -h home-pc -p standard -u users
    iptables.setup.sh -h server -p web-server -n 10.0.0.0/24
    
    
 Options:
    -h | --host-type [ home-pc | server ]
                     home-pc - block all input traffic, block output traffic
                     -p options could specify services set, which enable some output traffic
                     -u allow only http/https traffic from specific users
    -p | --ports [ standard | web-server | full | monitoring ]
                    standard - dns, icmp,
                    web-server - allow http/https
                    full - you could specify services in FULL_TCP, FULL_UDP variable
                    monitoring - zabbix, ssh, snmp, icmp
    -u | --users \"user1 user2\"     
                Specify specific users which could use http/https traffic        
    -v | --vpn [cisco-ipsec] 
                specify type of vpn client
                --vnets \"192.168.1.1/32 10.0.0.0/8\"
                Specify the address for remote vpn server or server group
    -n | --nets \"192.168.1.1/32 10.0.0.0/8\"
                Specify managment networks for ssh access
```
