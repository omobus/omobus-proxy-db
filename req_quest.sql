/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_quest(_login uid_t, _req_dt datetime_t, _cmd code_t, _attrs hstore) 
    returns int
as $BODY$
declare
    stack text;
    fcesig text;
    zrows int;
    zrows2 int;
    hs hstore;
    reqId uid_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    _cmd := lower(_cmd);

    if( _cmd not in ('erase','remove','restore','remove2','restore2','set','urgent') ) then
	raise exception '% doesn''t support [%] command.', fcesig, _cmd;
    end if;
    if( _attrs is null or _attrs->'account_id' is null or _attrs->'qname_id' is null or _attrs->'fix_date' is null) then
	raise exception '% invalid input attribute.', fcesig;
    end if;

    if( _cmd = 'erase' ) then
	update dyn_quests set hidden = 1, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' 
		and "_isRecentData" = 1 and hidden = 0;
	GET DIAGNOSTICS zrows = ROW_COUNT;
	update dyn_quests2 set hidden = 1, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' 
		and "_isRecentData" = 1 and hidden = 0;
	GET DIAGNOSTICS zrows2 = ROW_COUNT;
    elsif( _cmd = 'remove' ) then
	update dyn_quests set hidden = 1, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' and qrow_id = _attrs->'qrow_id' 
		and "_isRecentData" = 1 and hidden = 0;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( _cmd = 'restore' ) then
	update dyn_quests set hidden = 0, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' and qrow_id = _attrs->'qrow_id' 
		and "_isRecentData" = 1 and hidden = 1;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( _cmd = 'remove2' ) then
	update dyn_quests2 set hidden = 1, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' and guid = (_attrs->'guid')::uuid 
		and "_isRecentData" = 1 and hidden = 0;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( _cmd = 'restore2' ) then
	update dyn_quests2 set hidden = 0, censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' and guid = (_attrs->'guid')::uuid 
		and "_isRecentData" = 1 and hidden = 1;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( _cmd = 'set' ) then
	update dyn_quests set "value" = trim(_attrs->'value'), censor_id = _login, altered_dt = _req_dt
	    where fix_date = _attrs->'fix_date' and account_id = _attrs->'account_id' and qname_id = _attrs->'qname_id' and qrow_id = _attrs->'qrow_id' 
		and "_isRecentData" = 1 and "value" <> _attrs->'value' and _attrs->'value' is not null and trim(_attrs->'value') <> '';
	GET DIAGNOSTICS zrows = ROW_COUNT;
    end if;

    hs := _attrs;
    if zrows is not null then
	hs := hs || hstore(array['zrows',zrows::varchar]);
    end if;
    if zrows2 is not null then
	hs := hs || hstore(array['zrows2',zrows2::varchar]);
    end if;

    reqId := nextval('console.seq_requests');
    insert into console.requests(req_id, req_login, req_type, req_dt, status, attrs)
	values(reqId, _login, fcesig, _req_dt, _cmd, hs);

    return coalesce(zrows,0) + coalesce(zrows2,0);
end;
$BODY$ language plpgsql;
