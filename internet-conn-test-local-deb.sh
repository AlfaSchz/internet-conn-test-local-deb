#!/bin/bash

PINGIP="8.8.8.8"
TSTDOM="www.google.fr"
TSTSTRING="google.com"

if [ $(lspci | grep -c Ethernet) -eq 0 ]
then
        echo "No network interface"
        exit 1
fi

if [ -z $(lspci -s "$(lspci | grep Ethernet | cut -d " " -f1 | head -1)" -vv | grep "Kernel driver in use:" | cut -d : -f2 | tr -d " " ) ]
then
        echo "Missing network driver"
        exit 2
fi

MYDEVICE=$(ip route show 0.0.0.0/0.0.0.0 | cut -d " " -f5)

if [ -z "$MYDEVICE" ]
then

    echo "No ethernet cable and wifi interface down"
    exit 3

fi


if [ $(ip link show $MYDEVICE | grep -c "NO-CARRIER" ) -gt 0 ]
then

    echo "Physical ethernet link problem"
    exit 4

fi

if [ $(ip link show $MYDEVICE | grep -c " UP " ) -eq 0 ]
then

    echo "$MYDEVICE administratively DOWN"
    exit 5

fi

if [ $(ip -4 addr show dev $MYDEVICE | grep -c " inet " ) -eq 0 ]
then

    echo "No IP configured in '$MYDEVICE'"
    exit 6

fi


if [ $(ip route | grep -c "^default" ) -eq 0 ]
then

    echo "Gateway not configured"

    exit 7

fi

gateway=$(ip route | grep "^default" | cut -d ' ' -f3)

if [ $(ping -i 0.5 -c 3 $gateway | grep -c '3 received') -eq 0 ]
then

    echo "Unable to ping the configured gateway"
    exit 8
fi

gateway=$(ip route | grep "default" | cut -d ' ' -f3)

if ! ping -i 0.2 -c 3 $PINGIP &>/dev/null
then
    echo "Unable to ping the router '$PINGIP'."
    exit 9
fi

counter=0
errors=0

for dns in $(awk '/^nameserver/ {print $2}' /etc/resolv.conf)
do
        counter=$(($counter+1))
        if ! host -t a $TSTDOM $dns &>/dev/null
        then
                echo "Warning: '$dns' dns fails"
                errors=$(($errors+1))
        fi
done

if [ $counter -eq 0 ]
then
        echo "You have no DNS configured"
        exit 10
elif [ $counter -eq $errors ]
then
        echo "None of your configured DNS work"
        exit 11
fi

if [ $(curl -s https://$TSTDOM | grep -c $TSTSTRING) -eq 0 ]
then
        echo "Probably blocked by the proxy"
        exit 12
fi

echo 'Internet connection seems correctly configured by your side. Check with your ISP if you keep having troubles.'
