# Root-A-Toon
Software for rooting a (dutch/belgian) Toon/Boxx using software and a wifi hotspot only.

## What do I need?
First you need to setup a Linux/Pi machine as a routed wifi hotspot, see for example https://www.raspberrypi.org/documentation/configuration/wireless/access-point-routed.md
You goal must be that you can connect your Toon to the routed wifi hotspot and have internet on the Toon. The reason for this is that the script will need to intercept Toon internet traffic.

The script is tested on Debian Buster so you better have that installed or be prepared to modify the script a bit.

Next, make sure tcpdump is installed: ```sudo apt install tcpdump```

## Rooting test run

To start a rooting test run which does not modify the Toon yet you can issue ```sudo bash root-toon.sh```
This will initiate a qt-gui restart if the root access is succesfull. 

## Rooting with payload

The payload file contains the script which is run when the main script has root access. The payload script in the repository will block VPN, edit firewall, change password to 'toon', install dropbear (SSH access) and finally run a update-script with -f option to finish a complete rooted toon. But you can create your own payload if you like.

To initiate a Toon root with payload initiate the script with ```sudo bash root-toon.sh payload```

## How is root access possible?
The script intercepts Toon traffic as it is trying to create a VPN connection towards the Toon servicecenter. First it starts blocking port 443 which results in blocking this VPN access (and also other traffic, but that is not a problem during rooting). Next, the Toon will try to access the servicecenter (from 172.16.0.0/12 address space) over the normal network port (wlan0 interface on the Toon) because there is no more-specific route over a (non existing) VPN connection anymore. The script will see this traffic (using tcpdump) and will store the IP address for the servicecenter which the Toon wants to talk to.

The next step for the script is to open a listen port (by using netcat) on port 31080 (the service center port) on the just learned service center IP address. The effect is that the Toon will simulate to be the servicecenter. Next, the user is requested to press the 'software' button on the Toon which in turn will cause the Toon to request the servicecenter if there is a software update available. This request is received by the script and a answer is given to the Toon with a hidden 'curl 1.1|sh' command within the 'new' version number. A bug in the Toon software which should download the version of the new software will run this hidden command. This will initiate a shell command on the Toon to download the payload from the machine running the script. Once the payload is downloaded by the Toon, this payload script will do the rest.

## What if my Toon needs to be activated first?
Without an activated toon you will not be able to root it using this script as you are unable to start the check for new software process. But there is a way to fool the toon to be activated. Use the activation script for this. If your toon is in the activation wizard, connect your toon to the wifi hotspot and let it connect to the internet. It will then show you an 'activate' button. From there start the activation script: ``sudo bash activate-toon.sh`` 

