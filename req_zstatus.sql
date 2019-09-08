/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_zstatus(rlogin uid_t, cmd code_t, cookie uuid, note note_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    zrows int;
    author descr_t;
    u_id uid_t;
    a_name descr_t;
    a_address address_t;
    a_type descr_t;
    p_date date_t;
    f_date date_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    cmd := lower(cmd);
    note := NIL(trim(note));

    if( cmd not in ('accept','reject') ) then
	raise exception '% doesn''t support [%] command.', fcesig, cmd;
    end if;
    if( cookie is null or (cmd = 'reject' and note is null)) then
	raise exception '% invalid input attribute.', fcesig;
    end if;

    if( cmd = 'accept' ) then
	update j_user_activities set zstatus = 'accepted', znote = note
	    where guid = cookie and (zstatus is null or zstatus <> 'accepted') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( cmd = 'reject' ) then
	update j_user_activities set zstatus = 'rejected', znote = note
	    where guid = cookie and (zstatus is null or zstatus <> 'rejected') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    end if;

    if( zrows > 0 ) then
	select j.user_id, a.descr, a.address, t.descr, j.route_date, j.fix_date from j_user_activities j, activity_types t, accounts a
	    where j.guid = cookie and j.account_id = a.account_id and j.activity_type_id = t.activity_type_id
	into u_id, a_name, a_address, a_type, p_date, f_date;

	select descr from users 
	    where user_id = rlogin
	into author;

	if( f_date is not null ) then
	    perform content_add('tech_route', u_id, f_date, f_date);
	end if;
	if( p_date is not null and (f_date is null or f_date <> p_date) ) then
	    perform content_add('tech_route', u_id, p_date, p_date);
	end if;

	perform evmail_add(u_id, format('zstatus/caption:%s', cmd), 
	    format('zstatus/body:%s', case when cmd = 'reject' then cmd else cmd || (case when note is null then '1' else '0' end) end), 
	    case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array['a_name',a_name,'address',a_address,'fix_date',"L"(f_date),'u_name',case when author is null then lower(rlogin) else author end,
		'a_type',lower(a_type),'note',note]);
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['guid',cookie::varchar,'note',note,'zrows',zrows::varchar]));

    return zrows;
end;
$BODY$ language plpgsql;
