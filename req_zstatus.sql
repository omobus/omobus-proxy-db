/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_zstatus(_login uid_t, _reqdt datetime_t, _cmd code_t, _cookie uuid, _note note_t) 
    returns int
as $BODY$
declare
    stack text;
    fcesig text;
    zrows int;
    hs hstore;
    reqId uid_t;
    u_id uid_t;
    h_id uid_t;
    e_id uid_t;
    p_date date_t;
    f_date date_t;
    locked bool_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    _cmd := lower(_cmd);
    _note := NIL(trim(_note));

    if( _cmd not in ('accept','reject') ) then
	raise exception '% doesn''t support [%] command.', fcesig, _cmd;
    end if;
    if( _cookie is null or (_cmd = 'reject' and _note is null)) then
	raise exception '% invalid input attribute.', fcesig;
    end if;

    if( _cmd = 'accept' ) then
	update j_user_activities set zstatus = 'accepted', znote = _note, zauthor_id = _login, zreq_dt = _reqdt
	    where guid = _cookie and (zstatus is null or zstatus <> 'accepted') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( _cmd = 'reject' ) then
	update j_user_activities set zstatus = 'rejected', znote = _note, zauthor_id = _login, zreq_dt = _reqdt
	    where guid = _cookie and (zstatus is null or zstatus <> 'rejected') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    end if;

    hs := hstore(array['guid',_cookie::varchar]);
    hs := hs || hstore(array['zrows',zrows::varchar]);
    if _note is not null then
	hs := hs || hstore(array['note',_note]);
    end if;

    reqId := nextval('console.seq_requests');
    insert into console.requests(req_id, req_login, req_type, req_dt, status, attrs)
	values(reqId, _login, fcesig, _reqdt, _cmd, hs);

    if( zrows > 0 ) then
	select user_id, route_date, fix_date from j_user_activities where guid = _cookie
	    into u_id, p_date, f_date;
	select hidden from users where user_id = u_id
	    into locked;

	if( u_id is not null and f_date is not null ) then
	    perform content_add('tech_route', u_id, f_date, f_date);
	    perform content_add('route_compliance', '', f_date, f_date);
	    perform content_add('time', '', "monthDate_First"(f_date), "monthDate_Last"(f_date));
	end if;
	if( u_id is not null and p_date is not null and (f_date is null or f_date <> p_date) ) then
	    perform content_add('tech_route', u_id, p_date, p_date);
	    perform content_add('route_compliance', '', p_date, p_date);
	    perform content_add('time', '', "monthDate_First"(p_date), "monthDate_Last"(p_date));
	end if;
	if( u_id is not null and locked = 0 ) then
	    hs := hstore('guid', _cookie::text);
	    hs := hs || hstore('req_id', reqId);
	    if( _cmd = 'accept' ) then
		perform streams.spam_add('zstatus_accepted', hs);
	    elsif( _cmd = 'reject' ) then
		select executivehead_id from users where user_id = u_id and hidden = 0
		    into e_id;
		select pids[1] from users where user_id = u_id and hidden = 0
		    into h_id;

		if( e_id is not null and e_id <> _login ) then
		    perform streams.spam_add('zstatus_notice', hs || hstore('dst_id', e_id));
		end if;
		if( h_id is not null and h_id <> _login and (e_id is null or h_id <> e_id) ) then
		    perform streams.spam_add('zstatus_notice', hs || hstore('dst_id', h_id));
		end if;
		perform streams.spam_add('zstatus_rejected', hs);
	    end if;
	end if;
    end if;

    return zrows;
end;
$BODY$ language plpgsql;
