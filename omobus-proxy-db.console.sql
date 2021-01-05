/* Copyright (c) 2006 - 2021 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema console;

create sequence console.seq_requests;

create table console.requests (
    req_id 		uid_t 		not null primary key default nextval('console.seq_requests'),
    req_login 		uid_t 		not null,
    req_type 		code_t 		not null,
    req_dt 		datetime_t 	null,
    status 		code_t 		not null,
    attrs 		hstore 		null,
    inserted_ts 	ts_auto_t 	not null
);

create trigger trig_lock_update before update on console.requests for each row execute procedure tf_lock_update();

create table console.sessions (
    ses_id 		uid_t 		not null primary key,
    ses_ip 		hostname_t 	not null,
    u_name 		uid_t 		not null,
    u_id 		uid_t 		null,
    params 		json 		not null default '{}',
    lifetime 		int32_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    access_ts 		ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    closed 		bool_t 		not null default 0,
    gc 			bool_t 		null
);

create trigger trig_updated_ts before update on console.sessions for each row execute procedure tf_updated_ts();

create or replace function console.ses_create(p json) returns uid_t as
$body$
declare
    sid uid_t;
    erpid uid_t;
    username uid_t;
    ip hostname_t;
    lt int32_t;
begin
    sid := p ->> 'sid';
    erpid := p ->> 'erpid';
    username := p ->> 'username';
    ip := p ->> 'ip';
    lt := p ->> 'lifetime';
    if( sid is null or username is null or ip is null ) then
	sid := null;
    elsif( erpid is not null and (select count(*) from users where user_id=erpid and hidden=0) = 0 ) then
	sid := null;
    else
	insert into console.sessions(ses_id, u_name, u_id, ses_ip, params, lifetime) 
	    values(sid, username, erpid, ip, p, case when lt is null then 600 else lt end);
    end if;
    return sid;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_get(sid uid_t, ip hostname_t, out p json, out "obsolete" bool_t) as
$body$
declare
    x hostname_t;
begin
    select params, ses_ip, case when (extract(epoch from (current_timestamp - access_ts)))::int32_t > lifetime then 1 else 0 end from console.sessions 
	where ses_id = sid and closed = 0 into p, x, "obsolete";
    if( x = ip ) then
	update console.sessions set access_ts=current_timestamp where ses_id = sid and closed = 0;
	if( "obsolete" = 1) then
	    update console.sessions set closed=1 where ses_id = sid and closed = 0;
	end if;
    end if;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_destroy(sid uid_t, ip hostname_t) returns json as
$body$
declare
    p json;
    x hostname_t;
begin
    select params, ses_ip from console.sessions where ses_id = sid and closed = 0 into p, x;
    if( x = ip ) then
	update console.sessions set closed=1 where ses_id = sid and closed = 0;
    end if;
    return p;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_gc() returns table(sid uid_t, ip hostname_t, username uid_t) as
$body$
begin
    for sid, ip, username in
	select ses_id, ses_ip, u_name from console.sessions where closed=0 and (extract(epoch from (current_timestamp - access_ts)))::int32_t > lifetime
    loop
	update console.sessions set closed = 1, gc = 1 where ses_id = sid;
	return next;
    end loop;
end;
$body$
language plpgsql volatile;
