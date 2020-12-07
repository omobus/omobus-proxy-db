/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create extension hstore;
/*create extension file_fdw;*/
create extension isn;
create extension "uuid-ossp";

/*create server fs foreign data wrapper file_fdw;*/


create sequence seq_accounts;
create sequence seq_activities;
create sequence seq_documents;
create sequence seq_mail_stream;
create sequence seq_manuals;
create sequence seq_tickets;


create domain address_t as varchar(256);
create domain blob_t as OID;
create domain blobs_t as OID array;
create domain bool_t as smallint check (value is null or (value between 0 and 1));
create domain code_t as varchar(24);
create domain codes_t as varchar(24) array;
create domain color_t as int4;
create domain country_t as varchar(2) check (value is null or (value = upper(value))); -- Country code, as described in the ISO 3166-1 alpha-2.
create domain countries_t as varchar(2) array; -- Country code, as described in the ISO 3166-1 alpha-2.
create domain currency_t as numeric(16,2);
create domain date_t as varchar(10);
create domain datetime_t as varchar(19);
create domain datetimetz_t as varchar(32);
create domain descr_t as varchar(256);
create domain devid_t as varchar(40) not null;
create domain doctype_t as varchar(24) check (value is null or (value = lower(value)));
create domain double_t as float8;
create domain discount_t as numeric(5,2) check (value is null or (value between -100 and 100));
create domain email_t as varchar(254) /*check(value is null or (char_length(value)>4 and position('@' in value)>1))*/;
create domain emails_t as varchar(254) array /*check(value is null or (char_length(value)>4 and position('@' in value)>1))*/;
create domain ftype_t as int2 default 0 not null check (value between 0 and 1);
create domain gps_t as numeric(10,6);
create domain hostname_t as varchar(255);
create domain int32_t as integer;
create domain int64_t as bigint;
create domain month_t as varchar(7);
create domain note_t as varchar(1024);
create domain numeric_t as numeric(16,4);
create domain lang_t as varchar(2) check (value is null or (value = lower(value))); -- Language code, as described in the ISO 639-1 alpha-2.
create domain phone_t as varchar(32); -- E.164 defines maximum phone number as 16 symbols (+ and 15 numbers)
create domain time_t as char(5);
create domain ts_auto_t as timestamp with time zone default current_timestamp not null;
create domain ts_t as timestamp with time zone;
create domain uid_t as varchar(48);
create domain uids_t as varchar(48) array;
create domain volume_t as numeric(10,6);
create domain weight_t as numeric(12,6);
create domain wf_t as numeric(3,2);


create or replace function tf_lock_update() returns trigger as
$body$
begin
    raise exception 'The % statement is disabled for the table %.', tg_op, upper(tg_table_name);
    return null;
end;
$body$
language 'plpgsql';

create or replace function tf_code() returns trigger as
$body$
begin
    new.code := nextval('seq_'||lower(TG_RELNAME)) || "paramUID"('db:id');
    return new;
end;
$body$
language 'plpgsql';

create or replace function tf_updated_ts() returns trigger as
$body$
begin
    new.updated_ts = current_timestamp;
    return new;
end;
$body$
language 'plpgsql';

create or replace function NIL(arg varchar, def varchar) returns varchar as
$body$
begin
    return case when arg = '' then def else arg end;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function NIL(arg varchar) returns varchar as
$body$
begin
    return case when arg = '' then null else arg end;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function NIL(arg numeric) returns numeric as
$body$
begin
    return arg;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function NIL(arg integer) returns integer as
$body$
begin
    return arg;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function NIL() returns integer as
$body$
begin
    return null;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function act_id(out doc_id_sys uid_t)
as $body$
declare
    db_id varchar(3);
begin
    select left(trim(param_value), 3) from sysparams where param_id='db:id' into db_id;
    doc_id_sys := 'A' || nextval('seq_activities')::varchar || case when db_id is null then '' else db_id end;
end;
$body$ language plpgsql;

create or replace function blob_length(bid blob_t) returns int32_t as
$body$
declare
    len int32_t;
begin
    select sum(length(lo.data)) from pg_largeobject lo where lo.loid=bid into len;
    return len;
end;
$body$
language plpgsql STABLE;

create or replace function demasquerading(xid uid_t) returns uid_t as
$body$
begin
    return split_part(xid, '!', 2);
end;
$body$
language plpgsql IMMUTABLE;

create or replace function demasquerading2(xid uid_t, out uid uid_t, out erp uid_t) as
$body$
declare
    ar uids_t;
begin
    ar := string_to_array(xid, '!');
    if( array_length(ar, 1) = 2 ) then
	uid := ar[2];
	erp := ar[1];
    else
	uid := xid;
	erp := null;
    end if;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function DateDiff(units varchar(30), start_ts timestamp, end_ts timestamp) returns int32_t 
as $BODY$
declare
    diff_interval interval; 
    diff int = 0;
    years_diff int = 0;
begin
    if units in ('yy', 'yyyy', 'year', 'mm', 'm', 'month') then
	years_diff = DATE_PART('year', end_ts) - DATE_PART('year', start_ts);

	if units in ('yy', 'yyyy', 'year') then
	    return years_diff;
	else
	    -- If end month is less than start month it will subtracted
	    return years_diff * 12 + (DATE_PART('month', end_ts) - DATE_PART('month', start_ts)); 
	end if;
    end if;

    -- Minus operator returns interval 'DDD days HH:MI:SS'  
    diff_interval = end_ts - start_ts;
    diff = diff + DATE_PART('day', diff_interval);

    if units in ('wk', 'ww', 'week') then
	diff = diff/7;
	return diff;
    end if;

    if units in ('dd', 'd', 'day') then
	return diff;
    end if;

    diff = diff * 24 + DATE_PART('hour', diff_interval); 

    if units in ('hh', 'hour') then
	return diff;
    end if;

    diff = diff * 60 + DATE_PART('minute', diff_interval);

    if units in ('mi', 'n', 'minute') then
	return diff;
    end if;

    diff = diff * 60 + DATE_PART('second', diff_interval);

    return diff;
end;
$BODY$ 
language plpgsql IMMUTABLE;

create or replace function DateDiff(units varchar(30), start_dt datetime_t, end_dt datetime_t) returns int32_t 
as $BODY$
begin
    return DateDiff(units, start_dt::timestamp, end_dt::timestamp);
end;
$BODY$ 
language plpgsql IMMUTABLE;

create or replace function DateDiff(start_dt datetime_t, end_dt datetime_t) returns int32_t
as $BODY$
begin
    return DateDiff('minute', start_dt, end_dt);
end;
$BODY$ 
language plpgsql IMMUTABLE;

create or replace function distance(la0 gps_t, lo0 gps_t, la1 gps_t, lo1 gps_t) returns int32_t 
as $body$
begin
    la0 := la0*PI()/180;
    la1 := la1*PI()/180;
    lo0 := lo0*PI()/180;
    lo1 := lo1*PI()/180;
    return case when la0 = 0 or lo0 = 0 or la1 = 0 or lo1 = 0 then null else cast(
	    --6372795.0 * atan(sqrt(power(cos(la1)*sin(lo0-lo1),2)+power(cos(la0)*sin(la1)-sin(la0)*cos(la1)*cos(lo0-lo1),2))/(sin(la0)*sin(la1)+cos(la0)*cos(la1)*cos(lo0-lo1)))
	    6372795.0 * atan2(sqrt(power(cos(la1) * sin(lo1 - lo0), 2) + pow(cos(la0) * sin(la1) - sin(la0) * cos(la1) * cos(lo1 - lo0), 2)), sin(la0) * sin(la1) + cos(la0) * cos(la1) * cos(lo1 - lo0))
	 as int)
    end;
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function doc_id(out doc_id_sys uid_t)
as $body$
declare
    db_id varchar(3);
begin
    select left(trim(param_value), 3) from sysparams where param_id='db:id' into db_id;
    doc_id_sys := 'D' || nextval('seq_documents')::varchar || case when db_id is null then '' else db_id end;
end;
$body$ language plpgsql;

create or replace function ean13_in(m text) returns ean13
as $body$
declare
    m text;
    x ean13;
begin
    if m is not null then
	perform isn_weak(true);
	m := trim(m);
	begin
	    x := ean13_in(m::cstring);
	exception when others then
	    --raise notice '[%s] is invalid EAN13 value.', m;
	end;
	--perform isn_weak(false);
    end if;
    return x;
end;
$body$ language plpgsql IMMUTABLE;

create or replace function ean13_in(ar text array) returns ean13 array
as $body$
declare
    m text;
    x ean13 array;
begin
    perform isn_weak(true);
    if ar is not null then
	foreach m in array ar
	loop
	    if m is not null then
		m := trim(m);
		begin
		    x := array_append(x, ean13_in(m::cstring));
		exception when others then
		    --raise notice '[%s] is invalid EAN13 value.', m;
		end;
	    end if;
	end loop;
    end if;
    --perform isn_weak(false);
    return x;
end;
$body$ language plpgsql IMMUTABLE;

create or replace function ean13_out(ar ean13 array) returns text array
as $body$
declare
    m ean13;
    x text array;
begin
    --perform isn_weak(true);
    if ar is not null then
	foreach m in array ar
	loop
	    if m is not null then
		x := array_append(x, replace(rtrim((ean13_out(m))::text,'!'),'-',''));
	    end if;
	end loop;
    end if;
    --perform isn_weak(false);
    return x;
end;
$body$ language plpgsql IMMUTABLE;

create or replace function format_a(fmt text, ar text array) returns text as
$body$
declare
    x text;
    k text;
    f smallint default 0;
begin
    if( fmt is null ) then
	return fmt;
    end if;

    for x in select unnest(ar)
    loop
	if( f = 0 ) then
	    k := x;
	    f := 1;
	else
	    if( k is not null and trim(k) <> '' ) then
		fmt := replace(fmt, format('$(%s)',k), case when x is null then '-' else x end);
	    end if;
	    f := 0;
	end if;
    end loop; 

    if( f = 1 and k is not null and trim(k) <> '' ) then
	fmt := replace(fmt, format('$(%s)',k), '-');
    end if;

    return fmt;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function man_id(out doc_id_sys uid_t)
as $body$
declare
    db_id varchar(3);
begin
    select left(trim(param_value), 3) from sysparams where param_id='db:id' into db_id;
    doc_id_sys := 'M' || nextval('seq_manuals')::varchar || case when db_id is null then '' else db_id end;
end;
$body$ language plpgsql;

create or replace function masquerading(uid uid_t, erp uid_t) returns uid_t as
$body$
begin
    return case when uid is null then null when erp is null then uid else format('%1$s!%2$s', erp, uid)::uid_t end;
end;
$body$
language plpgsql IMMUTABLE;

create or replace function "L10n_format_a"(f_lang_id lang_t, f_obj_code code_t, f_obj_id uid_t, f_obj_attr uid_t, ar text array, def text) returns text as
$body$
declare
    fmt text;
begin
    select str from "L10n" where lang_id=f_lang_id and obj_code=f_obj_code and obj_id=f_obj_id and obj_attr=f_obj_attr and hidden=0
	into fmt;

    return case when fmt is null then def else format_a(fmt, ar) end;
end;
$body$
language plpgsql STABLE;

create or replace function "L10n_format_a"(f_lang_id lang_t, f_obj_code code_t, f_obj_id uid_t, f_obj_attr uid_t, ar text array) returns text as
$body$
begin
    return "L10n_format_a"(f_lang_id, f_obj_code, f_obj_id, f_obj_attr, ar, null::text);
end;
$body$
language plpgsql STABLE;

create or replace function "L10n_format_a"(f_lang_id lang_t, f_obj_code code_t, f_obj_id uid_t, f_obj_attr uid_t) returns text as
$body$
begin
    return "L10n_format_a"(f_lang_id, f_obj_code, f_obj_id, f_obj_attr, null::text[], null::text);
end;
$body$
language plpgsql STABLE;

create or replace function "L"(arg timestamp with time zone) returns datetimetz_t
as $body$
begin
    return to_char(arg, 'DD.MM.YYYY HH24:MI:SS TZ');
end;
$body$ language plpgsql IMMUTABLE;

create or replace function "L"(arg timestamp) returns datetimetz_t
as $body$
begin
    return to_char(arg, 'DD.MM.YYYY HH24:MI:SS');
end;
$body$ language plpgsql IMMUTABLE;

create or replace function "L"(arg date) returns datetimetz_t
as $body$
begin
    return to_char(arg, 'DD.MM.YYYY');
end;
$body$ language plpgsql IMMUTABLE;

create or replace function "L"(arg datetime_t) returns datetimetz_t
as $body$
begin
    return to_char(arg::timestamp, 'DD.MM.YYYY HH24:MI:SS');
end;
$body$ language plpgsql IMMUTABLE;

create or replace function "L"(arg date_t) returns datetimetz_t
as $body$
begin
    return to_char(arg::date, 'DD.MM.YYYY');
end;
$body$ language plpgsql IMMUTABLE;

create or replace function quote_csv_string(arg text) returns text
as $body$
begin
    arg := replace(arg, '"', '""');
    if( arg ~ '("|,)' ) then
	arg := concat('"',arg,'"');
    end if;
    arg := replace(arg, E'\n', ' ');
    arg := replace(arg, E'\r', ' ');
    return arg;
end;
$body$ language plpgsql IMMUTABLE;

create or replace function orphanLO() returns setof blob_t
as $body$
declare
    b blob_t;
    schem name;
    rel name;
    attr name;
    categ char;
begin
    /*
     * Don't get fooled by any non-system catalogs
     */
--    set search_path = pg_catalog;

    /*
     * First we create and populate the LO temp table
     */
    create temp table  ".vacuumLO" as select oid as lo from pg_largeobject_metadata;

    /*
     * Analyze the temp table so that planner will generate decent plans for
     * the DELETEs below.
     */
    analyze  ".vacuumLO";

    /*
     * Now find any candidate tables that have columns of type oid.
     *
     * NOTE: we ignore system tables and temp tables by the expedient of
     * rejecting tables in schemas named 'pg_*'.  In particular, the temp
     * table formed above is ignored, and pg_largeobject will be too. If
     * either of these were scanned, obviously we'd end up with nothing to
     * delete...
     *
     * NOTE: the system oid column is ignored, as it has attnum < 1. This
     * shouldn't matter for correctness, but it saves time.
     */
    for schem, rel, attr, categ in 
	select s.nspname, c.relname, a.attname, t.typcategory from pg_class c, pg_attribute a, pg_namespace s, pg_type t 
	    where a.attnum > 0 and not a.attisdropped
		and a.attrelid = c.oid
		and a.atttypid = t.oid
		and c.relnamespace = s.oid
		and t.typname in ('oid', 'lo', 'blob_t', 'blobs_t')
		and c.relkind in ('r', 'm')
		and s.nspname !~ '^pg_'
    loop
	if( categ = 'A' ) then /* array */
	    execute 'DELETE FROM  ".vacuumLO" WHERE lo IN (SELECT unnest("' || attr || '") FROM ' || schem || '."' || rel || '" WHERE "' || attr || '" is not null);';
	else
	    execute 'DELETE FROM  ".vacuumLO" WHERE lo IN (SELECT "' || attr ||'" FROM ' || schem || '."' || rel || '" WHERE "' || attr || '" is not null);';
	end if;
    end loop;

    /*
     * Now, those entries remaining in  ".vacuumLO" are orphans.
     */
    for b in select lo from ".vacuumLO"
    loop
	return next b;
    end loop;

    /*
     * Drop temporary table.
     */
    drop table if exists ".vacuumLO";
end;
$body$ language plpgsql;

create or replace function orphanTHUMB() returns setof blob_t
as $body$
declare
    b blob_t;
    schem name;
    rel name;
    attr name;
    categ char;
begin
    /*
     * Don't get fooled by any non-system catalogs
     */
--    set search_path = pg_catalog;

    /*
     * First we create and populate the LO temp table
     */
    create temp table  ".vacuumLO" as select photo as lo from thumbnail_stream;

    /*
     * Analyze the temp table so that planner will generate decent plans for
     * the DELETEs below.
     */
    analyze  ".vacuumLO";

    /*
     * Now find any candidate tables that have columns of type oid.
     *
     * NOTE: we ignore system tables and temp tables by the expedient of
     * rejecting tables in schemas named 'pg_*'.  In particular, the temp
     * table formed above is ignored, and pg_largeobject will be too. If
     * either of these were scanned, obviously we'd end up with nothing to
     * delete...
     *
     * NOTE: the system oid column is ignored, as it has attnum < 1. This
     * shouldn't matter for correctness, but it saves time.
     */
    for schem, rel, attr, categ in 
	select s.nspname, c.relname, a.attname, t.typcategory from pg_class c, pg_attribute a, pg_namespace s, pg_type t 
	    where a.attnum > 0 and not a.attisdropped
		and a.attrelid = c.oid
		and a.atttypid = t.oid
		and c.relnamespace = s.oid
		and t.typname in ('oid', 'lo', 'blob_t', 'blobs_t')
		and c.relkind in ('r', 'm')
		and s.nspname !~ '^pg_'
		and c.relname <> 'thumbnail_stream'
    loop
	if( categ = 'A' ) then /* array */
	    execute 'DELETE FROM  ".vacuumLO" WHERE lo IN (SELECT unnest("' || attr || '") FROM ' || schem || '."' || rel || '" WHERE "' || attr || '" is not null);';
	else
	    execute 'DELETE FROM  ".vacuumLO" WHERE lo IN (SELECT "' || attr ||'" FROM ' || schem || '."' || rel || '" WHERE "' || attr || '" is not null);';
	end if;
    end loop;

    /*
     * Now, those entries remaining in  ".vacuumLO" are orphans.
     */
    for b in select lo from ".vacuumLO"
    loop
	return next b;
    end loop;

    /*
     * Drop temporary table.
     */
    drop table if exists ".vacuumLO";
end;
$body$ language plpgsql;

create or replace function "monthDate_First"(d date) returns date as
$body$
declare
    rc date;
begin
    select date_trunc('MONTH', d)::date into rc;
    return rc;
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "monthDate_First"(d date_t) returns date as
$body$
begin
    return "monthDate_First"(d::date);
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "monthDate_First"(d ts_t) returns date as
$body$
begin
    return "monthDate_First"(d::date);
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "monthDate_Last"(d date) returns date as
$body$
declare
    rc date;
begin
    select (date_trunc('MONTH', d) + INTERVAL '1 MONTH - 1 day')::date into rc;
    return rc;
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "monthDate_Last"(d date_t) returns date as
$body$
begin
    return  "monthDate_Last"(d::date);
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "monthDate_Last"(d ts_t) returns date as
$body$
begin
    return  "monthDate_Last"(d::date);
end;
$body$ 
language plpgsql IMMUTABLE;

create or replace function "paramUID"(code uid_t) returns uid_t
as
$body$
declare
    v uid_t;
    x uid_t;
begin
    select param_id, param_value from sysparams where param_id=code and hidden=0 
	into x, v;
    if( x is null ) then
	raise exception 'The % parameter does not exist.', code;
    end if;
    return v;
end;
$body$
language plpgsql STABLE;

create or replace function "paramInteger"(code uid_t) returns int32_t
as
$body$
declare
    v int32_t;
    x uid_t;
begin
    select param_id, param_value::int32_t from sysparams where param_id=code and hidden=0 
	into x, v;
    if( x is null ) then
	raise exception 'The % parameter does not exist.', code;
    end if;
    return v;
end;
$body$
language plpgsql STABLE;

create or replace function "paramIntegerArray"(code uid_t) returns int array
as
$body$
declare
    v int array;
    x uid_t;
begin
    select param_id, param_value::int[] from sysparams where param_id=code and hidden=0 
	into x, v;
    if( x is null ) then
	raise exception 'The % parameter does not exist.', code;
    end if;
    return v;
end;
$body$
language plpgsql STABLE;

create or replace function "paramBoolean"(code uid_t) returns bool_t
as
$body$
declare
    v int32_t;
    x uid_t;
begin
    select param_id, "toBoolean"(param_value) from sysparams where param_id=code and hidden=0 
	into x, v;
    if( x is null ) then
	raise exception 'The % parameter does not exist.', code;
    end if;
    return v;
end;
$body$
language plpgsql STABLE;

create or replace function "paramText"(code uid_t) returns text
as
$body$
declare
    v text;
    x uid_t;
begin
    select param_id, param_value from sysparams where param_id=code and hidden=0 
	into x, v;
    if( x is null ) then
	raise exception 'The % parameter does not exist.', code;
    end if;
    return v;
end;
$body$
language plpgsql STABLE;

create or replace function "toBoolean"(x text) returns bool_t
as
$body$
begin
    return case lower(x)
	when 'yes'	then 1
	when 'true'	then 1
	when 'on' 	then 1
	when '1' 	then 1
	when 'no'	then 0
	when 'false'	then 0
	when 'off' 	then 0
	when '0' 	then 0
	else 		null
    end;
end;
$body$
language plpgsql IMMUTABLE;


