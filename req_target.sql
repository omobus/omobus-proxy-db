/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_target(rlogin uid_t, t_id uid_t) returns void
as $BODY$
declare
    stack text; fcesig text;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( t_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    update targets set hidden=1 where target_id=t_id;

    perform content_add('targets_compliance', '', '', '');

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'drop', hstore(array['target_id',t_id]));
end;
$BODY$ language plpgsql;

create type console.target_t as (
    target_type_id uid_t, 
    sub descr_t, 
    msg text, 
    b_date date_t, 
    e_date date_t, 
    dep_id uid_t, 
    account_ids uids_t, 
    region_ids uids_t, 
    city_ids uids_t, 
    rc_ids uids_t, 
    chan_ids uids_t, 
    poten_ids uids_t
);

create or replace function console.req_target(rlogin uid_t, t_id uid_t, opt console.target_t) returns uid_t
as $BODY$
declare
    stack text; fcesig text;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( opt is null or (opt).target_type_id is null or (opt).sub is null or (opt).msg is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( t_id is null or (select count(target_id) from targets where target_id=t_id) = 0 ) then
	if( t_id is null ) then
	    t_id := man_id();
	end if;

	insert into targets (target_id, target_type_id, subject, body, b_date, e_date, dep_id, author_id, account_ids, region_ids, city_ids, rc_ids, chan_ids, poten_ids, "immutable")
	    values(t_id, (opt).target_type_id, (opt).sub, (opt).msg, (opt).b_date, (opt).e_date, (opt).dep_id, rlogin, (opt).account_ids, (opt).region_ids, (opt).city_ids, (opt).rc_ids, (opt).chan_ids, (opt).poten_ids, 0);
    else
	update targets set target_type_id=(opt).target_type_id, subject=(opt).sub, body=(opt).msg, b_date=(opt).b_date, e_date=(opt).e_date, dep_id=(opt).dep_id, account_ids=(opt).account_ids, region_ids=(opt).region_ids, city_ids=(opt).city_ids, rc_ids=(opt).rc_ids, chan_ids=(opt).chan_ids, poten_ids=(opt).poten_ids
	    where target_id=t_id;
    end if;

    perform content_add('targets_compliance', '', '', '');

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'update', hstore(array['target_id',t_id,'target_type_id',(opt).target_type_id,'subject',(opt).sub,'body',(opt).msg,
	    'b_date',(opt).b_date,'e_date',(opt).e_date,'account_ids',(opt).account_ids::varchar,'region_ids',(opt).region_ids::varchar,
	    'city_ids',(opt).city_ids::varchar,'rc_ids',(opt).rc_ids::varchar,'chan_ids',(opt).chan_ids::varchar,'poten_ids',(opt).poten_ids::varchar,
	    'dep_id',(opt).dep_id,'author_id',rlogin]));

    return t_id;
end;
$BODY$ language plpgsql;

create or replace function console.req_target(rlogin uid_t, opt console.target_t) returns uid_t
as $BODY$
begin
    return console.req_target(rlogin, null, opt);
end;
$BODY$ language plpgsql;

create type console.target_at_t as (doc_id uid_t, sub descr_t, msg text, strict bool_t);

create or replace function console.req_target(rlogin uid_t, opt console.target_at_t)
    returns uid_t
as $BODY$
declare
    stack text; fcesig text;
    d_code uid_t;
    t_id uid_t;
    t_pid uid_t;
    t_re bool_t = 0;
    a_id uid_t;
    blob_id blob_t;
    u_lang lang_t;
    author_name descr_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( opt is null or (opt).doc_id is null or (opt).sub is null or (opt).msg is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;
    if "paramBoolean"('target:multi') then
	t_id := man_id();
    elsif (select count(*) from targets where target_id=(opt).doc_id) = 0 then
	t_id := (opt).doc_id;
    else
	return null;
    end if;

    select ltrim(doc_code,'h_') from j_docs where doc_id = (opt).doc_id 
	into d_code;
    if d_code is null then
	raise exception '% invalid input attribute!', fcesig;
    elsif d_code = 'photo' then
	select h.account_id, u.lang_id, photo from h_photo h, users u
	    where doc_id = (opt).doc_id and h.user_id=u.user_id
	into a_id, u_lang, blob_id;
	t_re := 1;
    elsif d_code = 'confirmation' then
	select h.account_id, u.lang_id, target_id, "renewable" from h_confirmation h, users u
	    where doc_id = (opt).doc_id and h.user_id=u.user_id
	into a_id, u_lang, t_pid, t_re;
    else
	raise exception '% invalid input attribute!', fcesig;
    end if;
    if( a_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select descr from users where user_id=rlogin
	into author_name;

    insert into targets (target_id, target_type_id, subject, body, b_date, e_date, author_id, account_ids, image, "immutable", "renewable", pid)
	values(
	    t_id, 
	    case when (opt).strict = 1 then 'target:strict' else 'target:normal' end, (opt).sub, 
	    "L10n_format_a"(u_lang,'targets','',d_code,array['fix_date',"L"(current_date),'msg',(opt).msg,'u_name',coalesce(author_name,rlogin)],(opt).msg), 
	    current_date, 
	    current_date + "paramInteger"('target:depth'), 
	    rlogin, 
	    array[a_id::varchar], 
	    blob_id, 
	    1, 
	    t_re, 
	    t_pid
	);

    if blob_id is not null and (select count(*) from thumbnail_stream where photo=blob_id) = 0 then
	insert into thumbnail_stream(photo) 
	    values(blob_id);
    end if;

    perform content_add('targets_compliance', '', '', '');

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'add/'||d_code, hstore(array['target_id',t_id,'subject',(opt).sub,'body',(opt).msg,'strict',(opt).strict::varchar,
	    'author_id',rlogin,'doc_id',(opt).doc_id,'blob_id',blob_id::varchar]));

    return t_id;
end;
$BODY$ language plpgsql;
