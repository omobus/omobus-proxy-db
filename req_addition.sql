/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_addition(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ _docid uid_t) 
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
    updated_rows int = 0;
    g uid_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _docid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	update j_additions set validator_id = _login, validated = 1, hidden = 0, updated_ts = current_timestamp
	    where doc_id = _docid and validated = 0
	returning guid
	into g;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;

	update accounts set hidden = 0
	    where account_id = g and approved = 0 and hidden = 1;
    elsif( _cmd = 'reject' ) then
	update j_additions set hidden = 1, updated_ts = current_timestamp
	    where doc_id = _docid and hidden = 0
	returning guid
	into g;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;

	update accounts set hidden = 1
	    where account_id = g and approved = 0 and hidden = 0;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;

    if updated_rows > 0 then
	select descr from users where user_id = _login
	    into auth;
	select descr, address from accounts where account_id = g
	    into a_name, a_address;

	for rcpt_to, u_lang in select evaddrs, lang_id from users where user_id in (
		select user_id from j_additions where doc_id = _docid
	    ) and hidden=0 and evaddrs is not null and array_length(evaddrs, 1) > 0
	loop
	    msg_cap  := "L10n_format_a"(u_lang, 'evmail', '', 'addition/caption:'||_cmd, array['a_name',a_name]);
	    msg_body := "L10n_format_a"(u_lang, 'evmail', '', 'addition/body:'||_cmd, array['a_name',a_name,'address',a_address,
		'u_name',case when auth is null then lower(_login) else auth end]);

	    if( msg_cap is not null and msg_body is not null ) then
		insert into mail_stream (rcpt_to, cap, msg, content, priority)
		    values (rcpt_to, msg_cap, msg_body, 'text/html', 3 /*normal*/);
	    end if;
	end loop;
    end if;

    hs := hstore(array['doc_id',_docid]);
    hs := hs || hstore(array['_updated_rows',updated_rows::varchar]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return 0;
end;
$BODY$ language plpgsql;
