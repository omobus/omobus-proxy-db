/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_addition(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ _docid uid_t) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    updated_rows int = 0;
    g uid_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _docid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	update j_additions set validator_id = _login, validated = 1, updated_ts = current_timestamp
	    where doc_id = _docid and hidden = 0 and validated = 0;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;
    elsif( _cmd = 'reject' ) then
	update j_additions set hidden = 1, updated_ts = current_timestamp
	    where doc_id = _docid and hidden = 0
	returning guid
	into g;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;

	update accounts set hidden = 1, locked = 0
	    where account_id = g and approved = 0 and hidden = 0;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hstore(array['doc_id',_docid]));
    return 0;
end;
$BODY$ language plpgsql;
