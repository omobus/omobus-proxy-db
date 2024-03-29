#!/bin/sh

# Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file.

dbname=omobus-proxy-db

if [ `whoami` != "omobus" ]; then
    echo Please, execute tis stript from omobus system account.
    echo 
    exit 1
fi

if [ `psql -l | grep -c $dbname` != "0" ]; then
    echo $dbname already exist!
    echo Please, remove $dbname before executing this script.
    echo 
    exit 1
fi

psql -d postgres -c \
    "CREATE DATABASE \"$dbname\" WITH OWNER = omobus ENCODING = 'UTF8' TABLESPACE = pg_default CONNECTION LIMIT = 30"

psql -d $dbname -f ./omobus-proxy-db.master.sql
psql -d $dbname -f ./omobus-proxy-db.console.sql
psql -d $dbname -f ./omobus-proxy-db.logs.sql
psql -d $dbname -f ./omobus-proxy-db.shadows.sql
psql -d $dbname -f ./omobus-proxy-db.slices.sql
psql -d $dbname -f ./omobus-proxy-db.streams.sql
psql -d $dbname -f ./omobus-proxy-db.RU.sql
psql -d $dbname -f ./version.sql

for i in ./req_*.sql; do
    psql -d $dbname -f "$i"
done;

exit 0
# The end of the script.
