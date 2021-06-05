/* Copyright (c) 2006 - 2021 omobus-proxy-db authors, see the included COPYRIGHT file. */

create type console.route_t as (user_id uid_t, cycle_id uid_t, account_id uid_t);

create or replace function console.req_route(_login uid_t, _reqdt datetime_t, _cmd code_t, _attrs console.route_t, _arg int) returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    weeks int; 
    u_wdays smallint[];
    x text;
    tmp int;
    rc int = 0;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    _cmd := lower(_cmd);

    if( not _cmd in ('set/week','drop/week','set/day','drop/day','remove','restore','add') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [set/week|drop/week|set/day|drop/day].', fcesig, _cmd;
    end if;
    if( _attrs is null or (_attrs).user_id is null or (_attrs).cycle_id is null or (_attrs).account_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select ceil((e_date::date - b_date::date)/7.0), status from route_cycles where cycle_id = (_attrs).cycle_id
	into weeks, x;

    if( weeks is null or x = 'closed' ) then
	raise exception '% unable to edit unknown or closed cycle!', fcesig;
    end if;
    if( weeks <= 0 or weeks > 4  ) then
	raise exception '% cycle [%] dates are invalid!', fcesig, (_attrs).cycle_id;
    end if;
    if( _cmd in ('set/week', 'set/day') and (select count(*) from accounts where account_id = (_attrs).account_id and (hidden=1 or locked=1)) > 0 ) then
	raise exception '% account [%] is locked or deleted!', fcesig, (_attrs).account_id;
    end if;
    if( _cmd = 'set/week' ) then
	if( _arg is null or _arg < 1 or _arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=_login, weeks[_arg] = 1
		where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( _cmd = 'drop/week' ) then
	if( _arg is null or _arg < 1 or _arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=_login, weeks[_arg] = 0
		where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( _cmd = 'set/day' ) then
	if( _arg is null or _arg < 1 or _arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    select coalesce("rules:wdays","paramIntegerArray"('rules:wdays')) from users where user_id = (_attrs).user_id
		into u_wdays;
	    if( u_wdays is null or u_wdays[_arg] = 1 ) then
		if( weeks = 1 ) then
		    update routes set author_id=_login, days[_arg] = 1, weeks[1] = 1
			where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
		else
		    update routes set author_id=_login, days[_arg] = 1
			where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
		end if;
		rc := 1;
	    else
		raise notice '% unables to set days[%]=1 to the route (user_id=%, account_idm%, cycle_id=%), please, check users.rules:wdays rules.', 
		    fcesig, _arg, (_attrs).user_id, (_attrs).account_id, (_attrs).cycle_id;
	    end if;
	end if;
    elsif( _cmd = 'drop/day') then
	if( _arg is null or _arg < 1 or _arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    if( weeks = 1 ) then
		update routes set author_id=_login, days[_arg] = 0, weeks[1] = 0
		    where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	    else
		update routes set author_id=_login, days[_arg] = 0
		    where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	    end if;
	    rc := 1;
	end if;
    elsif( _cmd = 'remove' ) then
	update routes set author_id=_login, hidden = 1
	    where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	rc := 1;
    elsif( _cmd = 'restore' ) then
	update routes set author_id=_login, hidden = 0
	    where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	rc := 1;
    elsif( _cmd = 'add' ) then
	select hidden from routes where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id
	    into tmp;
	if( tmp is null ) then
	    insert into routes(user_id, cycle_id, account_id, author_id)
		values((_attrs).user_id, (_attrs).cycle_id, (_attrs).account_id, _login);
	    rc := 1;
	elsif( tmp = 1 ) then
	    update routes set author_id=_login, days=array[0,0,0,0,0,0,0], weeks=array[0,0,0,0], hidden = 0
		where user_id = (_attrs).user_id and account_id = (_attrs).account_id and cycle_id = (_attrs).cycle_id;
	    rc := 1;
	end if;
    end if;

    hs := hstore(array['user_id',(_attrs).user_id]);
    hs := hs || hstore(array['cycle_id',(_attrs).cycle_id]);
    hs := hs || hstore(array['account_id',(_attrs).account_id]);
    hs := hs || hstore(array['arg',_arg::varchar]);
    hs := hs || hstore(array['_rc',rc::varchar]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return rc;
end;
$BODY$ language plpgsql;
