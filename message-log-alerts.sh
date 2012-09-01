#!/bin/bash

MSGLOG=/var/log/messages
TMPLOG=/tmp/tmp-message-log-last
EMAILMSG=/tmp/tmp-email-msg-messages.txt
TMPFILE=/tmp/tmp-last-alerts.txt
BLACKLISTFILE=/root/iptables/blacklist.zone

EXCEPTIONS="autoc_item.php"

SUBJECT="FFXIAH.com - Messages Log"
EMAILADDYS="scragg@gmail.com mike.scragg@gmail.com"

hinit() {
    rm -f /tmp/hashmap.$1
    touch /tmp/hashmap.$1
}

hput() {
    echo "$2 $3" >> /tmp/hashmap.$1
}

hget() {
    grep "^$2 " /tmp/hashmap.$1 | awk '{ print $2 };'
}

hinit ips

# Make sure files exist
touch $TMPLOG $EMAILMSG

# Clean email message file
echo -n '' > $EMAILMSG

# Check and validate tmptime
TMPTIME=$(head -n 1 $TMPLOG)
if [[ ! "$TMPTIME" =~ [0-9]+ ]] ; then
	TMPTIME=0
fi

NEWEST=0
SEND=0

# Load blacklist file in hash to avoid dupes
while read line
do
	hput ips $line 1
done < $BLACKLISTFILE

tail -n 100 $MSGLOG | egrep 'suhosin' > $TMPFILE

CYEAR=$(date --date now +%Y)
CMONTH="$(date --date now +%m | sed 's/^0//')"

while read line
do
	if [[ -n $(echo $line | egrep "($EXCEPTIONS)") ]] ; then
		continue;
	fi

	
	date=$(echo $line | cut -f1,2,3 -d' ')
	
	year=$CYEAR

	if [ $CMONTH -eq 1 ]; then	
		if [ "$(echo $date | egrep 'Dec')" != "" ]; then
			year=$CYEAR-1
		fi
	fi

	date=$(echo $date | sed "s/^\(.* .*\) \(.*\)/\1 $year \2/")
	
	timestamp=$(date --date "$date" +%s)
	echo $date
	echo $timestamp
	echo $TMPTIME
	if [ $timestamp -gt $TMPTIME ] ; then
		if [ $timestamp -gt $NEWEST ] ; then
			NEWEST=$timestamp
		fi
		if [ "$(echo $line | egrep 'attacker')" != "" ] ; then
			IP=$(echo $line | sed "s/.*attacker '\([0-9\.]*\)'.*/\1/")
			# This means no IP found
			if [ $line == $IP ] ; then 
				continue
			fi
			
			#echo $(hget ips $IP);
			if [ "$(hget ips $IP)" != "1" ] ; then
				echo $IP >> $BLACKLISTFILE
				hput ips $IP 1
				/sbin/iptables -A BLACKLIST -s $IP -j DROP
			fi
		fi 
		SEND=1
		echo $line >> $EMAILMSG
	fi
	
done < $TMPFILE

rm -f $TMPFILE

# Update the tmp timestamp
if [ $NEWEST -gt $TMPTIME ] ; then
	echo $NEWEST > $TMPLOG
fi

# Send any new files
if [ "$SEND" -eq 1 ] ; then
	for email in $EMAILADDYS
	do
		echo "Sending mail."
		/bin/mail -s "$SUBJECT" "$email" < $EMAILMSG
	done
fi

echo -n '' > $EMAILMSG
