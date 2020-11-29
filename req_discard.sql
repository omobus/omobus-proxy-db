/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_discard(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ a_id uid_t, u_id uid_t, t_id uid_t, p_date date_t) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or p_date is null or u_id is null or t_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	update j_discards set validator_id = _login, validated = 1, hidden = 0
	    where account_id = a_id and user_id = u_id and route_date = p_date and activity_type_id = t_id and validated = 0;
    elsif( _cmd = 'reject' ) then
	update j_discards set hidden = 1
	    where account_id = a_id and user_id = u_id and route_date = p_date and activity_type_id = t_id and hidden = 0;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;

    select descr from users where user_id=_login
	into auth;
    select descr, address from accounts where account_id=a_id
	into a_name, a_address;

    perform content_add('route_compliance', '', p_date, p_date);
    perform content_add('time', '', "monthDate_First"(p_date), "monthDate_Last"(p_date));

    perform evmail_add(u_id, 
	'discard/caption:'||_cmd, 
	'discard/body:'||_cmd, 
	case when _cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	array[
	    'a_name',a_name,
	    'address',a_address,
	    'route_date',"L"(p_date),
	    'u_name',case when auth is null then lower(_login) else auth end
	]
    );

    hs := hstore(array['account_id',a_id]);
    hs := hstore(array['user_id',u_id]);
    hs := hstore(array['route_date',p_date]);
    hs := hstore(array['activity_type_id',t_id]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return 0;
end;
$BODY$ language plpgsql;
