/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_deletion(rlogin uid_t, cmd code_t, /*attrs:*/ a_id uid_t) returns int
as $BODY$
declare
    stack text; fcesig text;
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

    if( cmd = 'validate' ) then
	update j_deletions set validator_id=rlogin, validated=1 where account_id=a_id;
	update accounts set locked = 1 where account_id=a_id;
    elsif( cmd = 'reject' ) then
	update j_deletions set hidden=1 where account_id=a_id;
	update accounts set locked = 0 where account_id=a_id;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, cmd;
    end if;

    select descr from users where user_id=rlogin
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
	msg_cap  := "L10n_format_a"(u_lang, 'evmail', '', 'deletion/caption:'||cmd, array['a_name',a_name]);
	msg_body := "L10n_format_a"(u_lang, 'evmail', '', 'deletion/body:'||cmd, array['a_name',a_name,'address',a_address,
	    'u_name',case when auth is null then lower(rlogin) else auth end]);

	if( msg_cap is not null and msg_body is not null ) then
	    insert into mail_stream (rcpt_to, cap, msg, content, priority)
		values (rcpt_to, msg_cap, msg_body, 'text/html', 3 /*normal*/);
	end if;
    end loop;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['account_id',a_id]));

    return 0;
end;
$BODY$ language plpgsql;
