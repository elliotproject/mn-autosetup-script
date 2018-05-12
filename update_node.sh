#!/usr/bin/env bash

TARBALLURL="https://github.com/elliotproject/elli/releases/download/v0.9.14/elli-0.9.14-x86_64-linux-gnu.tar.gz"
TARBALLNAME="elli-0.9.14-x86_64-linux-gnu.tar.gz"
ELLIVERSION="0.9.14"

CHARS="/-\|"

clear
echo "This script will update your masternode to version $ELLIVERSION"
read -p "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

USER=`ps u $(pgrep ellid) | grep ellid | cut -d " " -f 1`
USERHOME=`eval echo "~$USER"`

echo "Shutting down masternode..."
if [ -e /etc/systemd/system/ellid.service ]; then
    systemctl stop ellid
else
    su -c "elli-cli stop" $USER
fi

echo "Installing ELLI $ELLIVERSION..."
mkdir ./elli-temp && cd ./elli-temp
wget $TARBALLURL
tar -xzvf $TARBALLNAME && mv bin elli-$ELLIVERSION
yes | cp -rf ./elli-$ELLIVERSION/ellid /usr/local/bin
yes | cp -rf ./elli-$ELLIVERSION/elli-cli /usr/local/bin
cd ..
rm -rf ./elli-temp

if [ -e /usr/bin/ellid ];then rm -rf /usr/bin/ellid; fi
if [ -e /usr/bin/elli-cli ];then rm -rf /usr/bin/elli-cli; fi
if [ -e /usr/bin/elli-tx ];then rm -rf /usr/bin/elli-tx; fi

sed -i '/^addnode/d' $USERHOME/.elli/elli.conf

echo "Restarting ELLI daemon..."
if [ -e /etc/systemd/system/ellid.service ]; then
    systemctl start ellid
else
  cat > /etc/systemd/system/ellid.service << EOL
[Unit]
Description=ellid
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/ellid -conf=${USERHOME}/.elli/elli.conf -datadir=${USERHOME}/.elli
ExecStop=/usr/local/bin/elli-cli -conf=${USERHOME}/.elli/elli.conf -datadir=${USERHOME}/.elli stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
    sudo systemctl enable ellid
    sudo systemctl start ellid
fi
clear

cat << EOL

Now, you need to start your masternode. Please go to your desktop wallet and
enter the following line into your debug console:

startmasternode alias false <mymnalias>

where <mymnalias> is the name of your masternode alias (without brackets)

EOL

read -p "Press any key to continue after you've done that. " -n1 -s

clear

echo "Your masternode is syncing. Please wait for this process to finish."

until su -c "elli-cli startmasternode local false 2>/dev/null | grep 'successfully started' > /dev/null" $USER; do
    for (( i=0; i<${#CHARS}; i++ )); do
        sleep 2
        echo -en "${CHARS:$i:1}" "\r"
    done
done

su -c "elli-cli masternode status" $USER

cat << EOL

Masternode update completed.

EOL
