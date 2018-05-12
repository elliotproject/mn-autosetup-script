#!/usr/bin/env bash

clear
echo "This script will refresh your masternode."
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

USER=`ps u $(pgrep ellid) | grep ellid | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

if [ -e /etc/systemd/system/ellid.service ]; then
    systemctl stop ellid
else
    su -c "elli-cli stop" $ELLIUSER
fi

echo "Refreshing node, please wait."

sleep 5

rm -rf $USERHOME/.elli/blocks
rm -rf $USERHOME/.elli/database
rm -rf $USERHOME/.elli/chainstate
rm -rf $USERHOME/.elli/peers.dat

cp $USERHOME/.elli/elli.conf $USERHOME/.elli/elli.conf.backup
sed -i '/^addnode/d' $USERHOME/.elli/elli.conf

if [ -e /etc/systemd/system/ellid.service ]; then
    sudo systemctl start ellid
else
    su -c "ellid -daemon" $USER
fi

echo "Your masternode is syncing. Please wait for this process to finish."
echo "This can take up to a few hours. Do not close this window." && echo ""

until su -c "elli-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
    for (( i=0; i<${#CHARS}; i++ )); do
        sleep 2
        echo -en "${CHARS:$i:1}" "\r"
    done
done

sleep 1
su -c "/usr/local/bin/elli-cli startmasternode local false" $USER
sleep 1
clear
su -c "/usr/local/bin/elli-cli masternode status" $USER
sleep 5

echo "" && echo "Masternode refresh completed." && echo ""
