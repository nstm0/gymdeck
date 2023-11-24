#!/bin/bash

# Check for root privileges
if [ "$(id -u)" != "0" ]
then
    echo "This script must be run with root privileges"
    exit 1
fi

installDIR='/home/deck/.gymdeck'
settingsFILE="$installDIR/settings.yaml"

mkdir -p $installDIR
if [ -f "$settingsFILE" ]
then
  cp $settingsFILE ./settings.yaml.old
fi

cp ./bin/* $installDIR/

if [ -f ./settings.yaml.old ]
then
  cp ./settings.yaml.old $settingsFILE
fi

chown -R deck:users $installDIR
setcap cap_kill+ep $installDIR/startExperimental
setcap cap_kill+ep $installDIR/reloadSettings

cp ./assets/gymdeck.service /etc/systemd/system/

systemctl daemon-reload

systemctl enable gymdeck.service
systemctl restart gymdeck.service