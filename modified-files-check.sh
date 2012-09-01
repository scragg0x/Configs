#!/bin/bash

DAYSOLD=1
WWWDIR=/var/www
MODLOG=/var/log/modified-files.log
TMPLOG=/tmp/tmp-modified-time.log
EMAILMSG=/tmp/tmp-email-msg.txt
SUBJECT="FFXIAH.com - Modified File Log"
EMAILADDYS="scragg@gmail.com mike.scragg@gmail.com"

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

MODFILES=$(find $WWWDIR -mtime -$DAYSOLD | egrep 'html$|js$|php$')

for modfile in $MODFILES
do
	timestamp=$(ls -l --time-style="+%Y%m%d%H%M%S" $modfile | cut -f6 -d' ')
	if [ $timestamp -gt $TMPTIME ] ; then
		if [ $timestamp -gt $NEWEST ] ; then
			NEWEST=$timestamp
		fi
		SEND=1
		ls -l $modfile >> $EMAILMSG
		ls -l $modfile >> $MODLOG
	fi
	
done

# Update the tmp timestamp
if [ $NEWEST -gt $TMPTIME ] ; then
	echo $NEWEST > $TMPLOG
fi

# Send any new files
if [ "$SEND" -eq 1 ] ; then
	for email in $EMAILADDYS
	do
		/bin/mail -s "$SUBJECT" "$email" < $EMAILMSG
	done
fi

echo -n '' > $EMAILMSG
