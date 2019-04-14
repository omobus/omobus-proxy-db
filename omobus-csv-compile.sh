#!/bin/sh

# Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file.

IN=/var/ftp/maintain/CSV/IN
erp2omobus=/var/ftp/maintain/CSV/e2o

rm -f $erp2omobus/__unlocked__
rm -f $erp2omobus/*.csv

for i in $IN/*.csv
do 
    hash=`md5sum $i`
    fn=`basename $i`
    result=$erp2omobus/${fn%.csv}+${hash% *}.csv
    `sed -e 's/\r//g' $i | sed -e 's/|/;/g' | sed -e 's/$/;/g' | sed -e 's/;@/;/g' | sed -e 's/@;/;/g' | sed -e 's/; /;/g' | sed -e 's/#REF!//g' | sed -e 's/  / /g' > $result`
done

touch $erp2omobus/__unlocked__