-- **** System tables ****

create table "L10n" (
    lang_id 		lang_t 		not null,
    obj_code 		code_t 		not null, -- product|account|user|...
    obj_id 		uid_t 		not null,
    obj_attr 		uid_t 		not null, -- descr|address|...
    str 		text 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(lang_id, obj_code, obj_id, obj_attr)
);

--create index "i_row_L10n" on "L10n"(obj_code, obj_id, obj_attr);
--create index "i_group_L10n" on "L10n"(obj_code, obj_attr);
--create index "i_entity_L10n" on "L10n"(obj_code);
create trigger trig_updated_ts before update on "L10n" for each row execute procedure tf_updated_ts();

create table symlinks (
    distr_id 		uid_t 		not null,
    obj_code 		code_t 		not null, -- (product|account|user|...)
    f_id 		uid_t 		not null,
    t_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key(distr_id, obj_code, f_id)
);

create index i_db_ids_symlinks on symlinks using GIN (db_ids);
create trigger trig_updated_ts before update on symlinks for each row execute procedure tf_updated_ts();

create table sysholidays (
    h_date 		date_t 		not null,
    country_id 		country_t 	not null,
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(h_date, country_id)
);

create trigger trig_updated_ts before update on sysholidays for each row execute procedure tf_updated_ts();

create or replace function tf_sysholidays() returns trigger as
$body$
begin
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'tech_route' and user_id in (
	    select user_id from users where country_id = new.country_id
	) and b_date = new.h_date and e_date = new.h_date;
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'route_compliance' 
	and b_date = new.h_date and e_date = new.h_date;
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'time' 
	and b_date = "monthDate_First"(new.h_date)::date_t and e_date = "monthDate_Last"(new.h_date)::date_t;
    return null;
end;
$body$
language 'plpgsql';

create trigger trig_update_content after insert or update on sysholidays for each row execute procedure tf_sysholidays();

create table sysparams (
    param_id 		uid_t 		not null primary key,
    param_value 	text 		null,
    note 		note_t 		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on sysparams for each row execute procedure tf_updated_ts();

create table syswdmv (
    f_date 		date_t 		not null,
    t_date 		date_t 		not null,
    country_id 		country_t 	not null,
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(f_date, country_id)
);

create trigger trig_updated_ts before update on syswdmv for each row execute procedure tf_updated_ts();

create or replace function tf_syswdmv() returns trigger as
$body$
begin
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'tech_route' and user_id in (
	    select user_id from users where country_id = new.country_id
	) and ((b_date = new.f_date and e_date = new.f_date) or (b_date = new.t_date and e_date = new.t_date));
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'route_compliance' 
	and ((b_date = new.f_date and e_date = new.f_date) or (b_date = new.t_date and e_date = new.t_date));
    update "content_stream.ghost" set data_ts = current_timestamp where content_code = 'time' 
	and (
	    (b_date = "monthDate_First"(new.f_date)::date_t and e_date = "monthDate_Last"(new.f_date)::date_t) 
		or
	    (b_date = "monthDate_First"(new.t_date)::date_t and e_date = "monthDate_Last"(new.t_date)::date_t)
	);
    return null;
end;
$body$
language 'plpgsql';

create trigger trig_update_content after insert or update on syswdmv for each row execute procedure tf_syswdmv();


-- **** System statistics ****

create type counter_t as (fix_time time_t, count int32_t);

create table sysstats (
    fix_date 		date_t 		not null,
    user_id 		uid_t 		not null,
    packets 		counter_t 	not null default(row(null,0)),
    gps_violations 	int32_t 	not null default 0,
    tm_violations 	int32_t 	not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(fix_date, user_id)
);

create trigger trig_updated_ts before update on sysstats for each row execute procedure tf_updated_ts();

create or replace function sysstat_add(f_user_id uid_t, f_date date_t, f_time time_t) returns int
as $BODY$
begin
    if( (select count(*) from sysstats where user_id=f_user_id and fix_date=f_date) > 0 ) then
	update sysstats set packets=row(case when (packets).fix_time is null or (packets).fix_time < f_time then f_time else (packets).fix_time end, (packets).count + 1)
	    where user_id=f_user_id and fix_date=f_date;
    else
	insert into sysstats(fix_date, user_id, packets)
	    values(f_date, f_user_id, row(f_time, 1));
    end if;

    return 1;
end;
$BODY$ language plpgsql;


-- **** Manuals ****

create table accounts (
    account_id 		uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    code 		code_t 		null,
    ftype 		ftype_t 	not null,
    descr 		descr_t 	not null,
    address 		address_t 	not null,
    region_id 		uid_t		null,
    city_id 		uid_t		null,
    rc_id 		uid_t		null, 		/* -> retail_chains */
    chan_id 		uid_t 		null,
    poten_id 		uid_t 		null,
    cash_register 	int32_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    attr_ids 		uids_t 		null,
    extra_info 		note_t 		null,
    locked 		bool_t 		null default 0,
    approved 		bool_t 		null default 0,
    ownerless 		bool_t 		null default 0,
    props 		hstore 		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_region_id_accounts on accounts(region_id);
create index i_city_id_accounts on accounts(city_id);
create index i_rc_id_accounts on accounts(rc_id);
create index i_chan_id_accounts on accounts(chan_id);
create index i_poten_id_accounts on accounts(poten_id);
create index i_db_ids_accounts on accounts using GIN (db_ids);
create trigger trig_code before insert or update on accounts for each row when (new.code is null or new.code = '') execute procedure tf_code();
create trigger trig_updated_ts before update on accounts for each row execute procedure tf_updated_ts();

create table account_kpi (
    account_id 		uid_t 		not null,
    kpi_id 		uid_t 		not null,
    descr0 		descr_t 	not null,
    descr1 		descr_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null, /* KPI from the external sources */
    primary key (account_id, kpi_id)
);

create index i_db_ids_account_kpi on account_kpi using GIN (db_ids);
create trigger trig_updated_ts before update on account_kpi for each row execute procedure tf_updated_ts();

create table account_params (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    group_price_id 	uid_t 		null,
    payment_delay 	int32_t 	null,
    payment_method_id 	uid_t 		null,
    wareh_ids 		uids_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id)
);

create index i_db_ids_account_params on account_params using GIN (db_ids);
create trigger trig_updated_ts before update on account_params for each row execute procedure tf_updated_ts();

create table account_prices (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    price 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id)
);

create index i_db_ids_account_prices on account_prices using GIN (db_ids);
create trigger trig_updated_ts before update on account_prices for each row execute procedure tf_updated_ts();

