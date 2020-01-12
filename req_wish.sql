/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_wish(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ _aid uid_t, _uid uid_t) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    updated_rows int = 0;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _cmd not in ('validate','reject') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;
    if( _aid is null or _uid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	update j_wishes set validator_id = _login, validated = 1
	    where account_id = _aid and user_id = _uid and hidden = 0 and validated = 0;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;
    elsif( _cmd = 'reject' ) then
	update j_wishes set hidden = 1
	    where account_id = _aid and user_id = _uid and hidden = 0;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;
    end if;

    if updated_rows > 0 then
	select descr from users where user_id = _login
	    into auth;
	select descr, address from accounts where account_id = _aid
	    into a_name, a_address;

	perform evmail_add(
	    _uid, 
	    'wish/caption:'||_cmd, 
	    'wish/body:'||_cmd, case when _cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array['a_name',a_name,'address',a_address,'u_name',case when auth is null then lower(_login) else auth end]
	);
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hstore(array['account_id',_aid,'user_id',_uid]));

    return updated_rows;
end;
$BODY$ language plpgsql;
