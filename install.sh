#!/usr/bin/env bash

clear

# Set these to change the version of ELLI to install
TARBALLURL="https://github.com/elliotproject/elli/releases/download/v0.9.14/elli-0.9.14-x86_64-linux-gnu.tar.gz"
TARBALLNAME="elli-0.9.14-x86_64-linux-gnu.tar.gz"
ELLIVERSION="0.9.14"

# Check if we are root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root." 1>&2
    exit 1
fi

# Check if we have enough memory
if [[ `free -m | awk '/^Mem:/{print $2}'` -lt 512 ]]; then
    echo "This installation requires at least 512MB of RAM.";
    exit 1
fi

# Check if we have enough disk space
if [[ `df -k --output=avail / | tail -n1` -lt 5000000 ]]; then
    echo "This installation requires at least 5GB of free disk space.";
    exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
clear

echo "
MMMMMMMMMMMMMMNKkoc,...        ...,:ox0NMMMMMMMMMMMMMM
MMMMMMMMMMMXkl,.                      .'cxXWMMMMMMMMMM
MMMMMMMMNOc.                              .:kNMMMMMMMM
MMMMMMNx,           .;cccccccccccccccccccccclOWMMMMMMM
MMMMWO,            ,K0olllllllllllllllllllllllloOWMMMM
MMMXl.             lMl                          .cXMMM
MMK;               lMl                            ,0MM
MK,                lMl                             '0M
X:                 cWx''''''''''''''''''''''''''''''oN
o                  .:xkxxxxxxxxxxxxxxxxxxxxxxxxxxxxxkK
,        .'''''''''''',,,,,,,,,,,,,,,,,,,,,,,,..     ,
.      'kOxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxOx.
       dNc                                    oWl
       dN:                                    cWl
       dN:                                    cWl
.      oNc                                    oWl    .
:      'kOxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxOx.    ;
O'      .',;;,,,,,,,,,,,,,,,,,,,,,,''''''''''..     .x
WKkxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxd,               oW
MMO;..............................;O0'             lNM
MMWk.                             .xK,           .dNMM
MMMM0:                            .xK,          ,OWMMM
MMMMMNx,                          .xK,        .dNMMMMM
MMMMMMMNkoooooooooooooooooooooooooxKx.      ,dXMMMMMMM
MMMMMMMMMMMNOoccccccccccccccccccccc,.    'ckNMMMMMMMMM
MMMMMMMMMMMMNOd:'.                  .':oONMMMMMMMMMMMM
MMMMMMMMMMMMMMMMNOo:'..         .';okXMMMMMMMMMMMMMMMM
"

sleep 5

USER=root

USERHOME=`eval echo "~$USER"`

read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
read -e -p "Masternode Private Key (e.g. 8edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
read -e -p "Install UFW and configure ports? [Y/n] : " UFW

clear

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude
apt -qq update > /dev/null 2>&1
apt -qq -y dist-upgrade > /dev/null 2>&1
apt -qq -y autoremove > /dev/null 2>&1
apt -qq autoclean > /dev/null 2>&1

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
    aptitude -y -q install fail2ban
    touch /etc/fail2ban/jail.local
    cat > /etc/fail2ban/jail.local << EOL
[ssh]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 6
bantime = 3600
bantime.increment = true
bantime.rndtime = 10m
EOL
    service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
    apt-get -qq install ufw
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 61317/tcp
    yes | ufw enable
fi

# Install ELLI daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME
rm $TARBALLNAME
cp ./elli-$ELLIVERSION/bin/ellid /usr/local/bin
cp ./elli-$ELLIVERSION/bin/elli-cli /usr/local/bin
cp ./elli-$ELLIVERSION/bin/elli-tx /usr/local/bin
rm -rf elli-$ELLIVERSION

# Create .elli directory
mkdir $USERHOME/.elli

# Create elli.conf
touch $USERHOME/.elli/elli.conf
cat > $USERHOME/.elli/elli.conf << EOL
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:61317
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
EOL
chmod 0600 $USERHOME/.elli/elli.conf
chown -R $USER:$USER $USERHOME/.elli

sleep 1

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

echo "" && echo "Masternode setup completed." && echo ""