create table activity_types (
    activity_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    note 		note_t 		null,
    docs_needed 	bool_t 		not null default 0,
    exec_limit 		int32_t 	not null default 255 check (exec_limit between 1 and 255),
    strict 		bool_t 		not null default 0, /* sets to 1 (true) for direct visits to the accounts */
    selectable 		bool_t 		not null default 1, /* sets to 1 (true) if end users allow to select this activity type on the mobile devices */
    joint 		bool_t 		not null default 0, /* sets to 1 (true) for joint activities */
    important 		bool_t 		not null default 0, /* sets to 1 (true) for important/urgent activities */
    roles 		codes_t 	null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on activity_types for each row execute procedure tf_updated_ts();

create table addition_types (
    addition_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_addition_types on addition_types using GIN (db_ids);
create trigger trig_updated_ts before update on addition_types for each row execute procedure tf_updated_ts();

create table agencies (
    agency_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_agencies on agencies using GIN (db_ids);
create trigger trig_updated_ts before update on agencies for each row execute procedure tf_updated_ts();

create table agreements1 (
    account_id		uid_t		not null,
    placement_id 	uid_t 		not null,
    posm_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    strict 		bool_t 		not null default 1,
    cookie 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, placement_id, posm_id, b_date)
);

create index i_db_ids_agreements1 on agreements1 using GIN (db_ids);
create trigger trig_updated_ts before update on agreements1 for each row execute procedure tf_updated_ts();

create table agreements2 (
    account_id		uid_t		not null,
    prod_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    facing 		int32_t 	not null check(facing > 0),
    strict 		bool_t 		not null default 1,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id, b_date)
);

create index i_db_ids_agreements2 on agreements2 using GIN (db_ids);
create trigger trig_updated_ts before update on agreements2 for each row execute procedure tf_updated_ts();

create table asp_types ( /* Addition-Sales-Places */
    asp_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_asp_types on asp_types using GIN (db_ids);
create trigger trig_updated_ts before update on asp_types for each row execute procedure tf_updated_ts();

create table attributes (
    attr_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_attributes on attributes using GIN (db_ids);
create trigger trig_updated_ts before update on attributes for each row execute procedure tf_updated_ts();

create table audit_criterias (
    audit_criteria_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    wf 			wf_t 		not null check(wf between 0.01 and 1.00),
    mandatory 		bool_t 		not null default 1,
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_audit_criterias on audit_criterias using GIN (db_ids);
create trigger trig_updated_ts before update on audit_criterias for each row execute procedure tf_updated_ts();

create table audit_scores (
    audit_score_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    score 		int32_t 	not null check(score >= 0),
    wf 			wf_t 		not null check(wf between 0.00 and 1.00),
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_audit_scores on audit_scores using GIN (db_ids);
create trigger trig_updated_ts before update on audit_scores for each row execute procedure tf_updated_ts();

create table blacklist (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    locked 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id)
);

create index i_db_ids_blacklist on blacklist using GIN (db_ids);
create trigger trig_updated_ts before update on blacklist for each row execute procedure tf_updated_ts();

create table brands (
    brand_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    manuf_id 		uid_t 		not null,
    dep_id		uid_t		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_brands on brands using GIN (db_ids);
create trigger trig_updated_ts before update on brands for each row execute procedure tf_updated_ts();

create table canceling_types (
    canceling_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_canceling_types on canceling_types using GIN (db_ids);
create trigger trig_updated_ts before update on canceling_types for each row execute procedure tf_updated_ts();

create table categories (
    categ_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    brand_ids 		uids_t 		null,
    wf 			wf_t 		null check(wf between 0.01 and 1.00),
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_categories on categories using GIN (db_ids);
create trigger trig_updated_ts before update on categories for each row execute procedure tf_updated_ts();

create table channels (
    chan_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_channels on channels using GIN (db_ids);
create trigger trig_updated_ts before update on channels for each row execute procedure tf_updated_ts();

create table cities (
    city_id 		uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    ftype 		ftype_t 	not null,
    descr 		descr_t 	not null,
    country_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_cities on cities using GIN (db_ids);
create trigger trig_updated_ts before update on cities for each row execute procedure tf_updated_ts();

create table comment_types (
    comment_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    min_note_length 	int32_t 	null,
    photo_needed 	bool_t 		null,
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_comment_types on comment_types using GIN (db_ids);
create trigger trig_updated_ts before update on comment_types for each row execute procedure tf_updated_ts();

create table confirmation_types (
    confirmation_type_id uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    min_note_length 	int32_t 	null,
    photo_needed 	bool_t 		null,
    accomplished 	bool_t 		null,
    target_type_ids 	uids_t 		not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on confirmation_types for each row execute procedure tf_updated_ts();

create table contacts (
    contact_id 		uid_t 		not null primary key default man_id(),
    account_id 		uid_t 		not null,
    name 		descr_t 	not null,
    surname 		descr_t 	null,
    patronymic 		descr_t 	null,
    job_title_id 	uid_t 		not null,
    phone 		phone_t 	null,
    mobile 		phone_t 	null,
    email 		email_t 	null,
    loyalty_level_id 	uid_t 		null,
    locked 		bool_t 		not null default 0,
    extra_info 		note_t 		null,
    consent 		blob_t 		null, /* consent to the processing of personal data */
    author_id 		uid_t 		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null, /* contact from the external sources */
    "_dataTimestamp" 	datetime_t 	null
);

create index i_account_id_contacts on contacts(account_id);
create index i_email_contacts on contacts(email);
create index i_db_ids_contacts on contacts using GIN (db_ids);
create trigger trig_updated_ts before update on contacts for each row execute procedure tf_updated_ts();

create table countries (
    country_id 		country_t 	not null primary key,
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on countries for each row execute procedure tf_updated_ts();

create table debts (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    debt 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id)
);

create index i_db_ids_debts on debts using GIN (db_ids);
create trigger trig_updated_ts before update on debts for each row execute procedure tf_updated_ts();

create table delivery_types (
    delivery_type_id	uid_t		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_delivery_types on delivery_types using GIN (db_ids);
create trigger trig_updated_ts before update on delivery_types for each row execute procedure tf_updated_ts();

create table departments (
    dep_id		uid_t		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_departments on departments using GIN (db_ids);
create trigger trig_updated_ts before update on departments for each row execute procedure tf_updated_ts();

create table discard_types (
    discard_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_discard_types on discard_types using GIN (db_ids);
create trigger trig_updated_ts before update on discard_types for each row execute procedure tf_updated_ts();

create table discounts (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    discount 		discount_t 	not null default 0,
    min_discount 	discount_t 	not null default -100,
    max_discount 	discount_t 	not null default 100,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id)
);

create index i_db_ids_discounts on discounts using GIN (db_ids);
create trigger trig_updated_ts before update on discounts for each row execute procedure tf_updated_ts();

create table distributors (
    distr_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    country_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_distributors on distributors using GIN (db_ids);
create trigger trig_updated_ts before update on distributors for each row execute procedure tf_updated_ts();

create table equipment_types (
    equipment_type_id 	uid_t		not null primary key default man_id(),
    descr 		descr_t		not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_equipment_types on equipment_types using GIN (db_ids);
create trigger trig_updated_ts before update on equipment_types for each row execute procedure tf_updated_ts();

create table equipments (
    equipment_id 	uid_t 		not null primary key default man_id(),
    account_id 		uid_t 		null,
    serial_number 	code_t 		not null,
    equipment_type_id 	uid_t 		not null,
    ownership_type_id 	uid_t 		null,
    extra_info 		note_t 		null,
    photo 		blob_t 		null,
    author_id 		uid_t 		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null, /* equipment from the external sources */
    "_dataTimestamp" 	datetime_t 	null
);

create index i_db_ids_equipments on equipments using GIN (db_ids);
create trigger trig_updated_ts before update on equipments for each row execute procedure tf_updated_ts();

create table erp_docs (
    doc_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    pid 		uid_t 		null, /* parent erp_id */
    erp_no 		uid_t 		not null,
    erp_dt 		datetime_t 	not null,
    amount 		currency_t 	not null,
    status 		int32_t 	not null default 0 check (status between -1 and 1), /* -1 - delete; 0 - normal; 1 - closed; */
    doc_type 		doctype_t 	not null, /* order, contract, reclamation */
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (doc_id, erp_id)
);

create index i_db_ids_erp_docs on erp_docs using GIN (db_ids);
create trigger trig_updated_ts before update on erp_docs for each row execute procedure tf_updated_ts();

create table erp_products (
    doc_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    qty 		numeric_t 	not null,
    discount 		discount_t 	not null,
    amount 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (doc_id, erp_id, prod_id)
);

create index i_db_ids_erp_products on erp_products using GIN (db_ids);
create trigger trig_updated_ts before update on erp_products for each row execute procedure tf_updated_ts();

create table floating_prices (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    price 		currency_t 	not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    promo 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id, b_date)
);

create index i_db_ids_floating_prices on floating_prices using GIN (db_ids);
create trigger trig_updated_ts before update on floating_prices for each row execute procedure tf_updated_ts();

create table group_prices (
    distr_id 		uid_t 		not null,
    group_price_id 	uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    price 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, group_price_id, prod_id)
);

create index i_db_ids_group_prices on group_prices using GIN (db_ids);
create trigger trig_updated_ts before update on group_prices for each row execute procedure tf_updated_ts();

create table highlights (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    color 		color_t 	null,
    bgcolor 		color_t 	null,
    remark 		descr_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id)
);

create index i_db_ids_highlights on highlights using GIN (db_ids);
create trigger trig_updated_ts before update on highlights for each row execute procedure tf_updated_ts();

create table info_materials (
    infom_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    "blob" 		blob_t 		not null,
    content_type 	varchar(32) 	not null default 'application/pdf',
    rc_id 		uid_t 		null,
    chan_ids 		uids_t 		null,
    dep_id 		uid_t		null,
    country_id 		country_t 	not null,
    b_date 		date_t 		null,
    e_date 		date_t 		null,
    author_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on info_materials for each row execute procedure tf_updated_ts();

create table issues (
    issue_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    extra_info 		varchar(2048) 	not null, -- extra information for the support team
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on issues for each row execute procedure tf_updated_ts();

create table job_titles (
    job_title_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_job_titles on job_titles using GIN (db_ids);
create trigger trig_updated_ts before update on job_titles for each row execute procedure tf_updated_ts();

create table kinds (
    kind_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_kinds on kinds using GIN (db_ids);
create trigger trig_updated_ts before update on kinds for each row execute procedure tf_updated_ts();

create table languages (
    lang_id 		lang_t 		not null primary key,
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on languages for each row execute procedure tf_updated_ts();

insert into languages values('ru', 'Русский');
insert into languages values('en', 'English');

create table loyalty_levels (
    loyalty_level_id	uid_t		not null primary key default man_id(),
    descr		descr_t		not null,
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_loyalty_levels on loyalty_levels using GIN (db_ids);
create trigger trig_updated_ts before update on loyalty_levels for each row execute procedure tf_updated_ts();

create table manufacturers (
    manuf_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	null,
    competitor		bool_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_manufacturers on manufacturers using GIN (db_ids);
create trigger trig_updated_ts before update on manufacturers for each row execute procedure tf_updated_ts();

create table matrices (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    placement_ids 	uids_t 		null,
    row_no 		int32_t 	null, -- ordering
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id)
);

create index i_db_ids_matrices on matrices using GIN (db_ids);
create trigger trig_updated_ts before update on matrices for each row execute procedure tf_updated_ts();

create table mutuals (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    mutual 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id)
);

create index i_db_ids_mutuals on mutuals using GIN (db_ids);
create trigger trig_updated_ts before update on mutuals for each row execute procedure tf_updated_ts();

create table mutuals_history (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    erp_no 		uid_t 		not null,
    erp_dt 		datetime_t 	not null,
    amount 		currency_t 	not null,
    incoming 		bool_t 		not null,
    unpaid 		currency_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, erp_id)
);

create index i_db_ids_mutuals_history on mutuals_history using GIN (db_ids);
create trigger trig_updated_ts before update on mutuals_history for each row execute procedure tf_updated_ts();

create table mutuals_history_products (
    distr_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    qty 		numeric_t 	not null,
    discount 		discount_t 	null,
    amount 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, erp_id, prod_id)
);

create index i_db_ids_mutuals_history_products on mutuals_history_products using GIN (db_ids);
create trigger trig_updated_ts before update on mutuals_history_products for each row execute procedure tf_updated_ts();

create table my_accounts (
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (user_id, account_id)
);

create index i_db_ids_my_accounts on my_accounts using GIN (db_ids);
create trigger trig_updated_ts before update on my_accounts for each row execute procedure tf_updated_ts();

create table my_cities (
    user_id 		uid_t 		not null,
    city_id 		uid_t 		not null,
    chan_id 		uid_t 		not null default '',
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (user_id, city_id, chan_id)
);

create index i_db_ids_my_cities on my_cities using GIN (db_ids);
create trigger trig_updated_ts before update on my_cities for each row execute procedure tf_updated_ts();

create table my_kpi (
    user_id 		uid_t 		not null,
    kpi_id 		uid_t 		not null,
    descr0 		descr_t 	not null,
    descr1 		descr_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null, /* KPI from the external sources */
    primary key (user_id, kpi_id)
);

create index i_db_ids_my_kpi on my_kpi using GIN (db_ids);
create trigger trig_updated_ts before update on my_kpi for each row execute procedure tf_updated_ts();

create table my_regions (
    user_id 		uid_t 		not null,
    region_id 		uid_t 		not null,
    chan_id 		uid_t 		not null default '',
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (user_id, region_id, chan_id)
);

create index i_db_ids_my_regions on my_regions using GIN (db_ids);
create trigger trig_updated_ts before update on my_regions for each row execute procedure tf_updated_ts();

create table my_retail_chains (
    user_id 		uid_t 		not null,
    rc_id 		uid_t 		not null,
    region_id 		uid_t 		not null default '',
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (user_id, rc_id, region_id)
);

create index i_db_ids_my_retail_chains on my_retail_chains using GIN (db_ids);
create trigger trig_updated_ts before update on my_retail_chains for each row execute procedure tf_updated_ts();

create table my_routes (
    user_id		uid_t		not null,
    account_id		uid_t		not null,
    activity_type_id	uid_t		not null,
    p_date		date_t		not null,
    row_no 		int32_t 	null,
    duration		int32_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (user_id, account_id, activity_type_id, p_date)
);

create index i_user_id_p_date_my_routes on my_routes(user_id, p_date);
create index i_db_ids_my_routes on my_routes using GIN (db_ids);
create trigger trig_updated_ts before update on my_routes for each row execute procedure tf_updated_ts();

create table oos_types (
    oos_type_id		uid_t		not null primary key default man_id(),
    descr		descr_t		not null,
    dep_id		uid_t		null,
    row_no 		int32_t 	null, -- ordering
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_oos_types on oos_types using GIN (db_ids);
create trigger trig_updated_ts before update on oos_types for each row execute procedure tf_updated_ts();

create table order_params (
    distr_id 		uid_t 		not null,
    order_param_id 	uid_t 		not null default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, order_param_id)
);

create index i_db_ids_order_params on order_params using GIN (db_ids);
create trigger trig_updated_ts before update on order_params for each row execute procedure tf_updated_ts();

create table order_types (
    order_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_order_types on order_types using GIN (db_ids);
create trigger trig_updated_ts before update on order_types for each row execute procedure tf_updated_ts();

create table ownership_types (
    ownership_type_id 	uid_t		not null primary key default man_id(),
    descr 		descr_t		not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_ownership_types on ownership_types using GIN (db_ids);
create trigger trig_updated_ts before update on ownership_types for each row execute procedure tf_updated_ts();

create table packs (
    pack_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    descr 		descr_t 	not null,
    pack 		numeric_t 	not null default 1.0 check (pack >= 0.001),
    weight 		weight_t 	null,
    volume 		volume_t 	null,
    precision 		int32_t 	null check (precision is null or (precision >= 0)),
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (pack_id, prod_id)
);

create index i_db_ids_packs on packs using GIN (db_ids);
create trigger trig_updated_ts before update on packs for each row execute procedure tf_updated_ts();

create table payment_methods (
    payment_method_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    encashment 		bool_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_payment_methods on payment_methods using GIN (db_ids);
create trigger trig_updated_ts before update on payment_methods for each row execute procedure tf_updated_ts();

create table pending_types (
    pending_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_pending_types on pending_types using GIN (db_ids);
create trigger trig_updated_ts before update on pending_types for each row execute procedure tf_updated_ts();

create table permitted_returns ( /* allowed products for the [reclamation] document */
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    price 		currency_t 	not null check (price >= 0),
    max_qty    		numeric_t      	null check (max_qty is null or (max_qty >= 0)),
    locked 		bool_t 		null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id)
);

create index i_db_ids_permitted_returns on permitted_returns using GIN (db_ids);
create trigger trig_updated_ts before update on permitted_returns for each row execute procedure tf_updated_ts();

create table photo_params (
    photo_param_id	uid_t		not null primary key default man_id(),
    descr		descr_t		not null,
    placement_ids 	uids_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_photo_params on photo_params using GIN (db_ids);
create trigger trig_updated_ts before update on photo_params for each row execute procedure tf_updated_ts();

create table photo_types (
    photo_type_id	uid_t		not null primary key default man_id(),
    descr		descr_t		not null,
    placement_ids 	uids_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_photo_types on photo_types using GIN (db_ids);
create trigger trig_updated_ts before update on photo_types for each row execute procedure tf_updated_ts();

create table placements (
    placement_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_placements on placements using GIN (db_ids);
create trigger trig_updated_ts before update on placements for each row execute procedure tf_updated_ts();

create table planograms (
    pl_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    "blob" 		blob_t 		not null,
    content_type 	varchar(32) 	not null default 'image/jpeg',
    brand_ids 		uids_t 		not null,
    rc_id 		uid_t 		null,
    chan_ids 		uids_t 		null,
    country_id		country_t 	not null,
    b_date 		date_t 		null,
    e_date 		date_t 		null,
    author_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on planograms for each row execute procedure tf_updated_ts();

create table plu_codes ( /* Price Look-Up codes (in the outlet) */
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    plu_code 		code_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key(account_id, prod_id)
);

create index i_db_ids_plu_codes on plu_codes using GIN (db_ids);
create trigger trig_updated_ts before update on plu_codes for each row execute procedure tf_updated_ts();

create table pmlist ( /* Price Monitoring List - allowed products for the [price] document */
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id, b_date)
);

create index i_db_ids_pmlist on pmlist using GIN (db_ids);
create trigger trig_updated_ts before update on pmlist for each row execute procedure tf_updated_ts();

create table pos_materials ( /* Point-of-Sale and Point-of-Purchase materials */
    posm_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    "blob" 		blob_t 		not null,
    content_type 	varchar(32) 	not null default 'image/jpeg',
    brand_ids 		uids_t 		not null,
    placement_ids 	uids_t 		null,
    chan_ids 		uids_t 		null,
    country_id		country_t 	not null,
    b_date 		date_t 		null,
    e_date 		date_t 		null,
    author_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null /* pos_material from the external sources */
);

create index i_db_ids_pos_materials on pos_materials using GIN (db_ids);
create trigger trig_updated_ts before update on pos_materials for each row execute procedure tf_updated_ts();

create table potentials (
    poten_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_potentials on potentials using GIN (db_ids);
create trigger trig_updated_ts before update on potentials for each row execute procedure tf_updated_ts();

create table priorities (
    country_id 		uid_t 		not null,
    brand_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (country_id, brand_id, b_date)
);

create index i_db_ids_priorities on priorities using GIN (db_ids);
create trigger trig_updated_ts before update on priorities for each row execute procedure tf_updated_ts();

create table products (
    prod_id 		uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    ftype 		ftype_t 	not null,
    code 		code_t 		null,
    descr 		descr_t 	not null,
    kind_id 		uid_t 		null,
    brand_id 		uid_t 		null,
    categ_id 		uid_t 		null,
    shelf_life_id 	uid_t 		null,
    art 		code_t 		null,
    obsolete 		bool_t 		null,
    novelty 		bool_t 		null,
    promo 		bool_t 		null,
    barcodes 		ean13 array 	null,
    image 		blob_t 		null,
    country_ids 	countries_t 	null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_brand_id_products on products(brand_id);
create index i_db_ids_products on products using GIN (db_ids);
create trigger trig_updated_ts before update on products for each row execute procedure tf_updated_ts();

create table promo_types (
    promo_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    note_needed 	int32_t 	null,
    photo_needed 	bool_t 		null,
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_promo_types on promo_types using GIN (db_ids);
create trigger trig_updated_ts before update on promo_types for each row execute procedure tf_updated_ts();

create table quest_names (
    qname_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_quest_names on quest_names using GIN (db_ids);
create trigger trig_updated_ts before update on quest_names for each row execute procedure tf_updated_ts();

create table quest_rows (
    qname_id 		uid_t 		not null,
    qrow_id 		uid_t 		not null default man_id(),
    pid 		uid_t 		null,
    ftype 		ftype_t 	not null,
    descr 		descr_t 	not null,
    qtype 		varchar(7) 	null check(ftype=0 and qtype in ('boolean','integer') or (ftype<>0 and qtype is null)),
    extra_info 		note_t 		null,
    country_ids 	countries_t 	null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key(qname_id, qrow_id)
);

create index i_db_ids_quest_rows on quest_rows using GIN (db_ids);
create trigger trig_updated_ts before update on quest_rows for each row execute procedure tf_updated_ts();

create table rating_criterias (
    rating_criteria_id 	uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    ftype 		ftype_t 	not null,
    descr 		descr_t 	not null,
    dep_id 		uid_t 		null,
    wf 			wf_t 		null check((ftype=0 and wf is not null and wf between 0.01 and 1.00) or (ftype<>0 and wf is null)),
    mandatory 		bool_t 		null check((ftype=0 and mandatory is not null) or (ftype<>0 and mandatory is null)),
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_rating_criterias on rating_criterias using GIN (db_ids);
create trigger trig_updated_ts before update on rating_criterias for each row execute procedure tf_updated_ts();

create table rating_scores (
    rating_score_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    score 		int32_t 	not null check(score >= 0),
    wf 			wf_t 		not null check(wf between 0.00 and 1.00),
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_rating_scores on rating_scores using GIN (db_ids);
create trigger trig_updated_ts before update on rating_scores for each row execute procedure tf_updated_ts();

create table rdd (
    distr_id 		uid_t 		not null,
    obj_code 		code_t 		not null,
    r_date 		datetimetz_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, obj_code)
);

create index i_db_ids_rdd on rdd using GIN (db_ids);
create trigger trig_updated_ts before update on rdd for each row execute procedure tf_updated_ts();

create table receipt_types (
    receipt_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_receipt_types on receipt_types using GIN (db_ids);
create trigger trig_updated_ts before update on receipt_types for each row execute procedure tf_updated_ts();

create table reclamation_types (
    reclamation_type_id uid_t 		not null primary key default man_id(),
    descr 		descr_t 	null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_reclamation_types on reclamation_types using GIN (db_ids);
create trigger trig_updated_ts before update on reclamation_types for each row execute procedure tf_updated_ts();

create table recom_orders (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		null,
    qty 		int32_t 	null,
    stock_wf 		wf_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id)
);

create index i_db_ids_recom_orders on recom_orders using GIN (db_ids);
create trigger trig_updated_ts before update on recom_orders for each row execute procedure tf_updated_ts();

create table recom_retail_prices (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    rrp 		currency_t 	not null, /* [R]ecomended [R]etail Price */
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id)
);

create index i_db_ids_recom_retail_prices on recom_retail_prices using GIN (db_ids);
create trigger trig_updated_ts before update on recom_retail_prices for each row execute procedure tf_updated_ts();

create table recom_shares (
    account_id 		uid_t 		not null,
    categ_id 		uid_t 		not null,
    sos 		wf_t 		null check(sos between 0.01 and 1.00),
    soa 		wf_t 		null check(soa between 0.01 and 1.00),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key(account_id, categ_id)
);

create index i_db_ids_recom_shares on recom_shares using GIN (db_ids);
create trigger trig_updated_ts before update on recom_shares for each row execute procedure tf_updated_ts();

create table refunds (
    account_id 		uid_t 		not null primary key,
    percentage 		numeric(7,1) 	not null check(percentage >=0 ),
    attention 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_refunds on refunds using GIN (db_ids);
create trigger trig_updated_ts before update on refunds for each row execute procedure tf_updated_ts();

create table refunds_products (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    percentage 		numeric(7,1) 	not null check(percentage >=0 ),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id)
);

create index i_db_ids_refunds_products on refunds_products using GIN (db_ids);
create trigger trig_updated_ts before update on refunds_products for each row execute procedure tf_updated_ts();

create table regions (
    region_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    country_id 		country_t 	null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_regions on regions using GIN (db_ids);
create trigger trig_updated_ts before update on regions for each row execute procedure tf_updated_ts();

create table remark_types (
    remark_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_remark_types on remark_types using GIN (db_ids);
create trigger trig_updated_ts before update on remark_types for each row execute procedure tf_updated_ts();

create table reminders (
    reminder_id 	uid_t 		not null primary key default man_id(),
    subject 		descr_t 	not null,
    body 		varchar(2048)	not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    permanent 		bool_t 		not null default 0,
    user_ids 		uids_t		not null,
    author_id 		uid_t 		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on reminders for each row execute procedure tf_updated_ts();

create table restrictions (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    min_qty 		numeric_t 	null check (min_qty is null or min_qty >= 0),
    max_qty 		numeric_t 	null check (max_qty is null or max_qty >= 0),
    quantum 		numeric_t 	null check (quantum is null or quantum > 0),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, prod_id)
);

create index i_db_ids_restrictions on restrictions using GIN (db_ids);
create trigger trig_updated_ts before update on restrictions for each row execute procedure tf_updated_ts();

create table retail_chains (
    rc_id		uid_t		not null primary key default man_id(),
    descr 		descr_t 	not null,
    ka_code		code_t		null,	/* Key Account: NKA, KA, ... */
    country_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_retail_chains on retail_chains using GIN (db_ids);
create trigger trig_updated_ts before update on retail_chains for each row execute procedure tf_updated_ts();

create table route_cycles (
    cycle_id 		uid_t 		not null primary key default man_id(),
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    cycle_no 		int32_t 	not null,
    status 		varchar(10) 	check(status in ('closed','inprogress')),
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    compiled_ts 	ts_t 		null
);

create trigger trig_updated_ts before update on route_cycles for each row execute procedure tf_updated_ts();

create table routemv (
    user_id 		uid_t 		not null,
    f_date 		date_t 		not null,
    t_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(user_id, f_date, t_date)
);

create trigger trig_updated_ts before update on routemv for each row execute procedure tf_updated_ts();

create table routes (
    user_id 		uid_t 		not null,
    cycle_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    days 		smallint[] 	not null default array[0,0,0,0,0,0,0] check (array_length(days,1)=7),
    weeks 		smallint[] 	not null default array[0,0,0,0] check (array_length(weeks,1)=4),
    author_id 		uid_t		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(user_id, cycle_id, account_id)
);

create trigger trig_updated_ts before update on routes for each row execute procedure tf_updated_ts();

create table rules (
    doc_type 		doctype_t 	not null,
    role 		code_t 		not null,
    frequency 		code_t 		not null check(frequency in ('everytime','once_a_week','once_a_month')),
/* extra attributes for the my_jobs stream (accounts filter) BEGIN */
    account_ids 	uids_t 		null,
    region_ids 		uids_t		null,
    city_ids 		uids_t		null,
    rc_ids 		uids_t		null, /* -> retail_chains */
    chan_ids		uids_t 		null,
    poten_ids 		uids_t 		null,
/* extra attributes for the my_jobs stream (accounts filter) END */
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key(doc_type, role)
);

create trigger trig_updated_ts before update on rules for each row execute procedure tf_updated_ts();
create index i_db_ids_rules on rules using GIN (db_ids);

create table sales_history (
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    s_date 		date_t 		not null,
    amount_c 		currency_t 	null,
    pack_c_id 		uid_t 		null,
    qty_c 		numeric_t 	null,
    amount_r 		currency_t 	null,
    pack_r_id 		uid_t 		null,
    qty_r 		numeric_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (account_id, prod_id, s_date)
);

create index i_db_ids_sales_history on sales_history using GIN (db_ids);
create trigger trig_updated_ts before update on sales_history for each row execute procedure tf_updated_ts();

create table schedules (
    user_id 		uid_t 		not null,
    p_date 		date_t 		not null,
    -- jobs[1] = 09:00 - 11:00
    -- jobs[2] = 11:00 - 13:00
    -- jobs[3] = 14:00 - 16:00
    -- jobs[4] = 16:00 - 18:00
    jobs 		hstore[] 	not null default array[''::hstore,''::hstore,''::hstore,''::hstore] check(array_length(jobs,1)=4),
    closed 		bool_t 		not null default 0,
    author_id 		uid_t		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    alarm_ts 		ts_t 		null,
    primary key (user_id, p_date)
);

create trigger trig_updated_ts before update on schedules for each row execute procedure tf_updated_ts();

create table shelf_lifes (
    shelf_life_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    days 		int32_t 	null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_shelf_lifes on shelf_lifes using GIN (db_ids);
create trigger trig_updated_ts before update on shelf_lifes for each row execute procedure tf_updated_ts();

create table shipments (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    d_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, account_id, d_date)
);

create index i_db_ids_shipments on shipments using GIN (db_ids);
create trigger trig_updated_ts before update on shipments for each row execute procedure tf_updated_ts();

create table std_prices (
    distr_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack_id 		uid_t 		not null,
    price 		currency_t 	not null check (price >= 0),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, prod_id)
);

create index i_db_ids_std_prices on std_prices using GIN (db_ids);
create trigger trig_updated_ts before update on std_prices for each row execute procedure tf_updated_ts();

create table support (
    sup_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    phone 		phone_t 	null,
    email 		email_t		not null,
    country_id 		country_t 	null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on support for each row execute procedure tf_updated_ts();

create table targets (
    target_id 		uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    target_type_id 	uid_t 		not null,
    subject 		descr_t 	not null,
    body 		varchar(4096)	not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    image 		blob_t 		null, /* image attached to the target */
    dep_id 		uid_t		null,
    account_ids 	uids_t 		null,
    region_ids 		uids_t		null,
    city_ids 		uids_t		null,
    rc_ids 		uids_t		null, /* -> retail_chains */
    chan_ids		uids_t 		null,
    poten_ids 		uids_t 		null,
    props 		hstore 		null,
    myself 		bool_t 		not null default 0,
    rows		int32_t 	null,
    author_id 		uid_t 		null,
    hidden 		bool_t 		not null default 0,
    immutable 		bool_t 		not null default 0,
    renewable 		bool_t 		not null default 0, /* see [console.req_remark] for more info */
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    "_isAlienData" 	bool_t 		null, /* target from the external sources */
    "_isSuppressedData" bool_t 		null
);

create or replace function tf_targets$rows() returns trigger as
$body$
begin
    new.rows = (select count(*) from expand_accounts(new.account_ids, new.region_ids, new.city_ids, new.rc_ids, new.chan_ids, new.poten_ids));
    return new;
end;
$body$
language 'plpgsql';

create index i_db_ids_targets on targets using GIN (db_ids);
create index i_2lts_targets on targets (updated_ts);
create index i_pid_targets on targets (pid);

create trigger trig_rows before insert or update on targets for each row execute procedure tf_targets$rows();
create trigger trig_updated_ts before update on targets for each row execute procedure tf_updated_ts();

create table target_types (
    target_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    selectable 		bool_t 		not null default 1, /* sets to 1 (true) if end users allow to select this targen type on the mobile devices */
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on target_types for each row execute procedure tf_updated_ts();

create table testing_criterias (
    testing_criteria_id uid_t 		not null primary key default man_id(),
    pid 		uid_t 		null,
    ftype 		ftype_t 	not null,
    descr 		descr_t 	not null,
    wf 			wf_t 		null check((ftype=0 and wf is not null and wf between 0.01 and 1.00) or (ftype<>0 and wf is null)),
    mandatory 		bool_t 		null check((ftype=0 and mandatory is not null) or (ftype<>0 and mandatory is null)),
    extra_info 		note_t 		null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_testing_criterias on testing_criterias using GIN (db_ids);
create trigger trig_updated_ts before update on testing_criterias for each row execute procedure tf_updated_ts();

create table testing_scores (
    testing_score_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    score 		int32_t 	not null check(score >= 0),
    wf 			wf_t 		not null check(wf between 0.00 and 1.00),
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_testing_scores on testing_scores using GIN (db_ids);
create trigger trig_updated_ts before update on testing_scores for each row execute procedure tf_updated_ts();

create table tickets (
    ticket_id 		uid_t 		not null primary key default nextval('seq_tickets'),
    user_id 		uid_t 		not null,
    issue_id 		uid_t 		not null,
    note 		note_t 		null,
    resolution 		note_t 		null, -- <<< reg_resolution
    author_id 		uid_t 		not null,
    closed 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on tickets for each row execute procedure tf_updated_ts();

create table training_materials (
    tm_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    "blob" 		blob_t 		not null,
    content_type 	varchar(32) 	not null default 'application/pdf',
    brand_ids 		uids_t 		null,
    country_id		country_t 	not null,
    b_date 		date_t 		null,
    e_date 		date_t 		null,
    author_id 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on training_materials for each row execute procedure tf_updated_ts();

create table training_types (
    training_type_id	uid_t		not null primary key default man_id(),
    descr		descr_t		not null,
    dep_id		uid_t		null,
    row_no 		int32_t 	null, -- ordering
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create trigger trig_updated_ts before update on training_types for each row execute procedure tf_updated_ts();

create table unsched_types (
    unsched_type_id 	uid_t 		not null primary key default man_id(),
    descr 		descr_t 	null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_unsched_types on unsched_types using GIN (db_ids);
create trigger trig_updated_ts before update on unsched_types for each row execute procedure tf_updated_ts();

create table urgent_activities (
    user_id		uid_t		not null,
    account_id		uid_t		not null,
    activity_type_id	uid_t		not null,
    p_date		date_t		not null,
    extra_info 		note_t 		null,
    author_id 		uid_t		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (user_id, account_id, activity_type_id, p_date)
);

create trigger trig_updated_ts before update on urgent_activities for each row execute procedure tf_updated_ts();

create table users (
    user_id		uid_t		not null primary key,
    pids		uids_t		null,
    descr		descr_t		not null,
    role 		code_t 		null, -- check (role in ('merch','sr','mr','sv','ise','asm','kam','tme') and role = lower(role)),
    country_id		country_t 	not null default 'RU',
    lang_id 		lang_t 		not null default 'ru',
    dep_ids		uids_t		null,
    distr_ids		uids_t		null,
    agency_id 		uid_t 		null,
    mobile 		phone_t 	null,
    email 		email_t 	null,
    area 		descr_t 	null,
    dev_login 		uid_t 		null,
    executivehead_id 	uid_t 		null,
    "rules:wdays" 	smallint[] 	null check (array_length("rules:wdays",1)=7),
    "rules:wd_begin" 	time_t 		null,
    "rules:wd_end" 	time_t 		null,
    "rules:timing" 	time_t 		null,
    "rules:gps_off" 	bool_t 		not null default 0,
    "rules:tm_change" 	bool_t 		not null default 0,
    evaddrs		emails_t 	null,
    props 		hstore 		null,
    hidden		bool_t		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_users on users using GIN (db_ids);
create trigger trig_updated_ts before update on users for each row execute procedure tf_updated_ts();

create table vf_accounts (
    vf_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    row_no 		int32_t 	null, -- ordering
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (vf_id, account_id)
);

create index i_db_ids_vf_accounts on vf_accounts using GIN (db_ids);
create trigger trig_updated_ts before update on vf_accounts for each row execute procedure tf_updated_ts();

create table vf_names (
    vf_id 		uid_t 		not null primary key default man_id(),
    descr 		descr_t 	not null,
    row_no 		int32_t 	null, -- ordering
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null
);

create index i_db_ids_vf_names on vf_names using GIN (db_ids);
create trigger trig_updated_ts before update on vf_names for each row execute procedure tf_updated_ts();

create table vf_products (
    account_id 		uid_t 		not null,
    vf_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	null, -- ordering
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (vf_id, account_id, prod_id)
);

create index i_db_ids_vf_products on vf_products using GIN (db_ids);
create trigger trig_updated_ts before update on vf_products for each row execute procedure tf_updated_ts();

create table warehouses (
    distr_id 		uid_t 		not null,
    wareh_id 		uid_t 		not null,
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, wareh_id)
);

create index i_db_ids_warehouses on warehouses using GIN (db_ids);
create trigger trig_updated_ts before update on warehouses for each row execute procedure tf_updated_ts();

create table wareh_stocks (
    distr_id 		uid_t 		not null,
    wareh_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    qty 		int32_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    db_ids 		uids_t 		null,
    primary key (distr_id, wareh_id, prod_id)
);

create index i_db_ids_wareh_stocks on wareh_stocks using GIN (db_ids);
create trigger trig_updated_ts before update on wareh_stocks for each row execute procedure tf_updated_ts();


-- **** Activities ****

create table a_airplane (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    state 		varchar(3) 	not null check (state in ('on','off') and state = lower(state))
);

create index i_user_id_a_airplane on a_airplane (user_id);
create index i_fix_date_a_airplane on a_airplane (left(fix_dt,10));
create index i_exist_a_airplane on a_airplane (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_airplane for each row execute procedure tf_lock_update();

create table a_applog (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    status 		varchar(6) 	not null check (status in ('bind','rebind','unbind','msg') and status = lower(status)),
    package 		varchar(256) 	not null,
    name 		varchar(128) 	null,
    facility 		uid_t 		null,
    state 		code_t 		null check (state = lower(state)),
    cookie 		uid_t 		null,
    extra 		text 		null
);

create index i_user_id_a_applog on a_applog (user_id);
create index i_fix_date_a_applog on a_applog (left(fix_dt,10));
create index i_exist_a_applog on a_applog (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_applog for each row execute procedure tf_lock_update();

create table a_bluetooth (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    state 		varchar(3) 	not null check (state in ('on','off') and state = lower(state))
);

create index i_user_id_a_bluetooth on a_bluetooth (user_id);
create index i_fix_date_a_bluetooth on a_bluetooth (left(fix_dt,10));
create index i_exist_a_bluetooth on a_bluetooth (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_bluetooth for each row execute procedure tf_lock_update();

create table a_device (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t	not null,
    satellite_dt 	datetime_t	null,
    latitude 		gps_t		null,
    longitude 		gps_t		null,
    os_name		varchar(7) 	not null check (os_name in ('android') and os_name = lower(os_name)),
    os_version		code_t 		not null,
    model		descr_t		not null,
    manufacturer	descr_t		not null,
    fingerprint		descr_t		not null,
    uptime		int64_t		not null,
    myuid		int32_t		not null,
    cpu_abis 		descr_t 	null,
    cpu_cores		int32_t		not null,
    heap_size		int64_t		not null,
    screen_inches 	numeric(3,1)  	not null,
    screen_density 	int32_t 	not null,
    screen_height 	int32_t 	not null,
    screen_width 	int32_t 	not null,
    su 			varchar(2048) 	null,
    kernel 		varchar(512) 	null,
    vstamp 		code_t 		not null
);

create index i_user_id_a_device on a_device (user_id);
create index i_fix_date_a_device on a_device (left(fix_dt,10));
create index i_exist_a_device on a_device (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_device for each row execute procedure tf_lock_update();

create table a_exchange (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    mode 		varchar(8) 	not null check (mode in ('docs','sync','upd') and mode = lower(mode)),
    status 		varchar(8) 	not null check (status in ('success','failed') and status = lower(status)),
    packets 		int32_t 	null,
    corrupted 		int32_t 	null,
    msg 		varchar(512) 	null
);

create index i_user_id_a_exchange on a_exchange (user_id);
create index i_fix_date_a_exchange on a_exchange (left(fix_dt,10));
create index i_exist_a_exchange on a_exchange (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_exchange for each row execute procedure tf_lock_update();

create table a_gps_pos (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	not null,
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    accuracy 		double_t 	not null,
    altitude 		double_t 	not null,
    bearing 		double_t 	not null,
    speed 		double_t 	not null, /* in meters/second over ground */
    seconds 		int32_t 	null,
    provider 		varchar(8) 	null check (provider in ('gps','network') and provider = lower(provider)),
    satellites 		int32_t 	null
);

create index i_user_id_a_gps_pos on a_gps_pos (user_id);
create index i_fix_date_a_gps_pos on a_gps_pos (left(fix_dt,10));
create index i_exist_a_gps_pos on a_gps_pos (user_id, dev_pack, dev_id, fix_dt);
create index i_daily_a_gps_pos on a_gps_pos (user_id, left(fix_dt,10)); /* especially for getting daily data */
create index i_2lts_a_gps_pos on a_gps_pos (inserted_ts);

create trigger trig_lock_update before update on a_gps_pos for each row execute procedure tf_lock_update();

create table a_gps_trace (
    act_id 		uid_t 		not null,
    row_no 		int32_t 	not null default 0 check (row_no >= 0),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	not null,
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    accuracy 		double_t 	not null,
    altitude 		double_t 	not null,
    bearing 		double_t 	not null,
    speed 		double_t 	not null,
    seconds 		int32_t 	null,
    provider 		varchar(8) 	null check (provider in ('gps','network') and provider = lower(provider)),
    satellites 		int32_t 	null,
    primary key (act_id, row_no)
);

create index i_user_id_a_gps_trace on a_gps_trace (user_id);
create index i_fix_date_a_gps_trace on a_gps_trace (left(fix_dt,10));
create index i_daily_a_gps_trace on a_gps_trace (user_id, left(fix_dt,10)); /* especially for getting daily data */
create index i_2lts_a_gps_trace on a_gps_trace (inserted_ts);

create trigger trig_lock_update before update on a_gps_trace for each row execute procedure tf_lock_update();

create table a_gps_state (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    provider 		varchar(8) 	not null check (provider in ('gps','network') and provider = lower(provider)),
    state 		varchar(16) 	not null check (state in ('off','on','failed','not_permitted') and state = lower(state)),
    msg 		varchar(512) 	null
);

create index i_user_id_a_gps_state on a_gps_state (user_id);
create index i_fix_date_a_gps_state on a_gps_state (left(fix_dt,10));
create index i_exist_a_gps_state on a_gps_state (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_gps_state for each row execute procedure tf_lock_update();

create table a_gsm_pos (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    mcc 		int32_t 	not null,
    mnc 		int32_t 	not null,
    cid 		int32_t 	not null,
    lac 		int32_t 	not null,
    tA 			int32_t 	not null,
    asu 		int32_t 	not null,
    rxlev 		int32_t 	not null,
    radio 		varchar(5) 	not null check (radio in ('gsm','cdma','wcdma','umts','lte') and radio = lower(radio)),
    accuracy 		double_t 	null,
    altitude 		double_t 	null,
    bearing 		double_t 	null,
    speed 		double_t 	null
);

create index i_user_id_a_gsm_pos on a_gsm_pos (user_id);
create index i_fix_date_a_gsm_pos on a_gsm_pos (left(fix_dt,10));
create index i_exist_a_gsm_pos on a_gsm_pos (user_id, dev_pack, dev_id, fix_dt);
create index i_daily_a_gsm_pos on a_gsm_pos (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on a_gsm_pos for each row execute procedure tf_lock_update();

create table a_gsm_trace (
    act_id 		uid_t 		not null,
    row_no 		int32_t 	not null default 0 check (row_no >= 0),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    mcc 		int32_t 	not null,
    mnc 		int32_t 	not null,
    cid 		int32_t 	not null,
    lac 		int32_t 	not null,
    tA 			int32_t 	not null,
    asu 		int32_t 	not null,
    rxlev 		int32_t 	not null,
    accuracy 		double_t 	null,
    altitude 		double_t 	null,
    bearing 		double_t 	null,
    speed 		double_t 	null,
    radio 		varchar(5) 	not null check (radio in ('gsm','cdma','wcdma','umts','lte') and radio = lower(radio)),
    primary key (act_id, row_no)
);

create index i_user_id_a_gsm_trace on a_gsm_trace (user_id);
create index i_fix_date_a_gsm_trace on a_gsm_trace (left(fix_dt,10));
create index i_daily_a_gsm_trace on a_gsm_trace (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on a_gsm_trace for each row execute procedure tf_lock_update();

create table a_gsm_state (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    sim0_state		varchar(12)	not null check (sim0_state in ('absent','locked','pin_required','puk_required','ready','unknown') and sim0_state = lower(sim0_state)),
    sim1_state		varchar(12)	not null check (sim1_state in ('absent','locked','pin_required','puk_required','ready','unknown') and sim1_state = lower(sim1_state))
);


create index i_user_id_a_gsm_state on a_gsm_state (user_id);
create index i_fix_date_a_gsm_state on a_gsm_state (left(fix_dt,10));
create index i_exist_a_gsm_state on a_gsm_state (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_gsm_state for each row execute procedure tf_lock_update();

create table a_heap (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    pid 		int64_t 	not null,
    image_name 		varchar(512) 	not null,
    vm_max 		int64_t 	not null,
    vm_allocated 	int64_t 	not null,
    vm_free 		int64_t 	not null,
    native_heapsize 	int64_t 	not null,
    native_allocated 	int64_t 	not null,
    native_free 	int64_t 	not null,
    msg 		varchar(512) 	null
);

create index i_user_id_a_heap on a_heap (user_id);
create index i_fix_date_a_heap on a_heap (left(fix_dt,10));
create index i_exist_a_heap on a_heap (user_id, dev_pack, dev_id, fix_dt);
create index i_daily_a_heap on a_heap (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on a_heap for each row execute procedure tf_lock_update();

create table a_heap_trace (
    act_id 		uid_t 		not null,
    row_no 		int32_t 	not null default 0 check (row_no >= 0),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    pid 		int64_t 	not null,
    image_name 		varchar(512) 	not null,
    vm_max 		int64_t 	not null,
    vm_allocated 	int64_t 	not null,
    vm_free 		int64_t 	not null,
    native_heapsize 	int64_t 	not null,
    native_allocated 	int64_t 	not null,
    native_free 	int64_t 	not null,
    msg 		varchar(512) 	null,
    primary key (act_id, row_no)
);

create index i_user_id_a_heap_trace on a_heap_trace (user_id);
create index i_fix_date_a_heap_trace on a_heap_trace (left(fix_dt,10));
create index i_daily_a_heap_trace on a_heap_trace (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on a_heap_trace for each row execute procedure tf_lock_update();

create table a_lifecycle (
    act_id		uid_t 		not null primary key default act_id(),
    inserted_ts		ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    satellite_dt	datetime_t 	null,
    latitude		gps_t		null,
    longitude		gps_t		null,
    pid			int64_t 	not null,
    facility 		varchar(8) 	not null check (facility in ('os','process','service','activity') and facility = lower(facility)),
    name		varchar(512) 	not null,
    state		varchar(9)	not null check (state in ('start','stop','crash','exception','resume','suspend') and state = lower(state)),
    extra		text 		null
);

create index i_user_id_a_lifecycle on a_lifecycle (user_id);
create index i_fix_date_a_lifecycle on a_lifecycle (left(fix_dt,10));
create index i_exist_a_lifecycle on a_lifecycle (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_lifecycle for each row execute procedure tf_lock_update();

create table a_network (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    /*obsolete states: 'suspended','connecting','disconnecting','unknown'*/
    state 		varchar(13) 	not null check (state in ('suspended','connected','connecting','disconnected','disconnecting','unknown') and state = lower(state)),
    msg 		varchar(512)	null,
    /*obsolete:*/ background 		bool_t 		null
);

create index i_user_id_a_network on a_network (user_id);
create index i_fix_date_a_network on a_network (left(fix_dt,10));
create index i_exist_a_network on a_network (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_network for each row execute procedure tf_lock_update();

create table a_package (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    status 		varchar(7) 	not null check (status in ('added','removed','changed') and status = lower(status)),
    package 		varchar(256) 	not null,
    enabled 		bool_t 		not null,
    name 		varchar(128) 	null,
    system 		bool_t 		null,
    debuggable 		bool_t 		null
);

create index i_user_id_a_package on a_package (user_id);
create index i_fix_date_a_package on a_package (left(fix_dt,10));
create index i_exist_a_package on a_package (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_package for each row execute procedure tf_lock_update();

create table a_power (
    act_id		uid_t 		not null primary key default act_id(),
    inserted_ts		ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    state		varchar(8) 	not null check (state in ('on','off','unknown') and state = lower(state)),
    battery_life 	INT2  		not null default 255 check (battery_life between 0 and 100 or battery_life = 255),
    temperature 	numeric(4,1) 	null,
    voltage 		numeric(8,3) 	null,
    tech 		varchar(16) 	null,
    power_save 		bool_t 		null,
    idle 		bool_t 		null,
    usb 		bool_t 		null,
    ibo 		bool_t 		null, /* IgnoringBatteryOptimizations */
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t		null
);

create index i_user_id_a_power on a_power (user_id);
create index i_fix_date_a_power on a_power (left(fix_dt,10));
create index i_exist_a_power on a_power (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_power for each row execute procedure tf_lock_update();

create table a_sms (
    act_id		uid_t		not null primary key default act_id(),
    inserted_ts		ts_auto_t	not null,
    inserted_node	hostname_t	not null,
    dev_pack		int32_t		not null,
    dev_id		devid_t		not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    satellite_dt	datetime_t 	null,
    latitude		gps_t 		null,
    longitude		gps_t 		null,
    service_center 	code_t 		null,
    sender 		code_t 		null,
    receiver 		code_t 		null,
    msg			varchar(2048) 	null
);

create index i_user_id_a_sms on a_sms (user_id);
create index i_fix_date_a_sms on a_sms (left(fix_dt,10));
create index i_exist_a_sms on a_sms (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_sms for each row execute procedure tf_lock_update();

create table a_statfs (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    available_bytes 	int64_t 	not null,
    free_bytes 		int64_t 	not null,
    total_bytes 	int64_t 	not null,
    path 		varchar(2048) 	not null
);

create index i_user_id_a_statfs on a_statfs (user_id);
create index i_fix_date_a_statfs on a_statfs (left(fix_dt,10));
create index i_exist_a_statfs on a_statfs (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_statfs for each row execute procedure tf_lock_update();

create table a_time (
    act_id		uid_t		not null primary key default act_id(),
    inserted_ts		ts_auto_t	not null,
    inserted_node	hostname_t	not null,
    dev_pack		int32_t		not null,
    dev_id		devid_t		not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    satellite_dt	datetime_t 	null,
    latitude		gps_t 		null,
    longitude		gps_t 		null,
    status		varchar(8) 	not null check (status in ('time','timezone') and status = lower(status)),
    msg			varchar(512) 	null,
    diff 		int32_t 	null, /* approximate time difference in minutes */
    interactive 	bool_t 		null
);

create index i_user_id_a_time on a_time (user_id);
create index i_fix_date_a_time on a_time (left(fix_dt,10));
create index i_exist_a_time on a_time (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_time for each row execute procedure tf_lock_update();

create table a_traffic (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    mobile_rx_bytes 	int64_t 	not null,
    mobile_tx_bytes 	int64_t 	not null,
    total_rx_bytes 	int64_t 	not null,
    total_tx_bytes 	int64_t 	not null,
    omobus_rx_bytes 	int64_t 	not null,
    omobus_tx_bytes 	int64_t 	not null,
    duration 		int64_t 	not null
);

create index i_user_id_a_traffic on a_traffic (user_id);
create index i_fix_date_a_traffic on a_traffic (left(fix_dt,10));
create index i_exist_a_traffic on a_traffic (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_traffic for each row execute procedure tf_lock_update();

create table a_wifi (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    state 		varchar(3) 	not null check (state in ('on','off') and state = lower(state))
);

create index i_user_id_a_wifi on a_wifi (user_id);
create index i_fix_date_a_wifi on a_wifi (left(fix_dt,10));
create index i_exist_a_wifi on a_wifi (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_wifi for each row execute procedure tf_lock_update();

create table a_user_activity (
    act_id 		uid_t		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    satellite_dt 	datetime_t 	null,
    state 		varchar(8) 	not null check (state in ('begin','end') and state = lower(state)),
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		null,
    a_cookie 		uid_t 		not null,
    route_date 		date_t 		null,
    employee_id 	uid_t 		null,
    extra_info 		note_t 		null,
    docs 		int32_t 	null
);

create index i_user_id_a_user_activity on a_user_activity (user_id);
create index i_account_id_a_user_activity on a_user_activity (account_id);
create index i_activity_type_id_a_user_activ on a_user_activity (activity_type_id);
create index i_a_cookie_a_user_activity on a_user_activity (a_cookie);
create index i_fix_date_a_user_activity on a_user_activity (left(fix_dt,10));
create index i_exist_a_user_activity on a_user_activity (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_user_activity for each row execute procedure tf_lock_update();

create table a_user_document (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack 		int32_t		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    satellite_dt 	datetime_t 	null,
    fix_dt 		datetime_t 	not null,
    doc_type 		doctype_t 	not null,
    doc_no 		uid_t 		not null,
    duration 		int32_t 	not null,
    rows 		int32_t 	null,
    w_cookie 		uid_t 		null,
    /* activity to the account: */
    c_cookie 		uid_t 		null,
    a_cookie 		uid_t 		null,
    account_id 		uid_t 		null,
    activity_type_id 	uid_t 		null,
    employee_id 	uid_t 		null
);

create index i_user_id_a_user_document on a_user_document (user_id);
create index i_fix_date_a_user_document on a_user_document (left(fix_dt,10));
create index i_account_id_a_user_document on a_user_document (account_id);
create index i_a_type_id_a_user_document on a_user_document (activity_type_id);
create index i_employee_id_a_user_document on a_user_document (employee_id);
create index i_exist_a_user_document on a_user_document (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_a_user_document on a_user_document (inserted_ts);

create trigger trig_lock_update before update on a_user_document for each row execute procedure tf_lock_update();

create table a_user_joint (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    latitude		gps_t 		null,
    longitude 		gps_t 		null,
    satellite_dt 	datetime_t 	null,
    state 		varchar(8)	not null check (state in ('begin','end') and state = lower(state)),
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		not null,
    employee_id 	uid_t 		null
);

create index i_user_id_a_user_joint on a_user_joint (user_id);
create index i_fix_date_a_user_joint on a_user_joint (left(fix_dt,10));
create index i_exist_a_user_joint on a_user_joint (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_user_joint for each row execute procedure tf_lock_update();

create table a_user_report (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    satellite_dt 	datetime_t 	null,
    fix_dt 		datetime_t 	not null,
    doc_type 		doctype_t 	not null,
    duration 		int32_t 	not null,
    w_cookie 		uid_t 		null,
    /* activity to the account: */
    c_cookie 		uid_t 		null,
    a_cookie 		uid_t 		null,
    account_id 		uid_t 		null,
    activity_type_id 	uid_t 		null,
    employee_id 	uid_t 		null
);

create index i_user_id_a_user_report on a_user_report (user_id);
create index i_account_id_a_user_report on a_user_report (account_id);
create index i_a_type_id_a_user_report on a_user_report (activity_type_id);
create index i_fix_date_a_user_report on a_user_report (left(fix_dt,10));
create index i_employee_id_a_user_report on a_user_document (employee_id);
create index i_exist_a_user_report on a_user_report (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_a_user_report on a_user_report (inserted_ts);

create trigger trig_lock_update before update on a_user_report for each row execute procedure tf_lock_update();

create table a_user_work (
    act_id 		uid_t 		not null primary key default act_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    latitude		gps_t 		null,
    longitude 		gps_t 		null,
    satellite_dt 	datetime_t 	null,
    state 		varchar(8)	not null check (state in ('begin','end') and state = lower(state)),
    w_cookie 		uid_t 		not null
);

create index i_user_id_a_user_work on a_user_work (user_id);
create index i_fix_date_a_user_work on a_user_work (left(fix_dt,10));
create index i_exist_a_user_work on a_user_work (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on a_user_work for each row execute procedure tf_lock_update();


-- **** Documents ****

create table h_addition (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    guid 		uid_t 		not null,
    blobs 		int32_t 	not null,
    account 		descr_t 	not null,
    address 		address_t 	not null,
    legal_address 	address_t 	null,
    number 		code_t 		null,
    addition_type_id 	uid_t 		null,
    chan_id 		uid_t 		null,
    photos 		blobs_t 	null,
    attr_ids 		uids_t 		null
);

create index i_fix_date_h_addition on h_addition (left(fix_dt,10));
create index i_doc_no_h_addition on h_addition (doc_no);
create index i_user_id_h_addition on h_addition (user_id);
create index i_exist_h_addition on h_addition (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_addition for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();

create table h_advt ( /* advertisement in the outlet */
    doc_id		uid_t 		not null primary key default doc_id(),
    inserted_ts		ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    doc_no		uid_t 		not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    account_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt	datetime_t 	null,
    created_gps_la	gps_t 		null,
    created_gps_lo	gps_t 		null,
    closed_dt		datetime_t 	not null,
    closed_gps_dt	datetime_t 	null,
    closed_gps_la	gps_t 		null,
    closed_gps_lo	gps_t 		null,
    w_cookie		uid_t 		not null,
    a_cookie		uid_t 		not null,
    activity_type_id	uid_t 		not null,
    rows		int32_t 	not null
);

create table t_advt (
    doc_id		uid_t 		not null,
    row_no		int32_t 	not null check (row_no >= 0),
    placement_id 	uid_t 		not null,
    posm_id		uid_t 		not null,
    qty 		int32_t 	not null check (qty >= 0),
    scratch 		date_t 		null,
    primary key (doc_id, placement_id, posm_id)
);

create index i_fix_date_h_advt on h_advt (left(fix_dt,10));
create index i_doc_no_h_advt on h_advt (doc_no);
create index i_account_id_h_advt on h_advt (account_id);
create index i_user_id_h_advt on h_advt (user_id);
create index i_exist_h_advt on h_advt (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_advt for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_advt for each row execute procedure tf_lock_update();

create table h_audit (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null,
    blobs 		int32_t 	not null,
    categ_id		uid_t 		not null,
    wf 			wf_t 		not null check(wf between 0.01 and 1.00),
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    photos		blobs_t		null
);

create table t_audit (
    doc_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    audit_criteria_id 	uid_t 		not null,
    audit_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    primary key (doc_id, audit_criteria_id)
);

create index i_fix_date_h_audit on h_audit (left(fix_dt,10));
create index i_doc_no_h_audit on h_audit (doc_no);
create index i_account_id_h_audit on h_audit (account_id);
create index i_user_id_h_audit on h_audit (user_id);
create index i_exist_h_audit on h_audit (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_audit for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_audit for each row execute procedure tf_lock_update();

create table h_canceling (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    canceling_type_id 	uid_t 		null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null
);

create index i_user_id_h_canceling on h_canceling (user_id);
create index i_fix_date_h_canceling on h_canceling (left(fix_dt,10));
create index i_doc_no_h_canceling on h_canceling (doc_no);
create index i_exist_h_canceling on h_canceling (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_canceling for each row execute procedure tf_lock_update();

create table h_checkup (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null
);

create table t_checkup (
    doc_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    placement_id 	uid_t 		not null,
    prod_id 		uid_t 		not null,
    exist 		int32_t 	not null check (exist between 0 and 2),
    primary key (doc_id, placement_id, prod_id)
);

create index i_user_id_h_checkup on h_checkup (user_id);
create index i_fix_date_h_checkup on h_checkup (left(fix_dt,10));
create index i_doc_no_h_checkup on h_checkup (doc_no);
create index i_account_id_h_checkup on h_checkup (account_id);
create index i_exist_h_checkup on h_checkup (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_checkup for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_checkup for each row execute procedure tf_lock_update();

create table h_comment (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    comment_type_id 	uid_t 		null,
    photo 		blob_t 		null
);

create index i_user_id_h_comment on h_comment (user_id);
create index i_fix_date_h_comment on h_comment (left(fix_dt,10));
create index i_doc_no_h_comment on h_comment (doc_no);
create index i_account_id_h_comment on h_comment (account_id);
create index i_exist_h_comment on h_comment (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_comment on h_comment (inserted_ts);

create trigger trig_lock_update before update on h_comment for each row execute procedure tf_lock_update();

create table h_confirmation (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    target_id 		uid_t 		not null,
    confirmation_type_id uid_t 		not null,
    blobs 		int32_t 	not null,
    photos 		blobs_t 	null
);

create index i_fix_date_h_confirmation on h_confirmation (left(fix_dt,10));
create index i_doc_no_h_confirmation on h_confirmation (doc_no);
create index i_account_id_h_confirmation on h_confirmation (account_id);
create index i_user_id_h_confirmation on h_confirmation (user_id);
create index i_exist_h_confirmation on h_confirmation (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_confirmation on h_confirmation (inserted_ts);

create trigger trig_lock_update before update on h_confirmation for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();

create table h_contact (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    contact_id 		uid_t 		not null,
    job_title_id 	uid_t 		not null,
    name 		descr_t 	not null,
    surname 		descr_t 	null,
    patronymic 		descr_t 	null,
    phone 		phone_t 	null,
    mobile 		phone_t 	null,
    email 		email_t 	null,
    loyalty_level_id 	uid_t 		null,
    consent 		blob_t 		null, /* consent to the processing of personal data */
    locked 		bool_t 		not null default 0,
    deleted 		bool_t 		not null default 0,
    exist 		bool_t 		not null default 1
);

create index i_fix_date_h_contact on h_contact (left(fix_dt,10));
create index i_doc_no_h_contact on h_contact (doc_no);
create index i_account_id_h_contact on h_contact (account_id);
create index i_user_id_h_contact on h_contact (user_id);
create index i_exist_h_contact on h_contact (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_contact for each row execute procedure tf_lock_update();

create table h_deletion (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    photo 		blob_t 		null
);

create index i_user_id_h_deletion on h_deletion (user_id);
create index i_fix_date_h_deletion on h_deletion (left(fix_dt,10));
create index i_doc_no_h_deletion on h_deletion (doc_no);
create index i_account_id_h_deletion on h_deletion (account_id);
create index i_exist_h_deletion on h_deletion (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_deletion for each row execute procedure tf_lock_update();

create table h_discard ( /* remove account from the [route] */
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    account_id 		uid_t 		not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    discard_type_id 	uid_t 		null,
    route_date 		date_t 		not null
);

create index i_fix_date_h_discard on h_discard (left(fix_dt,10));
create index i_doc_no_h_discard on h_discard (doc_no);
create index i_account_id_h_discard on h_discard (account_id);
create index i_user_id_h_discard on h_discard (user_id);
create index i_exist_h_discard on h_discard (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_discard for each row execute procedure tf_lock_update();

create table h_dismiss ( /* dismiss [reminder] */
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    reminder_id 	uid_t 		not null
);

create index i_user_id_h_dismiss on h_dismiss (user_id);
create index i_fix_date_h_dismiss on h_dismiss (left(fix_dt,10));
create index i_doc_no_h_dismiss on h_dismiss (doc_no);
create index i_user_id_reminder_id_h_dismiss on h_dismiss (user_id, reminder_id);
create index i_exist_h_dismiss on h_dismiss (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_dismiss for each row execute procedure tf_lock_update();

create table h_equipment (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    equipment_id 	uid_t 		not null,
    serial_number 	code_t 		not null,
    equipment_type_id 	uid_t 		not null,
    ownership_type_id 	uid_t 		null,
    photo 		blob_t 		null,
    deleted 		bool_t 		not null default 0,
    exist 		bool_t 		not null default 1
);

create index i_fix_date_h_equipment on h_equipment (left(fix_dt,10));
create index i_doc_no_h_equipment on h_equipment (doc_no);
create index i_account_id_h_equipment on h_equipment (account_id);
create index i_user_id_h_equipment on h_equipment (user_id);
create index i_exist_h_equipment on h_equipment (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_equipment for each row execute procedure tf_lock_update();

create table h_location (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    doc_no 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	not null,
    latitude 		gps_t 		not null,
    longitude 		gps_t 		not null,
    accuracy 		double_t 	null,
    dist 		double_t 	null, -- clarification of account location (in meters)
    activity_type_id 	uid_t 		not null,
    account_id 		uid_t 		not null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null
);

create index i_fix_date_h_location on h_location (left(fix_dt,10));
create index i_account_id_h_location on h_location (account_id);
create index i_user_id_h_location on h_location (user_id);
create index i_exist_h_location on h_location (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_location for each row execute procedure tf_lock_update();

create table h_oos ( /* Out-of-Stock */
    doc_id		uid_t 		not null primary key default doc_id(),
    inserted_ts		ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    doc_no		uid_t 		not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    account_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt	datetime_t 	null,
    created_gps_la	gps_t 		null,
    created_gps_lo	gps_t 		null,
    closed_dt		datetime_t 	not null,
    closed_gps_dt	datetime_t 	null,
    closed_gps_la	gps_t 		null,
    closed_gps_lo	gps_t 		null,
    w_cookie		uid_t 		not null,
    a_cookie		uid_t 		not null,
    activity_type_id	uid_t 		not null,
    rows		int32_t 	not null
);

create table t_oos (
    doc_id		uid_t 		not null,
    row_no		int32_t 	not null check (row_no >= 0),
    prod_id		uid_t 		not null,
    oos_type_id 	uid_t 		not null,
    note 		note_t 		null,
    primary key (doc_id, prod_id)
);

create index i_fix_date_h_oos on h_oos (left(fix_dt,10));
create index i_doc_no_h_oos on h_oos (doc_no);
create index i_account_id_h_oos on h_oos (account_id);
create index i_user_id_h_oos on h_oos (user_id);
create index i_exist_h_oos on h_oos (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_oos for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_oos for each row execute procedure tf_lock_update();

create table h_order (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    distr_id 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    order_type_id 	uid_t 		null,
    group_price_id 	uid_t 		null,
    wareh_id 		uid_t 		null,
    delivery_date 	date_t 		not null,
    delivery_type_id 	uid_t 		null,
    delivery_note 	note_t 		null,
    amount 		currency_t 	not null,
    rows 		int32_t 	not null,
    weight 		weight_t 	not null,
    volume 		volume_t 	not null,
    payment_method_id 	uid_t 		null,
    payment_delay 	int32_t 	null check (payment_delay is null or (payment_delay >= 0)),
    bonus 		currency_t 	null check (bonus is null or (bonus >= 0)),
    encashment 		currency_t 	null check (encashment is null or (encashment >= 0)),
    order_param_ids 	uids_t		null
);

create table t_order (
    doc_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    pack_id 		uid_t 		not null,
    pack 		numeric_t 	not null,
    qty 		numeric_t 	not null,
    unit_price 		currency_t 	not null check (unit_price >= 0),
    discount 		discount_t 	not null,
    amount 		currency_t 	not null,
    weight 		weight_t 	not null,
    volume 		volume_t 	not null,
    primary key (doc_id, prod_id)
);

create index i_fix_date_h_order on h_order (left(fix_dt,10));
create index i_doc_no_h_order on h_order (doc_no);
create index i_account_id_h_order on h_order (account_id);
create index i_user_id_h_order on h_order (user_id);
create index i_exist_h_order on h_order (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_order on h_order (inserted_ts);

create trigger trig_lock_update before update on h_order for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_order for each row execute procedure tf_lock_update();

create table h_pending (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    account_id 		uid_t 		not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    pending_type_id 	uid_t 		null,
    route_date 		date_t 		not null
);

create index i_fix_date_h_pending on h_pending (left(fix_dt,10));
create index i_doc_no_h_pending on h_pending (doc_no);
create index i_account_id_h_pending on h_pending (account_id);
create index i_user_id_h_pending on h_pending (user_id);
create index i_exist_h_pending on h_pending (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_pending for each row execute procedure tf_lock_update();

create table h_photo (
    doc_id		uid_t		not null primary key default doc_id(),
    inserted_ts		ts_auto_t	not null,
    inserted_node	hostname_t	not null,
    dev_pack		int32_t		not null,
    doc_no		uid_t		not null,
    dev_id		devid_t		not null,
    dev_login		uid_t		not null,
    user_id		uid_t		not null,
    account_id		uid_t		not null,
    fix_dt		datetime_t	not null,
    created_dt		datetime_t	not null,
    created_gps_dt	datetime_t	null,
    created_gps_la	gps_t		null,
    created_gps_lo	gps_t		null,
    closed_dt		datetime_t	not null,
    closed_gps_dt	datetime_t	null,
    closed_gps_la	gps_t		null,
    closed_gps_lo	gps_t		null,
    w_cookie		uid_t		not null,
    a_cookie		uid_t		not null,
    doc_note		note_t		null,
    activity_type_id	uid_t		not null,
    placement_id 	uid_t		not null,
    brand_id		uid_t		null,
    photo_type_id	uid_t		null,
    photo_param_ids 	uids_t		null,
    photo		blob_t		not null,
    rev_cookie 		uid_t 		null
);

create index i_fix_date_h_photo on h_photo (left(fix_dt,10));
create index i_doc_no_h_photo on h_photo (doc_no);
create index i_account_id_h_photo on h_photo (account_id);
create index i_user_id_h_photo on h_photo (user_id);
create index i_exist_h_photo on h_photo (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_photo on h_photo (inserted_ts);
create index i_rev_cookie_h_photo on h_photo (rev_cookie);

create trigger trig_lock_update before update on h_photo for each row execute procedure tf_lock_update();

create table h_posm (
    doc_id		uid_t		not null primary key default doc_id(),
    inserted_ts		ts_auto_t	not null,
    inserted_node	hostname_t	not null,
    dev_pack		int32_t		not null,
    doc_no		uid_t		not null,
    dev_id		devid_t		not null,
    dev_login		uid_t		not null,
    user_id		uid_t		not null,
    account_id		uid_t		not null,
    fix_dt		datetime_t	not null,
    created_dt		datetime_t	not null,
    created_gps_dt	datetime_t	null,
    created_gps_la	gps_t		null,
    created_gps_lo	gps_t		null,
    closed_dt		datetime_t	not null,
    closed_gps_dt	datetime_t	null,
    closed_gps_la	gps_t		null,
    closed_gps_lo	gps_t		null,
    w_cookie		uid_t		not null,
    a_cookie		uid_t		not null,
    doc_note		note_t		null,
    activity_type_id	uid_t		not null,
    placement_id 	uid_t		not null,
    posm_id		uid_t		not null,
    photo		blob_t		not null,
    rev_cookie 		uid_t 		null
);

create index i_fix_date_h_posm on h_posm (left(fix_dt,10));
create index i_doc_no_h_posm on h_posm (doc_no);
create index i_account_id_h_posm on h_posm (account_id);
create index i_user_id_h_posm on h_posm (user_id);
create index i_exist_h_posm on h_posm (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_posm on h_posm (inserted_ts);
create index i_rev_cookie_h_posm on h_posm (rev_cookie);

create trigger trig_lock_update before update on h_posm for each row execute procedure tf_lock_update();

create table h_presence (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null
);

create table t_presence (
    doc_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    facing 		int32_t 	not null check (facing >= 0),
    stock 		int32_t 	not null check (stock >= 0),
    scratch 		date_t 		null,
    primary key (doc_id, prod_id)
);

create index i_fix_date_h_presence on h_presence (left(fix_dt,10));
create index i_doc_no_h_presence on h_presence (doc_no);
create index i_account_id_h_presence on h_presence (account_id);
create index i_user_id_h_presence on h_presence (user_id);
create index i_exist_h_presence on h_presence (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_presence on h_presence (inserted_ts);

create trigger trig_lock_update before update on h_presence for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_presence for each row execute procedure tf_lock_update();

create table h_presentation (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    doc_note 		note_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    participants 	int32_t 	not null,
    tm_ids 		uids_t 		null,
    blobs 		int32_t 	not null,
    photos		blobs_t		null
);

create index i_fix_date_h_presentation on h_presentation (left(fix_dt,10));
create index i_doc_no_h_presentation on h_presentation (doc_no);
create index i_account_id_h_presentation on h_presentation (account_id);
create index i_user_id_h_presentation on h_presentation (user_id);
create index i_exist_h_presentation on h_presentation (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_presentation for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();

create table h_price (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null
);

create table t_price (
    doc_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    price 		currency_t 	not null,
    promo 		bool_t 		not null default 0,
    rrp 		currency_t 	null,
    scratch 		date_t 		null,
    primary key (doc_id, prod_id)
);

create index i_fix_date_h_price on h_price (left(fix_dt,10));
create index i_doc_no_h_price on h_price (doc_no);
create index i_account_id_h_price on h_price (account_id);
create index i_user_id_h_price on h_price (user_id);
create index i_exist_h_price on h_price (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_price for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_price for each row execute procedure tf_lock_update();

create table h_profile (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    chan_id 		uid_t 		null,
    poten_id 		uid_t 		null,
    cash_register 	int32_t 	null,
    attr_ids 		uids_t 		null
);

create index i_fix_date_h_profile on h_profile (left(fix_dt,10));
create index i_doc_no_h_profile on h_profile (doc_no);
create index i_account_id_h_profile on h_profile (account_id);
create index i_user_id_h_profile on h_profile (user_id);
create index i_exist_h_profile on h_profile (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_profile for each row execute procedure tf_lock_update();

create table h_promo (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    categ_id 		uid_t 		not null,
    brand_id 		uid_t 		not null,
    promo_type_ids 	uids_t 		not null,
    blobs 		int32_t 	not null,
    photos 		blobs_t 	null
);

create index i_fix_date_h_promo on h_promo (left(fix_dt,10));
create index i_doc_no_h_promo on h_promo (doc_no);
create index i_account_id_h_promo on h_promo (account_id);
create index i_user_id_h_promo on h_promo (user_id);
create index i_exist_h_promo on h_promo (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_promo on h_promo (inserted_ts);

create trigger trig_lock_update before update on h_promo for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();

/*[deprecated]*/ create table h_pt ( /* price-tags */
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    prod_id 		uid_t 		not null,
    photo 		blob_t 		not null
);

create index i_user_id_h_pt on h_pt (user_id);
create index i_fix_date_h_pt on h_pt (left(fix_dt,10));
create index i_doc_no_h_pt on h_pt (doc_no);
create index i_account_id_h_pt on h_pt (account_id);
create index i_exist_h_pt on h_pt (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_pt for each row execute procedure tf_lock_update();

create table h_quest (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null
);

create table t_quest (
    doc_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    qname_id 		uid_t 		not null,
    qrow_id 		uid_t 		not null,
    value 		note_t 		not null,
    primary key (doc_id, qname_id, qrow_id)
);

create index i_fix_date_h_quest on h_quest (left(fix_dt,10));
create index i_doc_no_h_quest on h_quest (doc_no);
create index i_account_id_h_quest on h_quest (account_id);
create index i_user_id_h_quest on h_quest (user_id);
create index i_exist_h_quest on h_quest (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_quest for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_quest for each row execute procedure tf_lock_update();

create table h_rating (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null,
    employee_id 	uid_t 		not null,
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    assessment 		numeric(5,3) 	not null check(assessment >= 0)
);

create table t_rating (
    doc_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    rating_criteria_id 	uid_t 		not null,
    rating_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    primary key (doc_id, rating_criteria_id)
);

create index i_fix_date_h_rating on h_rating (left(fix_dt,10));
create index i_doc_no_h_rating on h_rating (doc_no);
create index i_account_id_h_rating on h_rating (account_id);
create index i_user_id_h_rating on h_rating (user_id);
create index i_employee_id_h_rating on h_rating (employee_id);
create index i_exist_h_rating on h_rating (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_rating for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_rating for each row execute procedure tf_lock_update();

create table h_receipt (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    distr_id 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    doc_note 		note_t 		null,
    receipt_type_id 	uid_t 		null,
    amount 		currency_t 	not null
);

create index i_fix_date_h_receipt on h_receipt (left(fix_dt,10));
create index i_doc_no_h_receipt on h_receipt (doc_no);
create index i_account_id_h_receipt on h_receipt (account_id);
create index i_user_id_h_receipt on h_receipt (user_id);
create index i_exist_h_receipt on h_receipt (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_receipt on h_receipt (inserted_ts);

create trigger trig_lock_update before update on h_receipt for each row execute procedure tf_lock_update();

create table h_reclamation (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    distr_id 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    account_id 		uid_t 		not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null,
    return_date 	date_t 		not null,
    amount 		numeric_t 	not null,
    weight 		weight_t 	not null,
    volume 		volume_t 	not null
);

create table t_reclamation (
    doc_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    reclamation_type_id uid_t 		null,
    pack_id 		uid_t 		not null,
    pack 		numeric_t 	not null,
    qty 		numeric_t 	not null,
    unit_price 		currency_t 	not null check (unit_price >= 0),
    amount 		currency_t 	not null,
    weight 		weight_t 	not null,
    volume 		volume_t 	not null,
    primary key (doc_id, prod_id)
);

create index i_fix_date_h_reclamation on h_reclamation (left(fix_dt,10));
create index i_doc_no_h_reclamation on h_reclamation (doc_no);
create index i_account_id_h_reclamation on h_reclamation (account_id);
create index i_user_id_h_reclamation on h_reclamation (user_id);
create index i_exist_h_reclamation on h_reclamation (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_reclamation on h_reclamation (inserted_ts);

create trigger trig_lock_update before update on h_reclamation for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_reclamation for each row execute procedure tf_lock_update();

create table h_review (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		not null,
    employee_id 	uid_t 		not null,
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    assessment 		numeric(5,3) 	not null check(assessment >= 0),
    note0 		note_t 		null,
    note1 		note_t 		null,
    note2 		note_t 		null
);

create index i_fix_date_h_review on h_review (left(fix_dt,10));
create index i_doc_no_h_review on h_review (doc_no);
create index i_employee_id_h_review on h_review (employee_id);
create index i_user_id_h_review on h_review (user_id);
create index i_exist_h_review on h_review (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_review for each row execute procedure tf_lock_update();

create table h_revoke (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rev_cookie 		uid_t 		not null
);

create index i_fix_date_h_revoke on h_revoke (left(fix_dt,10));
create index i_doc_no_h_revoke on h_revoke (doc_no);
create index i_account_id_h_revoke on h_revoke (account_id);
create index i_user_id_h_revoke on h_revoke (user_id);
create index i_exist_h_revoke on h_revoke (user_id, dev_pack, dev_id, fix_dt);
create index i_rev_cookie_h_revoke on h_revoke (rev_cookie);

create trigger trig_lock_update before update on h_revoke for each row execute procedure tf_lock_update();

create table h_shelf ( /* Share-of-Shelf-and-Assortment */
    doc_id		uid_t 		not null primary key default doc_id(),
    inserted_ts		ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    dev_pack		int32_t 	not null,
    doc_no		uid_t 		not null,
    dev_id		devid_t 	not null,
    dev_login		uid_t 		not null,
    user_id		uid_t 		not null,
    account_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt	datetime_t 	null,
    created_gps_la	gps_t 		null,
    created_gps_lo	gps_t 		null,
    closed_dt		datetime_t 	not null,
    closed_gps_dt	datetime_t 	null,
    closed_gps_la	gps_t 		null,
    closed_gps_lo	gps_t 		null,
    w_cookie		uid_t 		not null,
    a_cookie		uid_t 		not null,
    activity_type_id	uid_t 		not null,
    rows		int32_t 	not null,
    blobs 		int32_t 	not null,
    categ_id		uid_t 		not null,
    sos_target 		wf_t 		null check(sos_target between 0.01 and 1.00),
    soa_target 		wf_t 		null check(soa_target between 0.01 and 1.00),
    sos 		numeric(6,5)	null check(sos between 0.0 and 1.0),
    soa 		numeric(6,5)	null check(soa between 0.0 and 1.0),
    photos		blobs_t		null
);

create table t_shelf (
    doc_id		uid_t 		not null,
    row_no		int32_t 	not null check (row_no >= 0),
    brand_id		uid_t 		not null,
    facing 		int32_t 	null check (facing >= 0),
    assortment 		int32_t 	null check (assortment >= 0),
    primary key (doc_id, brand_id)
);

create index i_fix_date_h_shelf on h_shelf (left(fix_dt,10));
create index i_doc_no_h_shelf on h_shelf (doc_no);
create index i_account_id_h_shelf on h_shelf (account_id);
create index i_user_id_h_shelf on h_shelf (user_id);
create index i_exist_h_shelf on h_shelf (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_shelf for each row
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_shelf for each row execute procedure tf_lock_update();

create table h_stock (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null
);

create table t_stock (
    doc_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    manuf_date 		date_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    qty 		int32_t 	not null,
    expired 		bool_t  	not null default 0,
    scratch 		date_t 		null,
    primary key (doc_id, prod_id, manuf_date)
);

create index i_fix_date_h_stock on h_stock (left(fix_dt,10));
create index i_doc_no_h_stock on h_stock (doc_no);
create index i_account_id_h_stock on h_stock (account_id);
create index i_user_id_h_stock on h_stock (user_id);
create index i_exist_h_stock on h_stock (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_stock for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_stock for each row execute procedure tf_lock_update();

create table h_target (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		varchar(2048) 	null,
    activity_type_id 	uid_t 		not null,
    subject 		descr_t 	not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    target_type_id 	uid_t 		not null,
    myself 		bool_t 		not null,
    urgent 		bool_t 		null,
    photo 		blob_t 		null
);

create index i_fix_date_h_target on h_target (left(fix_dt,10));
create index i_doc_no_h_target on h_target (doc_no);
create index i_account_id_h_target on h_target (account_id);
create index i_user_id_h_target on h_target (user_id);
create index i_exist_h_target on h_target (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_target for each row execute procedure tf_lock_update();

create table h_testing (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    rows 		int32_t 	not null,
    contact_id 		uid_t 		not null,
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0)
);

create table t_testing (
    doc_id 		uid_t 		not null,
    row_no 		int32_t 	not null check (row_no >= 0),
    testing_criteria_id uid_t 		not null,
    testing_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    primary key (doc_id, testing_criteria_id)
);

create index i_fix_date_h_testing on h_testing (left(fix_dt,10));
create index i_doc_no_h_testing on h_testing (doc_no);
create index i_account_id_h_testing on h_testing (account_id);
create index i_user_id_h_testing on h_testing (user_id);
create index i_exist_h_testing on h_testing (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_testing for each row execute procedure tf_lock_update();
create trigger trig_lock_update before update on t_testing for each row execute procedure tf_lock_update();

create table h_training (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    doc_note 		note_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    training_type_id	uid_t		null,
    contact_ids 	uids_t 		not null,
    tm_ids 		uids_t 		not null,
    blobs 		int32_t 	not null,
    photos		blobs_t		null
);

create index i_fix_date_h_training on h_training (left(fix_dt,10));
create index i_doc_no_h_training on h_training (doc_no);
create index i_account_id_h_training on h_training (account_id);
create index i_user_id_h_training on h_training (user_id);
create index i_exist_h_training on h_training (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_training on h_training (inserted_ts);

create trigger trig_lock_update before update on h_training for each row 
    when (not (old.blobs > 0 and (old.photos is null or old.blobs <> array_length(old.photos, 1)))) execute procedure tf_lock_update();

create table h_unsched (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    unsched_type_id 	uid_t 		null
);

create index i_fix_date_h_unsched on h_unsched (left(fix_dt,10));
create index i_doc_no_h_unsched on h_unsched (doc_no);
create index i_user_id_h_unsched on h_unsched (user_id);
create index i_exist_h_unsched on h_unsched (user_id, dev_pack, dev_id, fix_dt);
create index i_2lts_h_unsched on h_unsched (inserted_ts);

create trigger trig_lock_update before update on h_unsched for each row execute procedure tf_lock_update();

create table h_wish (
    doc_id 		uid_t 		not null primary key default doc_id(),
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		not null,
    a_cookie 		uid_t 		not null,
    doc_note 		note_t 		null,
    activity_type_id 	uid_t 		not null,
    weeks 		smallint[] 	not null default array[0,0,0,0] check (array_length(weeks,1)=4),
    days 		smallint[] 	not null default array[0,0,0,0,0,0,0] check (array_length(days,1)=7)
);

create index i_user_id_h_wish on h_wish (user_id);
create index i_fix_date_h_wish on h_wish (left(fix_dt,10));
create index i_doc_no_h_wish on h_wish (doc_no);
create index i_account_id_h_wish on h_wish (account_id);
create index i_exist_h_wish on h_wish (user_id, dev_pack, dev_id, fix_dt);

create trigger trig_lock_update before update on h_wish for each row execute procedure tf_lock_update();


-- *** Journals & different representation of the collected data ****

create table dyn_advt (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    placement_id 	uid_t 		not null,
    posm_id 		uid_t 		not null,
    qty 		int32_t 	not null check (qty >= 0),
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    scratch 		date_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, placement_id, posm_id)
);

create index i_2lts_dyn_advt on dyn_advt (updated_ts);

create trigger trig_updated_ts before update on dyn_advt for each row execute procedure tf_updated_ts();

create table dyn_audits (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    categ_id 		uid_t 		not null,
    audit_criteria_id 	uid_t 		not null,
    audit_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    wf 			wf_t 		not null check(wf between 0.01 and 1.00),
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    photos		blobs_t		null,
    fix_dt 		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, categ_id, audit_criteria_id)
);

create index i_2lts_dyn_audits on dyn_audits(updated_ts);

create trigger trig_updated_ts before update on dyn_audits for each row execute procedure tf_updated_ts();

create table dyn_checkups (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    placement_id 	uid_t 		not null,
    prod_id 		uid_t 		not null,
    exist 		int32_t 	not null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, placement_id, prod_id)
);

create index i_2lts_dyn_checkups on dyn_checkups (updated_ts);

create trigger trig_updated_ts before update on dyn_checkups for each row execute procedure tf_updated_ts();

create table dyn_oos (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    oos_type_id 	uid_t 		not null,
    note 		note_t 		null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, prod_id)
);

create index i_2lts_dyn_oos on dyn_oos (updated_ts);

create trigger trig_updated_ts before update on dyn_oos for each row execute procedure tf_updated_ts();

create table dyn_presences (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    facing 		int32_t 	not null,
    stock 		int32_t 	not null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    scratch 		date_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, prod_id)
);

create index i_2lts_dyn_presences on dyn_presences (updated_ts);

create trigger trig_updated_ts before update on dyn_presences for each row execute procedure tf_updated_ts();

create table dyn_prices (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    price 		currency_t 	not null,
    promo 		bool_t 		not null,
    rrp 		currency_t 	null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    scratch 		date_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, prod_id)
);

create index i_2lts_dyn_prices on dyn_prices (updated_ts);

create trigger trig_updated_ts before update on dyn_prices for each row execute procedure tf_updated_ts();

create table dyn_quests (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    qname_id 		uid_t 		not null,
    qrow_id 		uid_t 		not null,
    value 		note_t 		not null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, qname_id, qrow_id)
);

create index i_2lts_dyn_quests on dyn_quests (updated_ts);

create trigger trig_updated_ts before update on dyn_quests for each row execute procedure tf_updated_ts();

create table dyn_ratings (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    employee_id 	uid_t 		not null,
    rating_criteria_id 	uid_t 		not null,
    rating_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, employee_id, rating_criteria_id)
);

create index i_2lts_dyn_ratings on dyn_ratings (updated_ts);

create trigger trig_updated_ts before update on dyn_ratings for each row execute procedure tf_updated_ts();

create table dyn_reviews (
    fix_date		date_t 		not null,
    employee_id 	uid_t 		not null,
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    assessment 		numeric(5,3)    not null check(assessment >= 0),
    note0 		note_t 		null,
    note1 		note_t 		null,
    note2 		note_t 		null,
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, employee_id)
);

create index i_2lts_dyn_reviews on dyn_reviews (updated_ts);

create trigger trig_updated_ts before update on dyn_reviews for each row execute procedure tf_updated_ts();

create table dyn_shelfs (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    categ_id 		uid_t 		not null,
    brand_id 		uid_t 		not null,
    facing 		int32_t 	null check (facing >= 0),
    assortment 		int32_t 	null check (assortment >= 0),
    sos 		numeric(6,5)	null check(sos between 0.0 and 1.0),
    soa 		numeric(6,5)	null check(soa between 0.0 and 1.0),
    photos		blobs_t		null,
    sos_target 		wf_t 		null check(sos_target between 0.01 and 1.00),
    soa_target 		wf_t 		null check(soa_target between 0.01 and 1.00),
    fix_dt		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, categ_id, brand_id)
);

create index i_2lts_dyn_shelfs on dyn_shelfs (updated_ts);

create trigger trig_updated_ts before update on dyn_shelfs for each row execute procedure tf_updated_ts();

create table dyn_stocks (
    fix_date		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    manuf_date 		date_t 		not null,
    stock 		int32_t 	not null,
    expired 		bool_t  	not null default 0,
    fix_dt 		datetime_t 	not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    scratch 		date_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, account_id, prod_id, manuf_date)
);

create index i_2lts_dyn_stocks on dyn_stocks (updated_ts);

create trigger trig_updated_ts before update on dyn_stocks for each row execute procedure tf_updated_ts();

create table dyn_testings (
    fix_date		date_t 		not null,
    contact_id 		uid_t 		not null,
    testing_criteria_id uid_t 		not null,
    testing_score_id 	uid_t 		null,
    criteria_wf 	wf_t 		not null check(criteria_wf between 0.01 and 1.00),
    score_wf 		wf_t 		null check(score_wf between 0.00 and 1.00),
    score 		int32_t 	null check (score >= 0),
    note 		note_t 		null,
    sla 		numeric(6,5)	not null check(sla between 0.0 and 1.0),
    fix_dt		datetime_t 	not null,
    account_id 		uid_t 		not null,
    user_id 		uid_t 		not null,
    doc_id 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    "_isRecentData"	bool_t 		null,
    primary key(fix_date, contact_id, testing_criteria_id)
);

create index i_2lts_dyn_testings on dyn_testings (updated_ts);

create trigger trig_updated_ts before update on dyn_testings for each row execute procedure tf_updated_ts();

create table j_acts (
    act_id 		uid_t 		not null primary key,
    act_code 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    satellite_dt 	datetime_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null
);

create index i_fix_date_j_acts on j_acts (left(fix_dt,10));
create index i_code_j_acts on j_acts (act_code);
create index i_user_id_j_acts on j_acts (user_id);
create index i_daily_j_acts on j_acts (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on j_acts for each row execute procedure tf_lock_update();

create table j_additions (
    doc_id 		uid_t 		not null primary key, 
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    account 		descr_t 	not null,
    address 		address_t 	not null,
    legal_address 	address_t 	null,
    number 		code_t 		null,
    addition_type_id 	uid_t 		null,
    note 		note_t 		null,
    chan_id 		uid_t 		null,
    photos 		blobs_t 	null,
    attr_ids 		uids_t 		null,
    guid 		uid_t 		not null,
    validator_id 	uid_t		null,
    validated 		bool_t 		not null default 0,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create index i_user_id_j_additions on j_additions (user_id);

create trigger trig_updated_ts before update on j_additions for each row execute procedure tf_updated_ts();

create table j_cancellations (
    user_id		uid_t 		not null,
    route_date		date_t 		not null,
    canceling_type_id	uid_t 		null,
    note 		note_t 		null,
    hidden		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key (user_id, route_date)
);

create trigger trig_updated_ts before update on j_cancellations for each row execute procedure tf_updated_ts();

create table j_deletions (
    account_id  	uid_t 		not null primary key, 
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    note		note_t		null,
    photo		blob_t		null,
    validator_id 	uid_t		null,
    validated 		bool_t 		not null default 0,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create index i_user_id_j_deletions on j_deletions (user_id);
create index i_2lts_j_deletions on j_deletions (updated_ts);

create trigger trig_updated_ts before update on j_deletions for each row execute procedure tf_updated_ts();

create table j_discards (
    account_id  	uid_t 		not null, 
    user_id		uid_t 		not null,
    route_date 		date_t 		not null,
    activity_type_id 	uid_t 		not null,
    fix_dt		datetime_t 	not null,
    discard_type_id 	uid_t 		null,
    note		note_t		null,
    validator_id 	uid_t		null,
    validated 		bool_t 		not null default 0,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key(user_id, account_id, activity_type_id, route_date)
);

create index i_2lts_j_discards on j_discards (updated_ts);

create trigger trig_updated_ts before update on j_discards for each row execute procedure tf_updated_ts();

create table j_docs (
    doc_id 		uid_t 		not null primary key,
    doc_code 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    inserted_node 	hostname_t 	not null,
    dev_pack 		int32_t 	not null,
    doc_no 		uid_t 		not null,
    dev_id 		devid_t 	not null,
    dev_login 		uid_t 		not null,
    user_id 		uid_t 		not null,
    fix_dt 		datetime_t 	not null,
    created_dt 		datetime_t 	not null,
    created_gps_dt 	datetime_t 	null,
    created_gps_la 	gps_t 		null,
    created_gps_lo 	gps_t 		null,
    closed_dt 		datetime_t 	not null,
    closed_gps_dt 	datetime_t 	null,
    closed_gps_la 	gps_t 		null,
    closed_gps_lo 	gps_t 		null,
    w_cookie 		uid_t 		null,
    /* activity to the account: */
    c_cookie 		uid_t 		null,
    a_cookie 		uid_t 		null,
    account_id 		uid_t 		null,
    activity_type_id 	uid_t 		null,
    employee_id 	uid_t 		null
);

create index i_fix_date_j_docs on j_docs (left(fix_dt,10));
create index i_code_j_docs on j_docs (doc_code);
create index i_user_id_j_docs on j_docs (user_id);
create index i_doc_no_j_docs on j_docs (doc_no);
create index i_daily_j_docs on j_docs (user_id, left(fix_dt,10)); /* especially for getting daily data */

create trigger trig_lock_update before update on j_docs for each row execute procedure tf_lock_update();

create table j_pending (
    account_id  	uid_t 		not null, 
    user_id		uid_t 		not null,
    route_date 		date_t 		not null,
    activity_type_id 	uid_t 		not null,
    fix_dt		datetime_t 	not null,
    pending_type_id 	uid_t 		null,
    note		note_t		null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key(user_id, account_id, activity_type_id, route_date)
);

create trigger trig_updated_ts before update on j_pending for each row execute procedure tf_updated_ts();

create table j_remarks (
    doc_id 		uid_t 		not null primary key,
    status 		varchar(8) 	not null check(status in ('accepted','rejected') and status = lower(status)),
    remark_type_id 	uid_t 		null,
    note 		note_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create index i_2lts_j_remarks on j_remarks (updated_ts);
create trigger trig_updated_ts before update on j_remarks for each row execute procedure tf_updated_ts();

create table j_revocations (
    doc_id 		uid_t 		not null primary key,
    doc_type 		doctype_t 	not null,
    rev_cookie 		uid_t 		not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create index i_2lts_j_revocations on j_revocations (updated_ts);
create index i_rev_cookie_j_revocations on j_revocations (rev_cookie);

create trigger trig_updated_ts before update on j_revocations for each row execute procedure tf_updated_ts();

create table j_ttd ( /* Transfered-to-Distributor (see queries/import/TTD.xconf and queries/ttd/orders.xconf for more information) */
    doc_id 		uid_t 		not null primary key,
    status 		varchar(9) 	not null check (status in ('delivered','accepted') and status = lower(status)),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on j_ttd for each row execute procedure tf_updated_ts();

create table j_user_activities (
    user_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		null,
    a_cookie 		uid_t 		not null,
    activity_type_id 	uid_t 		not null,
    fix_date 		date_t 		null,
    route_date 		date_t 		null,
    employee_id 	uid_t 		null,
    b_dt 		datetime_t 	null,
    b_la 		gps_t 		null,
    b_lo 		gps_t 		null,
    b_sat_dt 		datetime_t 	null,
    e_dt 		datetime_t 	null,
    e_la 		gps_t 		null,
    e_lo 		gps_t 		null,
    e_sat_dt 		datetime_t 	null,
    extra_info 		note_t 		null,
    docs 		int32_t 	null,
    dev_login 		uid_t 		null,
    zstatus 		varchar(8) 	null check(zstatus in ('accepted','rejected') and zstatus = lower(zstatus)),
    znote 		note_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    guid 		uuid 		not null default uuid_generate_v4(),
    primary key (user_id, account_id, activity_type_id, w_cookie, a_cookie)
);

create index i_dates_j_user_activities on j_user_activities(b_dt, e_dt);
create index i_route_date_j_user_activities on j_user_activities(route_date);
create index i_user_id_j_user_activities on j_user_activities (user_id);
create index i_fix_date_j_user_activities on j_user_activities (fix_date);
create index i_daily_j_user_activities on j_user_activities (user_id, fix_date); /* especially for getting daily data */
create index i_guid_j_user_activities on j_user_activities (guid);
create index i_2lts_j_user_activities on j_user_activities (updated_ts);

create trigger trig_updated_ts before update on j_user_activities for each row execute procedure tf_updated_ts();

create table j_user_joints (
    user_id 		uid_t 		not null,
    employee_id 	uid_t 		not null,
    w_cookie 		uid_t 		not null,
    c_cookie 		uid_t 		not null,
    fix_date 		date_t 		null,
    b_dt 		datetime_t 	null,
    b_la 		gps_t 		null,
    b_lo 		gps_t 		null,
    b_sat_dt 		datetime_t 	null,
    e_dt 		datetime_t 	null,
    e_la 		gps_t 		null,
    e_lo 		gps_t 		null,
    e_sat_dt 		datetime_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key (user_id, employee_id, w_cookie, c_cookie)
);

create index i_user_id_j_user_joints on j_user_joints (user_id);
create index i_fix_date_j_user_joints on j_user_joints (fix_date);
create index i_daily_j_user_joints on j_user_joints (user_id, fix_date); /* especially for getting daily data */

create trigger trig_updated_ts before update on j_user_joints for each row execute procedure tf_updated_ts();

create table j_user_works (
    user_id 		uid_t 		not null,
    w_cookie 		uid_t 		not null,
    fix_date 		date_t 		null,
    b_dt 		datetime_t 	null,
    b_la 		gps_t 		null,
    b_lo 		gps_t 		null,
    b_sat_dt 		datetime_t 	null,
    e_dt 		datetime_t 	null,
    e_la 		gps_t 		null,
    e_lo 		gps_t 		null,
    e_sat_dt 		datetime_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key (user_id, w_cookie)
);

create index i_user_id_j_user_works on j_user_works (user_id);
create index i_fix_date_j_user_works on j_user_works (fix_date);
create index i_daily_j_user_works on j_user_works (user_id, fix_date); /* especially for getting daily data */
create index i_2lts_j_user_works on j_user_works (updated_ts);

create trigger trig_updated_ts before update on j_user_works for each row execute procedure tf_updated_ts();

create table j_wishes (
    account_id  	uid_t 		not null,
    user_id		uid_t 		not null,
    fix_dt		datetime_t 	not null,
    weeks 		smallint[] 	not null default array[0,0,0,0] check (array_length(weeks,1)=4),
    days 		smallint[] 	not null default array[0,0,0,0,0,0,0] check (array_length(days,1)=7),
    note		note_t		null,
    validator_id 	uid_t		null,
    validated 		bool_t 		not null default 0,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    attrs 		hstore 		null
    primary key(user_id, account_id)
);

create index i_user_id_j_wishes on j_wishes (user_id);

create trigger trig_updated_ts before update on j_wishes for each row execute procedure tf_updated_ts();


-- *** Streams (for omobusd daemons)

create table blob_stream ( /* blob packages, that imported to the storage */
    s_id 		varchar(256) 	not null primary key,
    blob_id 		blob_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on blob_stream for each row execute procedure tf_updated_ts();

create table celltower_stream (
    mcc 		int32_t 	not null, /* mobile country code */
    mnc 		int32_t 	not null, /* mobile network code */
    cid 		int32_t 	not null, /* cell tower ID */
    lac 		int32_t 	not null, /* local area code */
    inserted_ts 	ts_auto_t 	not null,
    data_ts 		ts_auto_t 	not null,
    content_ts 		ts_t 		null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    changeable 		bool_t 		null, /* defines if coordinates of the cell tower are exact (0) or approximate (1). */
    source 		code_t 		null, /* defines source of the cell tower coordinates */
    primary key(mcc, mnc, cid, lac)
);

create table content_stream (
    user_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    content_ts 		ts_t 		null,
    content_code 	code_t 		not null,
    content_type 	varchar(32) 	null,
    content_compress 	varchar(6) 	null,
    content_blob 	blob_t 		null,
    rows 		int32_t 	null,
    primary key (user_id, b_date, e_date, content_code)
);

create table "content_stream.ghost" (
    user_id 		uid_t 		not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    content_code 	code_t 		not null,
    data_ts 		ts_auto_t 	not null,
    primary key (user_id, b_date, e_date, content_code)
);

create index i_content_code_content_stream on content_stream (content_code);

create or replace function content_add(_content_code code_t, _user_id uid_t, _b_date date_t, _e_date date_t) returns int
as $BODY$
begin
    if( (select count(*) from content_stream where user_id = _user_id and b_date = _b_date and e_date = _e_date and content_code = _content_code) = 0 ) then
	insert into content_stream(user_id, b_date, e_date, content_code)
	    values(_user_id, _b_date, _e_date, _content_code)
	on conflict do nothing;
    end if;
    insert into "content_stream.ghost"(user_id, b_date, e_date, content_code)
	values(_user_id, _b_date, _e_date, _content_code)
    on conflict on constraint "content_stream.ghost_pkey" do update set data_ts = current_timestamp;

    return 1;
end;
$BODY$ language plpgsql;

create or replace function content_add(_content_code code_t, _user_id uid_t, _b_date date, _e_date date) returns int
as $BODY$
begin
    return content_add(_content_code, _user_id, _b_date::date_t, _e_date::date_t);
end;
$BODY$ language plpgsql;

create or replace function content_update(_content_code code_t, _user_id uid_t, _b_date date_t, _e_date date_t) returns int
as $BODY$
declare
    c int;
begin
    update "content_stream.ghost" set data_ts = current_timestamp
	where user_id = _user_id and b_date = _b_date and e_date = _e_date and content_code = _content_code;
    GET DIAGNOSTICS c = ROW_COUNT;
    return c;
end;
$BODY$ language plpgsql;

create or replace function content_update(_content_code code_t, _user_id uid_t, _b_date date, _e_date date) returns int
as $BODY$
begin
    return content_update(_content_code, _user_id, _b_date::date_t, _e_date::date_t);
end;
$BODY$ language plpgsql;

create or replace function content_get(_content_code code_t, _user_id uid_t, _b_date date_t, _e_date date_t) returns table(
    content_ts ts_t,
    content_type VARCHAR(32),
    content_compress VARCHAR(6),
    content_blob blob_t
) as $BODY$
    select content_ts, content_type, content_compress, content_blob from content_stream
	where content_ts is not null and content_blob is not null and user_id=_user_id and b_date=_b_date and e_date=_e_date and content_code=_content_code;
$BODY$ language sql STABLE;

create or replace function content_get(_content_code code_t, _user_id uid_t, _b_date date, _e_date date) returns table(
    content_ts ts_t,
    content_type VARCHAR(32),
    content_compress VARCHAR(6),
    content_blob blob_t
) as $BODY$
    select content_ts, content_type, content_compress, content_blob from content_stream
	where content_ts is not null and content_blob is not null and user_id=_user_id and b_date=_b_date::date_t and e_date=_e_date::date_t and content_code=_content_code;
$BODY$ language sql STABLE;


create table data_stream ( /* data streams, that imported to the stogage */
    s_id 		varchar(256) 	not null primary key,
    digest 		varchar(32) 	not null,
    inserted_ts 	ts_auto_t 	not null,
    inserted_node	hostname_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on data_stream for each row execute procedure tf_updated_ts();

create or replace function stor_blob_stream(p_id varchar(256), b_id blob_t, hostname hostname_t) returns void
as $BODY$
begin
    if( (select count(*) from blob_stream where s_id=p_id) > 0 ) then
	update blob_stream set blob_id=b_id, inserted_node=hostname
	    where s_id=p_id;
    else
	insert into blob_stream(s_id, blob_id, inserted_node)
	    values(p_id, b_id, hostname);
    end if;
end;
$BODY$ language plpgsql;

create or replace function resolve_blob_stream(p_id varchar(256)) returns blob_t
as $BODY$
begin
    return (select blob_id from blob_stream where s_id=p_id);
end;
$BODY$ language plpgsql;

create or replace function stor_data_stream(p_id varchar(256), p_digest varchar(32), hostname hostname_t) returns void
as $BODY$
begin
    if( (select count(*) from data_stream where s_id=p_id) > 0 ) then
	update data_stream set digest=p_digest, inserted_node=hostname 
	    where s_id=p_id;
    else
	insert into data_stream(s_id, digest, inserted_node)
	    values(p_id, p_digest, hostname);
    end if;
end;
$BODY$ language plpgsql;


create table geocode_stream (
    account_id 		uid_t 		not null,
    reverse 		bool_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    content_ts 		ts_t 		null,
    address 		address_t 	null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    /* extra geocode results */
    "x-country" 	descr_t 	null,
    "x-region" 		descr_t 	null,
    "x-area" 		descr_t 	null,
    "x-city" 		descr_t 	null,
    "x-street" 		descr_t 	null,
    "x-house" 		code_t 		null,
    "x-address" 	address_t 	null,
    primary key (account_id, reverse)
);

create or replace function tf_forward_geocoding() returns trigger
as $BODY$
declare
    c int;
    x address_t;
begin
    x := (select array_to_string(array_agg(trim(z)),', ') from unnest(string_to_array(trim((string_to_array(trim(new.address),'('))[1]), ',')) z where trim(z)<>'');

    if( new.latitude is null or new.longitude is null or (new.latitude = 0 and new.longitude = 0) ) then
	if( TG_OP = 'UPDATE') then
	    /* geocode changed address: */
	    if( ltrim(rtrim(old.address)) <> ltrim(rtrim(new.address)) and new.ftype = 0 ) then 
		delete from geocode_stream where account_id=new.account_id;
		if( new.address is not null and ltrim(rtrim(new.address)) <> '' and x <> '' ) then
		    insert into geocode_stream (account_id, reverse, address) 
			values (new.account_id, 0, x);
		end if;
		update accounts set latitude = null, longitude = null where account_id=new.account_id;
	    end if;
	else
	    delete from geocode_stream where account_id=new.account_id;
	    /* geocode new address: */
	    if( new.account_id is not null and new.ftype = 0 and new.address is not null and ltrim(rtrim(new.address))<>'' and x <> '' ) then
		if( new.latitude is null or new.longitude is null or (new.latitude=0 and new.longitude=0) ) then
		    insert into geocode_stream (account_id, reverse, address) 
			values (new.account_id, 0, x);
		else
		    insert into geocode_stream (account_id, reverse, latitude, longitude, address) 
			values (new.account_id, 1, new.latitude, new.longitude, x);
		end if;
	    end if;
	end if;
    end if;
    return null;
end;
$BODY$ language plpgsql;

create trigger trig_geocode after insert or update on accounts for each row 
    execute procedure tf_forward_geocoding();

create table health_stream (
    db_id 		uid_t 		not null primary key,
    health 		ts_t 		not null,
    alarm 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create trigger trig_updated_ts before update on health_stream for each row execute procedure tf_updated_ts();

create or replace function "LTS_aging_L"() returns ts_t
as $body$
declare
    x ts_t;
    a ts_t = current_timestamp;
begin
    select min(health) from health_stream into x;
    return case when x is null then ("monthDate_First"(current_date - "paramInteger"('gc:keep_alive'::uid_t)))::ts_t else x end;
end;
$body$ language plpgsql STABLE;

create or replace function "LTS_aging_R"() returns ts_t
as $body$
declare
    x ts_t;
    a ts_t = current_timestamp;
    d interval = '12:00:00'::interval;
begin
    select min(health) from health_stream into x;
    return case when x is null then ("monthDate_First"(current_date - "paramInteger"('gc:keep_alive'::uid_t)))::ts_t + d when (a - x) > d then x + d else a end;
end;
$body$ language plpgsql STABLE;


create table mail_stream (
    ev_id		int64_t		not null primary key default nextval('seq_mail_stream'),
    mail_from		email_t 	null,
    rcpt_to		emails_t	not null,
    cap			varchar(512) 	not null,
    msg			varchar(32768)	not null,
    priority		INT2 		not null default 3 check (priority between 1 and 5),
    content		varchar(16)	not null default 'text/plain',
    return_receipt 	bool_t 		not null default 0,
    attachment 		blob_t 		null,
    filename 		varchar(128) 	null,
    step		int32_t 	not null default 0,
    inserted_ts		ts_auto_t 	not null,
    sent_ts		ts_t 		null,
    msg_id 		email_t 	null
);

create index i_sent_ts_step_mail_stream on mail_stream (step, sent_ts);

create or replace function evmail_add(rcpt_to emails_t, lang lang_t, l10n_cap uid_t, l10n_body uid_t, priority smallint, ar text[]) returns bool_t
as $body$
declare
    rc int default 0;
    msg_body varchar(4096);
    msg_cap varchar(512);
begin
    if lang is null then
	lang := "paramUID"('lang');
    end if;

    if( rcpt_to is not null and array_length(rcpt_to, 1) > 0 ) then
	msg_cap  := "L10n_format_a"(lang, 'evmail', '', l10n_cap, ar);
	msg_body := "L10n_format_a"(lang, 'evmail', '', l10n_body, ar);

	if( msg_cap is not null and msg_body is not null ) then
	    insert into mail_stream (rcpt_to, cap, msg, content, priority)
		values (rcpt_to, msg_cap, msg_body, case when lower(left(msg_body,5))='<html' then 'text/html' else 'text/plain' end, priority);
	    rc := 1;
	end if;
    end if;

    return rc;
end;
$body$ language plpgsql;

create or replace function evmail_add(x_user_id uid_t, l10n_cap uid_t, l10n_body uid_t, priority smallint, ar text[]) returns bool_t
as $body$
declare
    rcpt_to emails_t;
    u_lang lang_t;
begin
    select evaddrs, lang_id from users where user_id=x_user_id
	into rcpt_to, u_lang;
    return evmail_add(rcpt_to, u_lang, l10n_cap, l10n_body, priority, ar);
end;
$body$ language plpgsql;


create table mileage_stream (
    user_id 		uid_t 		not null,
    fix_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    content_ts 		ts_t 		null,
    data 		hstore 		null,
    primary key (user_id, fix_date)
);

create table "mileage_stream.ghost" (
    user_id 		uid_t 		not null,
    fix_date 		date_t 		not null,
    data_ts 		ts_auto_t 	not null,
    primary key (user_id, fix_date)
);

create or replace function mileage_add(_user_id uid_t, _fix_date date_t) returns int
as $BODY$
begin
    if( (select count(*) from mileage_stream where user_id=_user_id and fix_date=_fix_date) = 0 ) then
	insert into mileage_stream(user_id, fix_date)
	    values(_user_id, _fix_date)
	on conflict do nothing;
    end if;
    insert into "mileage_stream.ghost"(user_id, fix_date)
	values(_user_id, _fix_date)
    on conflict on constraint "mileage_stream.ghost_pkey" do update set data_ts = current_timestamp;

    return 1;
end;
$BODY$ language plpgsql;

create or replace function mileage_add(_user_id uid_t, _fix_date date) returns int
as $BODY$
begin
    return mileage_add(_user_id, _fix_date::date_t);
end;
$BODY$ language plpgsql;

create or replace function mileage_update(_user_id uid_t, _fix_date date_t) returns int
as $BODY$
declare
    c int;
begin
    update "mileage_stream.ghost" set data_ts = current_timestamp
	where user_id = _user_id and fix_date = _fix_date;
    GET DIAGNOSTICS c = ROW_COUNT;
    return c;
end;
$BODY$ language plpgsql;

create or replace function mileage_update(_user_id uid_t, _fix_date date) returns int
as $BODY$
begin
    return mileage_update(_user_id, _fix_date::date_t);
end;
$BODY$ language plpgsql;

create or replace function mileage_calc(uid uid_t, d date_t, b_time time_t, e_time time_t) returns int32_t
as $BODY$
declare
    la gps_t default 0;
    lo gps_t default 0;
    la0 gps_t default 0;
    lo0 gps_t default 0;
    dist int32_t default 0;
    tmp int32_t;
begin
    for la, lo in 
	select latitude, longitude from (
	    select latitude, longitude, fix_dt from a_gps_trace
		where user_id=uid and left(fix_dt,10)=d and (latitude <> 0 or longitude <> 0 ) 
		    and (b_time is null or b_time <= substring(fix_dt, 12, 5)) and (e_time is null or substring(fix_dt, 12, 5) <= e_time) 
		union
	    select latitude, longitude, fix_dt from a_gps_pos
		where user_id=uid and left(fix_dt,10)=d and (latitude <> 0 or longitude <> 0 ) 
		    and (b_time is null or b_time <= substring(fix_dt, 12, 5)) and (e_time is null or substring(fix_dt, 12, 5) <= e_time) 
	) x order by fix_dt
    loop
	if( la0 <> 0 or lo0 <> 0 ) then
	    tmp := distance(la0, lo0, la, lo);
	    if( tmp < 1000000 ) then
		dist := dist + tmp;
	    end if;
	end if;
	la0 := la;
	lo0 := lo;
    end loop;
    return dist;
--exception 
--    when numeric_value_out_of_range then 
--	return -1;
end;
$BODY$ language plpgsql STABLE;

create or replace function mileage_calc(uid uid_t, d date_t) returns int32_t
as $BODY$
begin
    return mileage_calc(uid, d, null, null);
end;
$BODY$ language plpgsql STABLE;

create or replace function mileage_get(_user_id uid_t, _fix_date date_t, _b_time time_t, _e_time time_t) returns int32_t
as $BODY$
declare 
    x int32_t;
    f timestamp;
begin
    select (data->(trim(format('%s %s',coalesce(_b_time,''),coalesce(_e_time,'')))))::int32_t, content_ts from mileage_stream 
	where user_id = _user_id and fix_date = _fix_date
    into x, f;
    if x is null then
	x := mileage_calc(_user_id, _fix_date, _b_time, _e_time);
	if x > 0 and (f is null or (current_timestamp > f and (current_timestamp - f) > '00:55:00'::interval)) then
	    if _b_time is null and _e_time is null then
		raise notice '[mileage_stream] does not contain data for user_id=%, fix_date=%.',
		    _user_id, _fix_date;
	    else
		raise notice '[mileage_stream] does not contain data for user_id=%, fix_date=%, b_time=%, e_time=%.',
		    _user_id, _fix_date, _b_time, _e_time;
	    end if;
	end if;
    end if;
    return x;
end;
$BODY$ language plpgsql STABLE;

create or replace function mileage_get(_user_id uid_t, _fix_date date, _b_time time_t, _e_time time_t) returns int32_t
as $BODY$
begin
    return mileage_get(_user_id, _fix_date, _b_time, _e_time);
end;
$BODY$ language plpgsql STABLE;

create or replace function mileage_get(_user_id uid_t, _fix_date date_t) returns int32_t
as $BODY$
begin
    return mileage_get(_user_id, _fix_date, null, null);
end;
$BODY$ language plpgsql STABLE;

create or replace function mileage_get(_user_id uid_t, _fix_date date) returns int32_t
as $BODY$
begin
    return mileage_get(_user_id, _fix_date, null, null);
end;
$BODY$ language plpgsql STABLE;


create table pt_stream (
    doc_id 		uid_t		not null primary key,
    photo 		blob_t 		not null,
    inserted_ts		ts_auto_t 	not null,
    prod_id 		uid_t 		null,
    price 		currency_t 	null,
    promo 		bool_t 		null,
    plu_code 		code_t 		null,
    name 		descr_t 	null,
    art 		code_t 		null,
    barcode 		ean13 		null,
    processing_ts 	ts_t 		null
);

create table thumbnail_stream (
    photo 		blob_t 		not null primary key,
    thumb 		blob_t 		null,
    thumb_width 	int32_t 	null check(thumb_width > 0),
    thumb_height 	int32_t 	null check(thumb_height > 0),
    thumb800 		blob_t 		null,
    thumb800_width 	int32_t 	null check(thumb_width > 0),
    thumb800_height 	int32_t 	null check(thumb_height > 0),
    guid 		uuid 		not null default uuid_generate_v4(),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null
);

create unique index i_guid_thumbnail_stream on thumbnail_stream using btree (guid);
create index i_2lts_thumbnail_stream on thumbnail_stream (updated_ts);

create trigger trig_updated_ts before update on thumbnail_stream for each row execute procedure tf_updated_ts();



-- *** other helper functions

create or replace function expand_accounts(account_ids uids_t, region_ids uids_t, city_ids uids_t, rc_ids uids_t, chan_ids uids_t, poten_ids uids_t)
    returns setof uid_t as
$BODY$
declare
    r uid_t;
begin
    for r in select account_id from accounts where hidden=0 
	/* if all parameters is null, nothing to return: */
	and not (account_ids is null and region_ids is null and city_ids is null and rc_ids is null and chan_ids is null and poten_ids is null)
	/* filters: */
	and (
	    (account_ids is not null and account_id=any(account_ids))
	    or ( 
		not (region_ids is null and city_ids is null and rc_ids is null and chan_ids is null and poten_ids is null)
		and (region_ids is null or region_id=any(region_ids))
		and (city_ids is null or city_id=any(city_ids))
		and (rc_ids is null or rc_id=any(rc_ids))
		and (chan_ids is null or chan_id=any(chan_ids))
		and (poten_ids is null or poten_id=any(poten_ids))
	    )
	)
    loop
	return next r; -- return current row of select
    end loop;
end;
$BODY$ language plpgsql STABLE;


create or replace function expand_cities(c_id uid_t, root bool_t = 1::bool_t) returns setof uid_t
as $body$
declare
   c uid_t;
   x uid_t;
begin
    if( root = 1 ) then
	return next c_id; -- return current row of select
    end if;

    for c in select city_id from cities where pid=c_id and hidden = 0
    loop
	return next c; -- return current row of select
	
	for x in select * from expand_cities(c, 0::bool_t)
	loop
	    return next x; -- return current row of select
	end loop;
    end loop;
end;
$body$ language plpgsql STABLE;


create or replace function my_head(my_id uid_t, head_role code_t) returns uid_t
as $body$
declare
    a uid_t;
    b code_t;
    z uids_t;
begin
    select pids from users where user_id=my_id 
	into z;
    if( z is null or array_length(z, 1) is null or array_length(z, 1) = 0 ) then
	return null;
    end if;

    select user_id, role from users where user_id=z[1]
	into a, b;
    if( a is null ) then
	return null;
    end if;

    if( head_role is null or b = head_role ) then 
	return a; 
    end if;

    return my_head(a, head_role);
end;
$body$ language plpgsql STABLE;


create or replace function my_head(my_id uid_t) returns uid_t
as $body$
begin
    return my_head(my_id, null::code_t);
end;
$body$ language plpgsql STABLE;


create or replace function my_executivehead(my_id uid_t) returns uid_t
as $body$
begin
    return my_head(my_id, "paramUID"('executive_head'::uid_t)::code_t);
end;
$body$ language plpgsql STABLE;


create type my_routes_t as (
    user_id uid_t,
    account_id uid_t,
    activity_type_id uid_t,
    p_date date_t,
    allow_discard bool_t,
    allow_pending bool_t,
    pending_date date_t,
    color int32_t,
    bgcolor int32_t,
    extra_info note_t,
    row_no int32_t,
    duration int32_t,
    "z-index" smallint
);

create or replace function my_routes() returns setof my_routes_t
as $body$
declare
    row my_routes_t;
    index date;
    start_date date;	/* First route date */
    offsetL int32_t = "paramInteger"('my_routes:offset:left');
    offsetR int32_t = "paramInteger"('my_routes:offset:right');
    pen_depth int32_t = "paramInteger"('my_routes:pending:depth');
    pen_color int32_t = "paramInteger"('my_routes:pending:color');
    pen_bgcolor int32_t = "paramInteger"('my_routes:pending:bgcolor');
    imp_bgcolor int32_t = "paramInteger"('my_routes:important:bgcolor');
    imp_depth int32_t = "paramInteger"('my_routes:important:depth');
    d bool_t = "paramBoolean"('my_routes:discard');
begin
    start_date = current_date;
    index = start_date + offsetL;

    /*** Step 1: pending activities ***/
    while  index <= start_date + offsetR loop
	for row in 
	    select
		h.user_id, h.account_id, h.activity_type_id, index p_date, 0 allow_discard, 0 allow_pending, h.route_date pending_date, pen_color color, 
		pen_bgcolor bgcolor, "L10n_format_a"(u.lang_id, 'my_routes', '',
		    case 
			when next_date is null and max_date = index then 'pending/today'
			when next_date is not null and next_date > max_date and max_date = index then 'pending/today'
			when next_date is not null and next_date <= max_date and (next_date-1) = index then 'pending/today'
			else 'pending' 
		    end, array['e_date',"L"((case when next_date is null or next_date > max_date then max_date else next_date-1 end)::date_t)])
		extra_info, null row_no, z.duration, 2 "z-index"
	    from (
		select 
		    x.user_id, x.account_id, x.activity_type_id, x.route_date, x.route_date::date + pen_depth max_date,
		    (select p_date::date from my_routes where x.account_id=account_id and x.user_id=user_id and p_date > index::date_t order by p_date limit 1) next_date
		from h_pending x
		where (index - pen_depth)::date_t <= x.route_date and x.route_date < index::date_t
	    ) h
		left join (
		    select r.user_id, r.account_id, max(r.p_date) p_date, max(r.duration) duration from my_routes r
			where index - pen_depth <= r.p_date::date and r.p_date::date <= index
		    group by 1, 2
		) r on h.user_id = r.user_id and h.account_id = r.account_id and h.route_date < r.p_date
		left join (
		    select route_date, user_id, account_id, b_dt fix_dt from j_user_activities 
			where b_dt is not null and e_dt is not null and route_date is not null and index - pen_depth <= fix_date::date and fix_date::date <= index
		) a on h.user_id = a.user_id and h.account_id = a.account_id and a.route_date = h.route_date
		left join users u on u.user_id=h.user_id
		left join my_routes z on z.user_id=h.user_id and z.account_id=h.account_id and z.p_date=h.route_date
	    where index - pen_depth <= h.route_date::date and h.route_date::date < index and a.fix_dt is null and r.p_date is null
	loop
	    return next row; -- return current row of select
	end loop;

	index = index + 1;
    end loop;

    /*** Step 2: moves routes from day to day (single user) ***/
    for row in select
	r.user_id, r.account_id, r.activity_type_id, mv.t_date p_date, 0 allow_discard, 0 allow_pending, r.p_date pending_date, pen_color color, 
	pen_bgcolor bgcolor, null extra_info, null row_no, r.duration, 1 "z-index"
    from my_routes r
	left join routemv mv on mv.user_id = r.user_id and mv.f_date = r.p_date
    where start_date - offsetR <= cast(mv.t_date as date) and cast(mv.t_date as date) <= start_date + offsetR and mv.user_id is not null
	and (select count(*) from j_user_activities j where j.user_id=r.user_id and j.account_id=r.account_id and j.route_date=mv.f_date and j.b_dt is not null and j.e_dt is not null and left(j.b_dt, 10) <> mv.t_date)=0
    loop
	return next row; -- return current row of select
    end loop;

    /*** Step 3: urgent activities ***/
    index = start_date + offsetL;
    while index <= start_date + offsetR loop
	for row in 
	    select
		x.user_id, x.account_id, x.activity_type_id, index p_date, 0 allow_discard, 0 allow_pending, case when x.p_date::date = index then null else x.p_date end pending_date, 
		null color, case when t.important=1 then imp_bgcolor else null end bgcolor, x.extra_info, null row_no, null duration, 5 "z-index"
	    from urgent_activities x
		left join activity_types t on x.activity_type_id = t.activity_type_id
		left join (
		    select r.user_id, r.account_id, max(r.p_date) p_date from my_routes r
			where index - imp_depth <= r.p_date::date and r.p_date::date <= index
		    group by 1, 2
		) r on x.user_id = r.user_id and x.account_id = r.account_id and x.p_date < r.p_date
		left join (
		    select route_date, user_id, account_id, b_dt fix_dt from j_user_activities
			where b_dt is not null and e_dt is not null and route_date is not null and index - imp_depth <= fix_date::date and fix_date::date <= index
		) a on x.user_id = a.user_id and x.account_id = a.account_id and a.route_date = x.p_date
	    where ((t.important=1 and index - imp_depth < x.p_date::date and x.p_date::date <= index) or (t.important=0 and index = x.p_date::date)) 
		and a.fix_dt is null and r.p_date is null
	loop
	    return next row; -- return current row of select
	end loop;

	index = index + 1;
    end loop;

    /*** Step 4: moves work days (single country) ***/
    for row in select
	r.user_id, r.account_id, r.activity_type_id, mv.t_date p_date, 0 allow_discard, 0 allow_pending, r.p_date pending_date, null color, null bgcolor, 
	null extra_info, r.row_no, r.duration, 8 "z-index"
    from my_routes r
	left join syswdmv mv on mv.f_date = r.p_date and (select count(*) from users u where u.user_id=r.user_id and mv.country_id = u.country_id) > 0
    where start_date + offsetL <= mv.t_date::date and mv.t_date::date <= start_date + offsetR
	and (select count(*) from j_user_activities j where j.user_id=r.user_id and j.account_id=r.account_id and j.route_date=mv.f_date and j.b_dt is not null and j.e_dt is not null and j.fix_date/*left(j.b_dt, 10)*/ <> mv.t_date)=0
    loop
	return next row; -- return current row of select
    end loop;

    /*** Step 5: regular routes (MAXimal priority) ***/
    for row in select 
	user_id, account_id, activity_type_id, p_date, d allow_discard, 1 allow_pending, null pending_date, null color, null bgcolor, null extra_info, 
	row_no, duration, 9 "z-index"
    from my_routes
	where start_date + offsetL <= p_date::date and p_date::date <= start_date + offsetR
    loop
	return next row; -- return current row of select
    end loop;
end;
$body$ language plpgsql;


create or replace function my_staff(my_id uid_t, root bool_t, _ar uids_t) returns setof uid_t
as $body$
declare
   u uid_t;
   x uid_t;
begin
    if( root > 0 and (_ar is null or not(my_id = any(_ar))) ) then
	_ar := array_append(_ar::text[], my_id::text);
	return next my_id;
    end if;

    for u in select user_id from users where my_id = any(pids) /*and hidden = 0*/
    loop
	if u = any(_ar) then
	    --raise notice '% already added to the hierarchy at %.', u, my_id;
	    continue;
	end if;

	_ar := array_append(_ar::text[], u::text);
	return next u; -- return current row of select
	
	for x in select my_staff from my_staff(u, 0::bool_t, _ar)
	loop
	    _ar := array_append(_ar::text[], x::text); 
	    return next x; -- return current row of select
	end loop;
    end loop;
end;
$body$ language plpgsql STABLE;


create or replace function my_staff(my_id uid_t, root bool_t) returns setof uid_t
as $body$
begin
    return query select my_staff(my_id, root, null::uids_t);
end;
$body$ language plpgsql STABLE;

create or replace function photo_get(blob_id blob_t) returns blob_t
as $body$
declare
    x blob_t;
begin
    select photo from thumbnail_stream where photo=blob_id 
	into x;
    return x;
end;
$body$ language plpgsql;

create or replace function photo_get(g uuid) returns blob_t
as $body$
declare
    x blob_t;
begin
    select photo from thumbnail_stream where guid=g
	into x;
    return x;
end;
$body$ language plpgsql;

create or replace function quest_path(f_descr text, f_qname_id uid_t, f_pid uid_t) returns text
as $$
declare
    x text;
    z uid_t;
begin
    if( f_qname_id is null or f_pid is null ) then
	return f_descr;
    else 
	select descr, pid from quest_rows where qname_id=f_qname_id and qrow_id=f_pid and ftype=1 into x, z;
	return quest_path(case when f_descr is not null and f_descr <> '' then (f_descr || ', ') else '' end || coalesce(x,''), f_qname_id, z);
    end if;
end;
$$
language plpgsql;

create or replace function thumb_get(blob_id blob_t) returns blob_t
as $body$
declare
    x blob_t;
begin
    select case when thumb is null then photo else thumb end from thumbnail_stream where photo=blob_id 
	into x;
    return x;
end;
$body$ language plpgsql;

create or replace function thumb_get(g uuid) returns blob_t
as $body$
declare
    x blob_t;
begin
    select case when thumb is null then photo else thumb end from thumbnail_stream where guid=g
	into x;
    return x;
end;
$body$ language plpgsql;


create or replace function urgent_add(x_user_id uid_t, x_account_id uid_t, x_activity_type_id uid_t, x_p_date date_t, x_author_id uid_t, x_extra note_t) returns bool_t
as $body$
declare
    rc int default 0;
begin
    if( (select count(*) from urgent_activities where user_id=x_user_id and account_id=x_account_id and activity_type_id=x_activity_type_id and p_date=x_p_date) = 0 ) then
	insert into urgent_activities(user_id, account_id, activity_type_id, p_date, author_id, extra_info)
	    values(x_user_id, x_account_id, x_activity_type_id, x_p_date, x_author_id, x_extra);
	rc := 1;
    end if;
    return rc;
end;
$body$ language plpgsql;


create or replace function user_routes(f_user_id uid_t, f_b_date date_t, f_e_date date_t, f_pending bool_t) returns table (
    user_id uid_t,
    route_date date_t,
    row_no int32_t,
    route bool_t,
    closed bool_t,
    canceled bool_t,
    discarded bool_t,
    pending bool_t,
    account_id uid_t,
    b_dt datetime_t,
    e_dt datetime_t,
    satellite_dt datetime_t,
    latitude gps_t,
    longitude gps_t,
    latitude_e gps_t,
    longitude_e gps_t,
    activity_type_id uid_t,
    a_cookie uid_t,
    extra_info note_t,
    docs int32_t,
    canceling_type_id uid_t,
    canceling_note note_t,
    discard_type_id uid_t,
    discard_note note_t,
    pending_type_id uid_t,
    pending_note note_t,
    zstatus text,
    znote note_t,
    guid uuid
    )
as $body$
    select
	user_id, 
	route_date, 
	null::int32_t row_no, 
	null::bool_t route, 
	case when b_dt is null or e_dt is null then null::bool_t else 1::bool_t end closed,
	null::bool_t canceled, 
	null::bool_t discarded, 
	null::bool_t pending,
	account_id, 
	b_dt, 
	e_dt, 
	b_sat_dt satellite_dt, 
	b_la latitude, 
	b_lo longitude, 
	e_la latitude_e, 
	e_lo longitude_e, 
	activity_type_id, 
	a_cookie,
	extra_info,
	docs,
	null::uid_t canceling_type_id, 
	null::note_t canceling_note, 
	null::uid_t discard_type_id, 
	null::note_t discard_note,
	null::uid_t pending_type_id, 
	null::note_t pending_note, 
	zstatus, 
	znote, 
	guid
    from j_user_activities
	where (f_user_id is null or user_id=f_user_id) and fix_date>=f_b_date and fix_date<=f_e_date and 
	    (route_date is null or route_date='' or (f_pending = 1::bool_t and route_date<>fix_date))
union
    select
	r.user_id, 
	r.p_date route_date, 
	r.row_no, 
	1::bool_t route, 
	case when v.b_dt is null or v.e_dt is null then null::bool_t else 1::bool_t end closed,
	case when c.hidden is null and s.h_date is null then null::bool_t else 1::bool_t end canceled,
	case when d.hidden is null then null::bool_t else 1::bool_t end discarded,
	case when p.hidden is null then null::bool_t else 1::bool_t end pending,
	r.account_id, 
	v.b_dt, 
	v.e_dt, 
	v.b_sat_dt satellite_dt, 
	v.b_la latitude, 
	v.b_lo longitude, 
	v.e_la latitude_e, 
	v.e_lo longitude_e, 
	r.activity_type_id, 
	v.a_cookie,
	v.extra_info,
	v.docs,
	case when s.h_date is not null then null::uid_t else c.canceling_type_id end canceling_type_id,
	case when s.h_date is not null then s.descr::note_t else c.note::note_t end canceling_note,
	d.discard_type_id, 
	d.note discard_note,
	p.pending_type_id, 
	p.note pending_note, 
	v.zstatus, 
	v.znote,
	v.guid
    from my_routes r
	left join j_user_activities v on v.user_id = r.user_id and v.account_id = r.account_id
	    and v.activity_type_id = r.activity_type_id and v.route_date = r.p_date
	left join j_cancellations c on c.user_id = r.user_id and c.route_date = r.p_date and c.hidden = 0
	left join j_discards d on d.user_id = r.user_id and d.account_id = r.account_id and d.activity_type_id = r.activity_type_id and d.route_date = r.p_date and d.hidden = 0 and d.validated = 1
	left join j_pending p on p.user_id = r.user_id and p.account_id = r.account_id and p.activity_type_id = r.activity_type_id and p.route_date = r.p_date and p.hidden = 0
	left join users u on u.user_id = r.user_id
	left join sysholidays s on s.h_date = r.p_date and s.country_id = u.country_id and s.hidden = 0
    where r.p_date>=f_b_date and r.p_date<=f_e_date and (f_user_id is null or r.user_id=f_user_id)
union /* orphaned routes: */
    select
	j.user_id,
	j.route_date,
	null::int32_t row_no,
	null::bool_t route,
	case when j.b_dt is null or j.e_dt is null then null::bool_t else 1::bool_t end closed,
	null::bool_t canceled,
	null::bool_t discarded,
	null::bool_t pending,
	j.account_id,
	j.b_dt,
	j.e_dt,
	j.b_sat_dt satellite_dt,
	j.b_la latitude,
	j.b_lo longitude,
	j.e_la latitude_e,
	j.e_lo longitude_e,
	j.activity_type_id, 
	j.a_cookie,
	j.extra_info,
	j.docs,
	null::uid_t canceling_type_id,
	null::note_t canceling_note,
	null::uid_t discard_type_id,
	null::note_t discard_note,
	null::uid_t pending_type_id,
	null::note_t pending_note,
	j.zstatus,
	j.znote,
	j.guid
    from j_user_activities j
	left join my_routes m on m.user_id=j.user_id and m.account_id=j.account_id and m.p_date=j.route_date and m.activity_type_id=j.activity_type_id
    where (f_user_id is null or j.user_id=f_user_id) and j.route_date>=f_b_date and j.route_date<=f_e_date and
	j.route_date is not null and j.route_date<>'' and m.p_date is null
$body$ language sql STABLE;



-- default system parameters

insert into sysparams values('db:created_ts', current_timestamp, 'Database creation datetime.');
insert into sysparams values('db:id', 'PRI', 'Database unique ID.');
insert into sysparams values('srv:domain', 'omobus.local', 'Server domain name.');
insert into sysparams values('srv:push', '<3874a923-189a-4b95-b65c-b55a3809e35e@push.omobus.net>', 'Server alert notification address.');
insert into sysparams values('gc:keep_alive', '155', 'How many days the data will be hold from cleaning.');
insert into sysparams values('dumps:depth', null, 'Dumps depth (days).');
insert into sysparams values('executive_head', null, 'Executive head role name or null if direct head is executive head. After change it is necessary to execute: [update users set executivehead_id=my_executivehead(user_id) where hidden=0].');
insert into sysparams values('lang', 'ru', 'Default language.');

insert into sysparams values('rules:wdays', '{1,1,1,1,1,0,0}', 'The woking day list as array of flags for each week day starting monday.');
insert into sysparams values('rules:min_duration', '5', 'The minimum duration of the activity (in minutes).');
insert into sysparams values('rules:max_duration', '90', 'The maximum duration of the activity (in minutes).');
insert into sysparams values('rules:max_distance', '200', 'The maximum allowable distance to the account at the start of the activity (in meters).');
insert into sysparams values('rules:wd_begin', '09:30', 'Show warning if the working day begins later than rules:wd_begin.');
insert into sysparams values('rules:wd_end', '17:30', 'Show warning if the working day ends early than rules:wd_end.');
insert into sysparams values('rules:timing', '06:00', 'Minimal route day duration.');
insert into sysparams values('rules:power', '90', 'The minimum power (battery life percentage) at the working day begin.');

insert into sysparams values('checkups:offset', '-30', 'How long (in days) empty data from the dyn_checkups is used.');

insert into sysparams values('advt_history:offset', '-60', 'The maximum depth of the advt_history in days');
insert into sysparams values('oos_history:offset', '-60', 'The maximum depth of the oos_history in days');
insert into sysparams values('photos_history:offset', '-2', 'The maximum depth of the photos_history in days.');
insert into sysparams values('posms_history:offset', '-2', 'The maximum depth of the posms_history in days.');
insert into sysparams values('presences_history:offset', '-60', 'The maximum depth of the presences_history in days');
insert into sysparams values('prices_history:offset', '-60', 'The maximum depth of the prices_history in days.');
insert into sysparams values('quests_history:offset', '-60', 'The maximum depth of the quests_history in days.');
insert into sysparams values('route_history:offset:left', '-10', 'The maximum depth of the route_history in days.');
insert into sysparams values('route_history:offset:right', '5', 'The maximum depth of the route_history right offset in days.');
insert into sysparams values('stocks_history:offset', '-60', 'The maximum depth of the stocks_history in days');
insert into sysparams values('trainings_history:offset', '-60', 'The maximum depth of the trainings_history in days.');

insert into sysparams values('orders_history:offset', '-10', 'The maximum depth of the orders_history in days.');
insert into sysparams values('orders_history:alert:color', '13107200', 'orders_history alert text color as rgb integer.');
insert into sysparams values('orders_history:alert:bgcolor', '16116715', 'orders_history alert bgcolor as rgb integer.');

insert into sysparams values('reclamations_history:offset', '-10', 'The maximum depth of the reclamations_history in days.');
insert into sysparams values('reclamations_history:alert:color', '13107200', 'reclamations_history alert text color as rgb integer.');
insert into sysparams values('reclamations_history:alert:bgcolor', '16116715', 'reclamations_history alert bgcolor as rgb integer.');

insert into sysparams values('my_routes:offset:left', '-1', 'The maximum deph of the my_routes in days.');
insert into sysparams values('my_routes:offset:right', '5', 'my_routes right offset in days.');
insert into sysparams values('my_routes:pending:depth', '7', 'my_routes pending depth in days.');
insert into sysparams values('my_routes:pending:color', '1704061', 'my_routes pending color as rgb integer value.');
insert into sysparams values('my_routes:pending:bgcolor', '15395583', 'my_routes pending bgcolor as rgb integer value.');
insert into sysparams values('my_routes:important:depth', '3', 'my_routes important depth in days.');
insert into sysparams values('my_routes:important:bgcolor', '16773360', 'my_routes important bgcolor as rgb integer value.');
insert into sysparams values('my_routes:discard', 'false', 'allows discarding of the route.');

insert into sysparams values('target:depth', '14', 'default target depth (days).');
insert into sysparams values('target:multi', 'no', 'set to [yes] for allowing more then one target per document.');
