/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema celltowers;

create table celltowers."MLS" (
    mcc 		int32_t 	not null, /* mobile country code */
    mnc 		int32_t 	not null, /* mobile network code */
    cid 		int32_t 	not null, /* cell tower ID */
    lac 		int32_t 	not null, /* local area code */
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    radio 		text 		not null,
    changeable 		bool_t 		not null, /* defines if coordinates of the cell tower are exact (0) or approximate (1). */
    primary key(mcc, mnc, cid, lac, radio)
);

create index i_celltower_mls on celltowers."MLS" (mcc, mnc, cid, lac);

create table celltowers."OCID" (
    mcc 		int32_t 	not null, /* mobile country code */
    mnc 		int32_t 	not null, /* mobile network code */
    cid 		int32_t 	not null, /* cell tower ID */
    lac 		int32_t 	not null, /* local area code */
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    radio 		text 		not null,
    changeable 		bool_t 		not null, /* defines if coordinates of the cell tower are exact (0) or approximate (1). */
    primary key(mcc, mnc, cid, lac)
);

create table celltowers."OCID" (
    mcc 		int32_t 	not null, /* mobile country code */
    mnc 		int32_t 	not null, /* mobile network code */
    cid 		int32_t 	not null, /* cell tower ID */
    lac 		int32_t 	not null, /* local area code */
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    radio 		text 		not null,
    changeable 		bool_t 		not null, /* defines if coordinates of the cell tower are exact (0) or approximate (1). */
    primary key(mcc, mnc, cid, lac)
);
