#!/bin/bash

#cleanup earlier bad runs
rm -f /tmp/pipe.in
rm -f /tmp/pipe.out

killall -9 nc 2>/dev/null
killall -9 cat 2>/dev/null


if netstat -anp | grep LISTEN | grep ":80 "
then
 echo "Please shutdown this appliction which is using port 80 because we need it to root the toon."
# exit
fi

/sbin/iptables -F FORWARD

echo "First bring up your Toon and wait until it is in the activation screen. Connect to your active-toon-wifi and wait until the service center is connected and you are able to push the 'activate' button."
echo "Then, press the activate button on the Toon but don't give it a code yet. Press [enter] to go on with this script."
read QUESTION
echo "Blocking all HTTPS (and therefore Toon VPN). Now we wait until the Toon disconnects the VPN and sends traffic towards the service center on the wifi. After a minute or so start the activation (use a random activation code and retry until it succeeds. Don't go back to the home activation screen."
/sbin/iptables -I FORWARD -p tcp --dport 443 -j DROP

OUTPUT=`/usr/sbin/tcpdump -n -i wlan0 dst net 172.16.0.0/12 -c 1 2>/dev/null` || exit "tcpdump failed"
IP=`echo $OUTPUT | cut -d\  -f5 | cut -d\. -f1,2,3,4`


echo "The Toon is connecting to IP: $IP"

echo "Let's have some fun! Try another activation."

/sbin/ip addr add $IP/32 dev lo 2>/dev/null


[ -f /tmp/pipe.in ] || /usr/bin/mkfifo /tmp/pipe.in
[ -f /tmp/pipe.out ] || /usr/bin/mkfifo /tmp/pipe.out

RESPONSE='HTTP/1.1 200 OK\n\n


<action xmlns:u="http://schema.homeautomationeurope.com/quby" class="response" uuid="0429a450-bd0c-11e0-962b-0800200c9a66" destuuid="_DESTUUID_" destcommonname="_DESTCOMMONNAME_" requestid="_REQUESTID_" serviceid="urn:hcb-hae-com:serviceId:quby">\n
  <u:getInformationForActivationCodeResponse>\n
    <Success>true</Success>\n
    <Reason>Success</Reason>\n
  </u:getInformationForActivationCodeResponse>\n
</action>\n
'

DONE=false

while ! $DONE 
do
cat /tmp/pipe.out | nc -q 0 -Nl 31080 | tee /tmp/pipe.in &

while read line
do
echo $LINE
if [[ $line = *"action class"* ]]
then
  COMMONNAME=`echo $line | sed 's/.* commonname="\(.*\)".*/\1/'`
  UUID="$COMMONNAME:happ_scsync" 
  REQUESTID=`echo $line | sed 's/.* requestid="\(.*\)" .*/\1/'`
  TOSEND=`echo $RESPONSE | sed "s/_REQUESTID_/$REQUESTID/" | sed "s/_DESTCOMMONNAME_/$COMMONNAME/" | sed "s/_DESTUUID_/$UUID/" `
fi
if [[ $line = *"<u:getInformation"* ]]
then
  echo "Ok sending the reponse for the activation request"
  echo -e $TOSEND > /tmp/pipe.out
  DONE=true
fi
  
done < /tmp/pipe.in

done

echo "I received the activation request and send back a bogues reponse to allow the activation to proceed. Go on and accept the shown empty settings."

RESPONSE='HTTP/1.1 200 OK\n\n


<action xmlns:u="http://schema.homeautomationeurope.com/quby" class="response" uuid="0429a450-bd0c-11e0-962b-0800200c9a66" destuuid="_DESTUUID_" destcommonname="_DESTCOMMONUUID_" requestid="_REQUESTID_" serviceid="urn:hcb-hae-com:serviceId:quby">\n
  <u:RegisterQubyResponse>\n
    <StartDate>0</StartDate>\n
    <EndDate>-1</EndDate>\n
    <Status>IN_SUPPLY</Status>\n
    <ProductVariant>Toon</ProductVariant>\n
    <SoftwareUpdates>true</SoftwareUpdates>\n
    <ElectricityDisplay>false</ElectricityDisplay>\n
    <GasDisplay>false</GasDisplay>\n
    <HeatDisplay>false</HeatDisplay>\n
    <ProduDisplay>false</ProduDisplay>\n
    <ContentApps>false</ContentApps>\n
    <TelmiEnabled>false</TelmiEnabled>\n
    <HeatWinner>false</HeatWinner>\n
    <ElectricityOtherProvider>false</ElectricityOtherProvider>\n
    <GasOtherProvider>false</GasOtherProvider>\n
    <DistrictHeatOtherProvider>false</DistrictHeatOtherProvider>\n
    <CustomerName>TSC</CustomerName>\n
    <Success>true</Success>\n
    <Reason>Success</Reason>\n
    <ReasonDetails>Success</ReasonDetails>\n
  </u:RegisterQubyResponse>\n
</action>\n
'

DONE=false

while ! $DONE 
do
cat /tmp/pipe.out | nc -q 0 -Nl 31080 | tee /tmp/pipe.in &

while read line
do
echo $LINE
if [[ $line = *"action class"* ]]
then
  COMMONNAME=`echo $line | sed 's/.* commonname="\(.*\)".*/\1/'`
  UUID="$COMMONNAME:happ_scsync" 
  REQUESTID=`echo $line | sed 's/.* requestid="\(.*\)" .*/\1/'`
  TOSEND=`echo $RESPONSE | sed "s/_REQUESTID_/$REQUESTID/" | sed "s/_DESTCOMMONNAME_/$COMMONNAME/" | sed "s/_DESTUUID_/$UUID/" `
fi
if [[ $line = *"<u:RegisterQuby"* ]]
then
  echo "Ok sending the reponse for the activation confirm request"
  echo -e $TOSEND > /tmp/pipe.out
  DONE=true
fi
  
done < /tmp/pipe.in

done

echo "And that it! We activated the toon. However in the main activation screen you can not proceed yet. Don'd worry. Just reboot your toon after 10 seconds by unplugging the power and it will bring you back to the activation screen but now you can press the finish button on the top right."
