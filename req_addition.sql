/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_addition(rlogin uid_t, cmd code_t, /*attrs:*/ d_id uid_t) returns int
as $BODY$
declare
    stack text; fcesig text;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( d_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( cmd = 'validate' ) then
	update j_additions set validator_id=rlogin, validated=1, updated_ts=current_timestamp
	    where doc_id=d_id;
    elsif( cmd = 'reject' ) then
	update j_additions set hidden=1, updated_ts=current_timestamp
	    where doc_id=d_id;
	update accounts set hidden=1, locked=0
	    where account_id=(select guid from h_addition where doc_id=d_id) and approved=0;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, cmd;
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['doc_id',d_id]));
    return 0;
end;
$BODY$ language plpgsql;
