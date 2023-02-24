#! /bin/bash

usage() {
echo "
*** A simple script to split the traffic of a certain app or script and direct it to your desired interface
Call this way: ./guideMan.sh --interface 'interfaceName' --script '/route/to/script'
Example: ./guideMan.sh --interface eth0 --script './test.sh'
"
}

#*************************functions to clean created stuff at the end****************************
cleanUp() {
    #delete iptables rules
    iptables -t mangle -C OUTPUT -m owner --uid-owner $appRunnerUser -j MARK --set-mark $tableNum &>/dev/null
    if [ $? == 0 ]; then
        iptables -t mangle -D OUTPUT -m owner --uid-owner $appRunnerUser -j MARK --set-mark $tableNum
    fi

    iptables -C INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT &>/dev/null
    if [ $? == 0 ]; then
        iptables -D INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT
    fi

    iptables -C OUTPUT -o lo -m owner --uid-owner $appRunnerUser -j ACCEPT &>/dev/null
    if [ $? == 0 ]; then
        iptables -D OUTPUT -o lo -m owner --uid-owner $appRunnerUser -j ACCEPT
    fi

    iptables -C OUTPUT -o $INTERFACE -m owner --uid-owner $appRunnerUser -j ACCEPT &>/dev/null
    if [ $? == 0 ]; then
        iptables -D OUTPUT -o $INTERFACE -m owner --uid-owner $appRunnerUser -j ACCEPT
    fi

    iptables -t nat -C POSTROUTING -o $INTERFACE -j MASQUERADE &>/dev/null
    if [ $? == 0 ]; then
        iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
    fi

    iptables -C OUTPUT -m owner --uid-owner $appRunnerUser -j REJECT &>/dev/null
    if [ $? == 0 ]; then
        iptables -D OUTPUT -m owner --uid-owner $appRunnerUser -j REJECT
    fi

    #delete other settings
    ps -o pid -u $appRunnerUser | egrep -v PID | xargs kill -15 &>/dev/null

    if [ $(cat /etc/passwd | awk -F ":" '{print $1}' | egrep -x -c $appRunnerUser) == 1 ]; then
        sudo userdel -f $appRunnerUser &>/dev/null
    fi

    if [ $(cat /etc/group | awk -F ":" '{print $1}' | egrep -x -c $appRunnerUser) == 1 ]; then
        sudo groupdel -f $appRunnerUser &>/dev/null
    fi

    if [ $(ip rule list | awk -F " " '{print $7}' | egrep -x -c $appRunnerUser) == 1 ]; then
        ip rule del from all fwmark $tableNum lookup $appRunnerUser
    fi

    cat /etc/iproute2/rt_tables | awk -v var="$tableNum" '$1!=var' >$dirPath/tempFile001
    cat $dirPath/tempFile001 >/etc/iproute2/rt_tables

    if [ -d /home/$appRunnerUser ]; then
        rm -rf /home/$appRunnerUser
    fi

    rm -rf $dirPath
    echo ""
    echo "===================================="
    echo "you exited successfully."
    echo "===================================="

    exit 0
}


# check if app runner is the root user or not
if [ $EUID != 0 ]; then
    echo "You are not the root user. Please first become root and then try again."
    exit 1
fi

#********** receive arguments *************

while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --interface )               INTERFACE="$2";   shift;;
    --script )                     scriptToRun="$2";   shift;;
    --help )                      usage;       exit;; # Quit and show usage
  esac
  shift
done

#******************************create a folder to put temporary files***********************************

namingPostfix=$(date +%Y-%m-%d-%H,%M,%S)
randString=$(echo $RANDOM | tr '[0-9]' '[a-z]')
mkdir /var/runDir-$namingPostfix-$randString
dirPrefix="/var/runDir-$namingPostfix-$randString"
dirPath="/var/runDir-$namingPostfix-$randString"

#define a user to run the app
cat /etc/passwd | awk -F ":" '$1 ~ /^tempuser/ {print $1}' >$dirPath/tempFile001

for num in {252..1}; do
    echo tempuser$num >>$dirPath/tempFile002
done

appRunnerUser=$(cat $dirPath/tempFile002 | egrep -x -v -f $dirPath/tempFile001 | head -n1)
rm -f $dirPath/tempFile001 $dirPath/tempFile002

# define an appropriate routing table name
cat /etc/iproute2/rt_tables | awk '{print $1}' | egrep -x '[0-9]+' | egrep -x -v '255|254|253|0' >$dirPath/tempFile003

for num in {252..1}; do
    echo $num >>$dirPath/tempFile004
done

tableNum=$(cat $dirPath/tempFile004 | egrep -x -v -f $dirPath/tempFile003 | head -n1)
rm -f $dirPath/tempFile003 $dirPath/tempFile004

trap cleanUp 1 2 3 6 9 15
#create a User by which we will run the process
if [ -d /home/$appRunnerUser ]; then
    rm -rf /home/$appRunnerUser
fi

if [ $(cat /etc/group | awk -F ":" '{print $1}' | egrep -x $appRunnerUser | wc -l) == 1 ]; then
    groupdel $appRunnerUser
fi

sudo adduser --disabled-login --gecos "" $appRunnerUser &>/dev/null

# mark packets from $appRunnerUser

iptables -t mangle -A OUTPUT -m owner --uid-owner $appRunnerUser -j MARK --set-mark $tableNum

# allow responses
iptables -A INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT

# let $appRunnerUser access lo and $INTERFACE
iptables -A OUTPUT -o lo -m owner --uid-owner $appRunnerUser -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m owner --uid-owner $appRunnerUser -j ACCEPT

# all packets on $INTERFACE needs to be masqueraded
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

#create a routing table with the name of $appRunnerUser
echo $tableNum $appRunnerUser >>/etc/iproute2/rt_tables

GATEWAYIP=$(ifconfig $INTERFACE | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | egrep -v '255|(127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | tail -n1)
if [[ $(ip route ls | grep $INTERFACE | egrep -o "default via .* dev ens33" | awk '{print $3}' | head -n1 | wc -l) -eq 1 ]]; then
  GATEWAYIP=$(ip route ls | grep $INTERFACE | egrep -o "default via .* dev ens33" | awk '{print $3}' | head -n1)
fi

if [ $(ip rule list | awk -F " " '{print $7}' | egrep -x -c $appRunnerUser) != 0 ]; then
    ip rule del lookup $appRunnerUser
fi
ip rule add from all fwmark $tableNum lookup $appRunnerUser
ip route flush table $appRunnerUser
ip route replace default via $GATEWAYIP table $appRunnerUser
#*******************************************************************
echo "===================================="
echo -e "your assigned user is $appRunnerUser"
echo -e "your interface is $INTERFACE"
echo "===================================="
#************************start application**************************
xhost +local:$appRunnerUser &>/dev/null
sudo -u $appRunnerUser -H $scriptToRun
appPID=$!
#wait $appPID
cleanUp
