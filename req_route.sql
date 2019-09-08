/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create type console.route_t as (user_id uid_t, cycle_id uid_t, account_id uid_t);

create or replace function console.req_route(rlogin uid_t, cmd code_t, attrs console.route_t, arg int) returns int
as $BODY$
declare
    stack text; fcesig text;
    weeks int; x bool_t;
    u_wdays smallint[];
    rc int = 0;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    cmd := lower(cmd);

    if( not cmd in ('set/week','drop/week','set/day','drop/day','remove','restore','add') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [set/week|drop/week|set/day|drop/day].', fcesig, cmd;
    end if;
    if( attrs is null or (attrs).user_id is null or (attrs).cycle_id is null or (attrs).account_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select ceil((e_date::date - b_date::date)::float/7), closed from route_cycles where cycle_id = (attrs).cycle_id
	into weeks, x;

    if( weeks is null or x = 1 ) then
	raise exception '% unable to edit unknown or closed cycle!', fcesig;
    end if;
    if( weeks <= 0 or weeks > 6  ) then
	raise exception '% cycle [%] dates are invalid!', fcesig, (attrs).cycle_id;
    end if;
    if( cmd in ('set/week', 'set/day') and (select count(*) from accounts where account_id = (attrs).account_id and (hidden=1 or locked=1)) > 0 ) then
	raise exception '% account [%] is locked or deleted!', fcesig, (attrs).account_id;
    end if;
    if( cmd = 'set/week' ) then
	if( arg is null or arg < 1 or arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=rlogin, weeks[arg] = 1
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'drop/week' ) then
	if( arg is null or arg < 1 or arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=rlogin, weeks[arg] = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'set/day' ) then
	if( arg is null or arg < 1 or arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    select coalesce("rules:wdays"/*, 5-days work week: array[1,1,1,1,1,0,0]*/) from users where user_id = (attrs).user_id
		into u_wdays;
	    if( u_wdays is null or u_wdays[arg] = 1 ) then
		update routes set author_id=rlogin, days[arg] = 1
		    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
		rc := 1;
	    else
		raise notice '% unables to set days[%]=1 to the route (user_id=%, account_idm%, cycle_id=%), please, check users.rules:wdays rules.', 
		    fcesig, arg, (attrs).user_id, (attrs).account_id, (attrs).cycle_id;
	    end if;
	end if;
    elsif( cmd = 'drop/day') then
	if( arg is null or arg < 1 or arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    update routes set author_id=rlogin, days[arg] = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'remove' ) then
	update routes set author_id=rlogin, hidden = 1
	    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	rc := 1;
    elsif( cmd = 'restore' ) then
	update routes set author_id=rlogin, hidden = 0
	    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	rc := 1;
    elsif( cmd = 'add' ) then
	select hidden from routes where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id
	    into x;
	if( x is null ) then
	    insert into routes(user_id, cycle_id, account_id, author_id)
		values((attrs).user_id, (attrs).cycle_id, (attrs).account_id, rlogin);
	    rc := 1;
	elsif( x = 1 ) then
	    update routes set author_id=rlogin, days=array[0,0,0,0,0,0,0], weeks=array[0,0,0,0], hidden = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['user_id',(attrs).user_id,'cycle_id',(attrs).cycle_id,'account_id',(attrs).account_id,
	    'arg',arg::varchar,'out:rc',rc::varchar]));

    return rc;
end;
$BODY$ language plpgsql;
