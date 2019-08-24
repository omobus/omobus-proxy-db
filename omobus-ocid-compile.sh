#!/bin/sh

# Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file.

DATE=/bin/date
ECHO=/bin/echo
RM=/bin/rm
MV=/bin/mv
CHMOD=/bin/chmod
CHOWN=/bin/chown
GZIP=/bin/gzip
WGET=/usr/bin/wget

database=/var/lib/pgsql/data/omobus
fname=OCID-celltowers
flag=0

$WGET -O $database/$fname.csv.gz http://ocid.omobus.org:8080/OCID-celltowers.csv.gz
$GZIP -d $database/$fname.csv.gz

$ECHO "mcc,mnc,cid,lac,latitude,longitude,radio,changeable" > $database/.$fname.txt

while IFS="," read radio mcc net area cell unit lon lat range samples changeable created updated averageSignal
do
    if [ "$mcc" = "250" ]; then # RU
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "257" ]; then # BY
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "401" ]; then # KZ
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "282" ]; then # GE
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "400" ]; then # AZ
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "283" ]; then # AM
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "434" ]; then # UZ
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "259" ]; then # MD
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "428" ]; then # MN
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    elif [ "$mcc" = "437" ]; then # KG
	$ECHO "$mcc,$net,$cell,$area,$lat,$lon,$radio,$changeable" >> $database/.$fname.txt
	flag=1
    fi;
done < $database/$fname.csv

IFS="$OLD_IFS"

if [ "$flag" != "0" ]; then
    $CHMOD 0644 $database/.$fname.txt
    $CHOWN postgres:postgres $database/.$fname.txt
    $RM -f $database/$fname.txt
    $MV $database/.$fname.txt $database/$fname.txt
fi

$RM -f $database/.$fname.txt $database/$fname.csv $database/$fname.csv.gz

exit 0
