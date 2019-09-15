#!/bin/sh

# Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file.

# This script downloads information about mobile network celltowers from
# the Mozilla Location Service: 
#         https://location.services.mozilla.com/downloads

DATE=/bin/date
ECHO=/bin/echo
RM=/bin/rm
MV=/bin/mv
CHMOD=/bin/chmod
CHOWN=/bin/chown
GZIP=/bin/gzip
WGET=/usr/bin/wget
MKDIR=/bin/mkdir
PSQL=/usr/local/libexec/pgsql-9.6/bin/psql
SU=/bin/su

database=/var/lib/omobus.d/celltowers
fname=MLS
flag=0
copyscript="truncate table celltowers.\"$fname\";COPY celltowers.\"$fname\"(mcc,mnc,cid,lac,latitude,longitude,radio,changeable) FROM '$database/$fname.txt' DELIMITER ',' CSV HEADER;"

$MKDIR -p $database
$WGET -O $database/$fname.csv.gz https://d3r3tk5171bc5t.cloudfront.net/export/MLS-full-cell-export-`$DATE +%Y-%m-%d`T000000.csv.gz
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
    $ECHO "$copyscript" | $SU omobus -c "$PSQL -d omobus-proxy-db"
fi

$RM -f $database/.$fname.txt $database/$fname.csv $database/$fname.csv.gz

exit 0
