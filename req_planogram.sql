/* Copyright (c) 2006 - 2020 omobus-proxy-db authors, see the included COPYRIGHT file. */

create type console.planogram_t as (
    descr descr_t,
    country_id uid_t,
    brand_ids uids_t,
    rc_id uid_t,
    chan_ids uids_t,
    b_date date_t,
    e_date date_t
);

create or replace function console.req_planogram(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ _pl_id uid_t, _opt console.planogram_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    rv int = 0;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _cmd = 'unlink' ) then
	if( _pl_id is null ) then
	    raise exception '% invalid input attribute!', fcesig;
	end if;

	update planograms set hidden = 1
	    where pl_id = _pl_id and hidden = 0;
	GET DIAGNOSTICS rv = ROW_COUNT;
    elsif( _cmd = 'edit' ) then
	if( _pl_id is null or _opt is null or (_opt).descr is null or (_opt).country_id is null or (_opt).brand_ids is null ) then
	    raise exception '% invalid input attribute!', fcesig;
	end if;

	update planograms set 
	    descr = (_opt).descr, 
	    country_id = (_opt).country_id, 
	    brand_ids = (_opt).brand_ids, 
	    rc_id = (_opt).rc_id,
	    chan_ids = (_opt).chan_ids, 
	    b_date = (_opt).b_date, 
	    e_date = (_opt).e_date, 
	    author_id = _login
	where pl_id = _pl_id and hidden = 0;
	GET DIAGNOSTICS rv = ROW_COUNT;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [edit|unlink].', fcesig, cmd;
    end if;

    hs := hstore(array['pl_id',_pl_id]);
    if( _opt is not null ) then
	hs := hs || hstore(array['descr',(_opt).descr]);
	hs := hs || hstore(array['country_id',(_opt).country_id]);
	hs := hs || hstore(array['brand_ids',array_to_string((_opt).brand_ids,',')]);
	if( (_opt).rc_id is not null ) then
	    hs := hs || hstore(array['rc_id',(_opt).rc_id]);
	end if;
	if( (_opt).chan_ids is not null ) then
	    hs := hs || hstore(array['chan_ids',array_to_string((_opt).chan_ids,',')]);
	end if;
	if( (_opt).b_date is not null ) then
	    hs := hs || hstore(array['b_date',(_opt).b_date]);
	end if;
	if( (_opt).e_date is not null ) then
	    hs := hs || hstore(array['e_date',(_opt).e_date]);
	end if;
    end if;
    hs := hs || hstore(array['__rv',rv::text]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return rv;
end;
$BODY$ language plpgsql;

create or replace function console.req_planogram(_login uid_t, _reqdt datetime_t, /*attrs:*/ _name descr_t, _data blob_t, _content_type text) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    rv int = 0;
    xid uid_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _name is null or _data is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    insert into planograms(descr, country_id, brand_ids, "blob", content_type, author_id)
	values(_name, '', '{}'::uids_t, _data, _content_type, _login)
    returning pl_id
    into xid;
    GET DIAGNOSTICS rv = ROW_COUNT;

    hs := hstore(array['pl_id',xid]);
    hs := hs || hstore(array['descr',_name]);
    hs := hs || hstore(array['data_oid',_data::text]);
    hs := hs || hstore(array['content_type',_content_type]);
    hs := hstore(array['__rv',rv::text]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, 'add', hs);

    return rv;
end;
$BODY$ language plpgsql;
