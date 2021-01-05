/* Copyright (c) 2006 - 2021 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_schedule(_login uid_t, _reqdt datetime_t, _uid uid_t, _p_date date_t, _num int, _attrs hstore) returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    updated_rows int = 0;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _uid is null or _p_date is null or _num is null or not (1 <= _num and _num <= 4) ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    update schedules set jobs[_num] = coalesce(_attrs, ''::hstore), author_id = _login
	where user_id = _uid and p_date = _p_date and closed = 0 and hidden = 0;
    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    hs := hstore(array['user_id',_uid]);
    hs := hs || hstore(array['p_date',_p_date]);
    hs := hs || hstore(array['num',_num::text]);
    hs := hs || hstore(array['_updated_rows',updated_rows::text]);
    if _attrs is not null then
	hs := hs || _attrs;
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, case when _attrs is null or _attrs = ''::hstore then 'drop' else 'set' end, hs);

    return updated_rows;
end;
$BODY$ language plpgsql;

create or replace function console.req_schedule(_login uid_t, _reqdt datetime_t, _uid uid_t, _p_date date_t, _num int, _attrs text[]) returns int
as $BODY$
declare
    x text;
    k text;
    f smallint = 0;
    hs hstore = ''::hstore;
begin
    for x in select unnest(_attrs)
    loop
	if( f = 0 ) then
	    k := x;
	    f := 1;
	else
	    if( k is not null and trim(k) <> '' and x is not null ) then
		hs := hs || hstore(array[k,x]);
	    end if;
	    f := 0;
	end if;
    end loop;
    return console.req_schedule(_login, _reqdt, _uid, _p_date, _num, hs);
end;
$BODY$ language plpgsql;

create or replace function console.req_schedule(_login uid_t, _reqdt datetime_t, _uid uid_t, _p_date date_t, _num int) returns int
as $BODY$
begin
    return console.req_schedule(_login, _reqdt, _uid, _p_date, _num, ''::hstore);
end;
$BODY$ language plpgsql;
