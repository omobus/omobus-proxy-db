/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_discard(rlogin uid_t, cmd code_t, /*attrs:*/ a_id uid_t, u_id uid_t, p_date date_t, t_id uid_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or p_date is null or u_id is null or t_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( cmd = 'validate' ) then
	update j_discards set validator_id=rlogin, validated=1
	    where account_id=a_id and user_id=u_id and route_date=p_date and activity_type_id=t_id;
    elsif( cmd = 'reject' ) then
	update j_discards set hidden=1
	    where account_id=a_id and user_id=u_id and route_date=p_date and activity_type_id=t_id;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, cmd;
    end if;

    select descr from users where user_id=rlogin
	into auth;
    select descr, address from accounts where account_id=a_id
	into a_name, a_address;

    perform evmail_add(u_id, 'discard/caption:'||cmd, 'discard/body:'||cmd, case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, array[
	'a_name',a_name,'address',a_address,'route_date',"L"(p_date),'u_name',case when auth is null then lower(rlogin) else auth end]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['account_id',a_id,'user_id',u_id,'route_date',p_date,'activity_type_id',t_id]));

    return 0;
end;
$BODY$ language plpgsql;
