/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_deletion(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ a_id uid_t) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    msg_body varchar(4096);
    msg_cap varchar(512);
    rcpt_to emails_t;
    u_lang lang_t;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( a_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	update j_deletions set validator_id = _login, validated = 1, hidden = 0 
	    where account_id = a_id and validated = 0;
	update accounts set locked = 1 
	    where account_id = a_id and locked = 0;
    elsif( _cmd = 'reject' ) then
	update j_deletions set hidden = 1 
	    where account_id = a_id and hidden = 0;
	update accounts set locked = 0 
	    where account_id = a_id and locked = 1;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;

    select descr from users where user_id=_login
	into auth;
    select descr, address from accounts where account_id=a_id
	into a_name, a_address;

    for rcpt_to, u_lang in select evaddrs, lang_id from users where user_id in (
	    select user_id from j_deletions where account_id=a_id
		union
	    select distinct user_id from my_accounts where account_id=a_id
		union
	    select distinct user_id from my_routes where account_id=a_id and p_date>=(current_date-1)::date_t
	) and hidden=0 and evaddrs is not null and array_length(evaddrs, 1) > 0
    loop
	msg_cap  := "L10n_format_a"(u_lang, 'evmail', '', 'deletion/caption:'||_cmd, array['a_name',a_name]);
	msg_body := "L10n_format_a"(u_lang, 'evmail', '', 'deletion/body:'||_cmd, array['a_name',a_name,'address',a_address,
	    'u_name',case when auth is null then lower(_login) else auth end]);

	if( msg_cap is not null and msg_body is not null ) then
	    insert into mail_stream (rcpt_to, cap, msg, content, priority)
		values (rcpt_to, msg_cap, msg_body, 'text/html', 3 /*normal*/);
	end if;
    end loop;

    hs := hstore(array['account_id',a_id]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return 0;
end;
$BODY$ language plpgsql;
