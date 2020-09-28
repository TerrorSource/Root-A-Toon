# Root-A-Toon
Software for rooting a (dutch/belgian) Toon/Boxx using software and a wifi hotspot only

First you need to setup a Linux/Pi machine as a routed wifi hotspot, see for example https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
You goal must be that you can connect your Toon to the routed wifi hotspot and have internet on the Toon. The reason for this is that the script will need to intercept Toon internet traffic.

The script is tested on Debian Buster so you better have that installed or be prepared to modify the script a bit.

Next, make sure tcpdump is installed: ```sudo apt install tcpdump```

## Rooting test run

To start a rooting test run which does not modify the Toon yet you can issue ```sudo ./root-toon.sh```
This will initiate a qt-gui restart if the root access is succesfull. 

## Rooting with payload

The payload file contains the script which is run when the main script has root access. The payload script in the repository will block VPN, edit firewall, change password to 'toon', install dropbear (SSH access) and finally run a update-script with -f option to finish a complete rooted toon. But you can create your own payload if you like.

To initiate a Toon root with payload initiate the script with ```sudo ./root-toon.sh payload```




