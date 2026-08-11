### this script resolve all url in /etc/nginx/nginx.conf and append it to /etc/hosts IF NOT ALREADY PRESENT
* this will backup /etc/hosts before make any change and tag its chnage in that file too
```
#!/bin/bash
set -x

cat /etc/nginx/nginx.conf|grep proxy_pass|grep -v '#'|sed 's/^ *//'|grep -iv header|awk '{print $2}'|grep -i http|sed 's/^ *//'|cut -d'/' -f3 > /tmp/sina.txt
cat /etc/nginx/nginx.conf|grep -w "server"|grep -v '#'|grep -v '{'|awk '{print $2}'|sed 's/^ *//'|cut -d'/' -f3 >> /tmp/sina.txt

INPUT="/tmp/sina.txt"
HOSTS="/etc/hosts"
FAILED="$HOSTS"
cp $HOSTS $HOSTS.$(date +%Y%m%d-%H%M%S)

echo "########### added by script in $(date +%Y%m%d-%H%M%S) ###############" >> $HOSTS


while IFS= read -r line; do
    host=$(echo "$line" | sed 's/[[:space:];]*$//' | sed 's/:.*$//' | xargs)

    [ -z "$host" ] && continue

    # Skip if already an IPv4 address
    if [[ "$host" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        continue
    fi

    # Resolve
    ip=$(getent ahostsv4 "$host" | awk 'NR==1 {print $1}')

    if [ -z "$ip" ]; then
        echo "$host failed" >> "$FAILED"
        continue
    fi

    # Show only successful resolutions
    echo "$ip $host"

    # Add to /etc/hosts if hostname doesn't already exist
    if ! grep -Ev '^[[:space:]]*#' "$HOSTS" | grep -Eq "[[:space:]]$host([[:space:]]|$)" ; then
        echo "$ip $host" >> "$HOSTS"
    fi

done < "$INPUT"


echo "########### done ###############" >> $HOSTS

```
