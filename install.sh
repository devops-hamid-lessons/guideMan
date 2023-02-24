#! /bin/bash

if [ $EUID != 0 ]; then
  echo "You are not the root user. Please first become root and then try again."
  exit 1
fi

if [ ! $(command -v ifconfig) ]; then
  echo "net-tools is not installed"
  echo "installing net-tools..."
  sudo apt-get update
  if [ $? != 0 ]; then
    echo "there is a problem with your Internet Connection. <apt-get update> command failed. Try again"
    echo "********************** configuration failed :((( ********************"
    exit 1
  fi
  sudo DEBIAN_FRONTEND=noninteractive apt-get -yq install net-tools
  if [ $? != 0 ]; then
    echo "there is a problem with your Internet Connection. <apt-get install net-tools> command failed. Try again"
    echo "********************** configuration failed :((( ********************"
    exit 1
  fi
  echo "net-tools installed: OK"
else
  echo "net-tools is installed on your system."
fi


INTERFACE=$(route | awk '/default/ {print $8}')
touch installationTempFile
echo "net.ipv4.conf.all.rp_filter = 2" >installationTempFile
echo "net.ipv4.conf.default.rp_filter = 2" >>installationTempFile
echo "net.ipv4.conf.$INTERFACE.rp_filter = 2" >>installationTempFile
if [ ! $(sudo sysctl --system | egrep -x -f installationTempFile | wc -l) == 3 ]; then
  cp installationTempFile /etc/sysctl.d/vpnSplitor.conf
  if [ $? != 0 ]; then
    echo "Unable to copy configuration into /etc/sysctl.d. Try again"
    echo "********************** configuration failed :((( ********************"
    rm installationTempFile
    exit 1
  fi
  rm installationTempFile
  sudo sysctl --system
fi
rm installationTempFile
echo "********************** configuration is complete. ********************"
