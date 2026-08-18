cd /var/lotus/libs/
#find all url lines and save /tmp/sina.txt
find . -type f -iname '*.properties' -exec grep -E 'http|url|uri|192.168' '{}' \;|grep -v '#'|cut -d'=' -f2|grep -vE '192.168.247.197|192.168.247.124'|sort -u > /tmp/sina.txt
# check connection to all url contain both ip and port
for i in $(cat /tmp/sina.txt |cut -d '/' -f3|sort -u|grep ':'|grep '\.'|grep -v ','|sed 's/^ *//'|sort -u);do ip=$(echo $i|cut -d':' -f1) && port=$(echo $i|cut -d':' -f2) && nc -w 3 -zv $ip $port 2> /dev/null ;if [ "$(echo $?)" != "0" ] ;then echo "$i timeout";fi ; done
# check connection to all url contain both ip and port:443
for i in $(cat /tmp/sina.txt |cut -d '/' -f1-3|grep https|cut -d '/' -f3|grep -v ':'|grep '\.'|grep -v ','|sed 's/^ *//'|sort -u);do ip=$(echo $i|cut -d':' -f1) && port=$(echo $i|cut -d':' -f2) && nc -w 3 -zv $ip 443 2> /dev/null ;if [ "$(echo $?)" != "0" ] ;then echo "$i:443 timeout";fi ; done
# check connection to all url contain both ip and port:80
for i in $( cat /tmp/test.txt |cut -d '/' -f1-3|grep -v https|cut -d '/' -f3|grep -v ':'|grep '\.'|grep -v ','|sed 's/^ *//'|sort -u);do ip=$(echo $i|cut -d':' -f1) && port=$(echo $i|cut -d':' -f2) && nc -w 3 -zv $ip 80 2> /dev/null ;if [ "$(echo $?)" != "0" ] ;then echo "$i:80 timeout";fi ; done
