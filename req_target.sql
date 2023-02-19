/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_target(_login uid_t, _reqdt datetime_t, _tid uid_t) 
    returns void
as $BODY$
declare
    stack text; fcesig text;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _tid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    update targets set hidden=1 where target_id=_tid;

    perform content_add('targets_compliance', '', '', '');

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, 'drop', hstore(array['target_id',_tid]));
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

create or replace function console.req_target(_login uid_t, _reqdt datetime_t, _tid uid_t, _opt console.target_t) 
    returns uid_t
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    cmd code_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _opt is null or (_opt).target_type_id is null or (_opt).sub is null or (_opt).msg is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _tid is null or (select count(target_id) from targets where target_id=_tid) = 0 ) then
	if( _tid is null ) then
	    _tid := man_id();
	end if;

	insert into targets (
	    target_id, 
	    target_type_id, 
	    subject, body, 
	    b_date, 
	    e_date, 
	    dep_id, 
	    author_id, 
	    account_ids, 
	    region_ids, 
	    city_ids, 
	    rc_ids, 
	    chan_ids, 
	    poten_ids, 
	    "immutable"
	) values(
	    _tid, 
	    (_opt).target_type_id, 
	    (_opt).sub, 
	    (_opt).msg, 
	    (_opt).b_date, 
	    (_opt).e_date, 
	    (_opt).dep_id, 
	    _login, 
	    (_opt).account_ids, 
	    (_opt).region_ids, 
	    (_opt).city_ids, 
	    (_opt).rc_ids, 
	    (_opt).chan_ids, 
	    (_opt).poten_ids, 
	    0
	);
	cmd := 'add';
    else
	update targets set 
	    target_type_id=(_opt).target_type_id, 
	    subject=(_opt).sub, 
	    body=(_opt).msg,
	    b_date=(_opt).b_date, 
	    e_date=(_opt).e_date, 
	    dep_id=(_opt).dep_id, 
	    account_ids=(_opt).account_ids, 
	    region_ids=(_opt).region_ids, 
	    city_ids=(_opt).city_ids, 
	    rc_ids=(_opt).rc_ids, 
	    chan_ids=(_opt).chan_ids, 
	    poten_ids=(_opt).poten_ids
	where target_id=_tid;
	cmd := 'update';
    end if;

    perform content_add('targets_compliance', '', '', '');

    hs := hstore(array['target_id',_tid]);
    hs := hs || hstore(array['author_id',_login]);
    if (_opt).target_type_id is not null then
	hs := hs || hstore(array['target_type_id',(_opt).target_type_id]);
    end if;
    if (_opt).sub is not null then
	hs := hs || hstore(array['subject',(_opt).sub]);
    end if;
    if (_opt).msg is not null then
	hs := hs || hstore(array['body',(_opt).msg]);
    end if;
    if (_opt).b_date is not null then
	hs := hs || hstore(array['b_date',(_opt).b_date]);
    end if;
    if (_opt).e_date is not null then
	hs := hs || hstore(array['e_date',(_opt).e_date]);
    end if;
    if (_opt).account_ids is not null then
	hs := hs || hstore(array['account_ids',array_to_string((_opt).account_ids,',')]);
    end if;
    if (_opt).region_ids is not null then
	hs := hs || hstore(array['region_ids',array_to_string((_opt).region_ids,',')]);
    end if;
    if (_opt).city_ids is not null then
	hs := hs || hstore(array['city_ids',array_to_string((_opt).city_ids,',')]);
    end if;
    if (_opt).rc_ids is not null then
	hs := hs || hstore(array['rc_ids',array_to_string((_opt).rc_ids,',')]);
    end if;
    if (_opt).chan_ids is not null then
	hs := hs || hstore(array['chan_ids',array_to_string((_opt).chan_ids,',')]);
    end if;
    if (_opt).poten_ids is not null then
	hs := hs || hstore(array['poten_ids',array_to_string((_opt).poten_ids,',')]);
    end if;
    if (_opt).dep_id is not null then
	hs := hs || hstore(array['dep_id',(_opt).dep_id]);
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, cmd, hs);

    return _tid;
end;
$BODY$ language plpgsql;

create or replace function console.req_target(_login uid_t, _reqdt datetime_t, _opt console.target_t) 
    returns uid_t
as $BODY$
begin
    return console.req_target(_login, _reqdt, null, _opt);
end;
$BODY$ language plpgsql;

create type console.target_at_t as (
    doc_id uid_t, 
    sub descr_t, 
    msg text, 
    strict bool_t, 
    urgent bool_t
);

create or replace function console.req_target(_login uid_t, _reqdt datetime_t, _opt console.target_at_t)
    returns uid_t
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    d_code uid_t;
    tid uid_t;
    tpid uid_t;
    re bool_t = 0;
    aid uid_t;
    a_name descr_t;
    a_address address_t;
    blob_id blob_t;
    uid uid_t;
    u_lang lang_t;
    author_name descr_t;
    tmp int;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _opt is null or (_opt).doc_id is null or (_opt).sub is null or (_opt).msg is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;
    if "paramBoolean"('target:multi') then
	tid := man_id();
    elsif (select count(*) from targets where target_id=(_opt).doc_id) = 0 then
	tid := (_opt).doc_id;
    else
	return null;
    end if;

    select doc_code from j_docs where doc_id = (_opt).doc_id 
	into d_code;
    if d_code is null then
	raise exception '% invalid input attribute!', fcesig;
    elsif d_code = 'photo' then
	select h.user_id, h.account_id, u.lang_id, a.descr, a.address, h.photo from h_photo h, users u, accounts a
	    where doc_id = (_opt).doc_id and h.user_id = u.user_id and h.account_id = a.account_id
	into uid, aid, u_lang, a_name, a_address, blob_id;
	re := 1;
    elsif d_code = 'confirmation' then
	select h.account_id, u.lang_id, target_id, "renewable" from h_confirmation h, users u
	    where doc_id = (_opt).doc_id and h.user_id = u.user_id
	into aid, u_lang, tpid, re;
    elsif d_code = 'posm' then
	select h.user_id, h.account_id, u.lang_id, a.descr, a.address, h.photo from h_posm h, users u, accounts a
	    where doc_id = (_opt).doc_id and h.user_id = u.user_id and h.account_id = a.account_id
	into uid, aid, u_lang, a_name, a_address, blob_id;
	re := 1;
    else
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( aid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select descr from users where user_id=_login
	into author_name;

    if author_name is null then
	author_name := _login;
    end if;

    insert into targets (
	target_id, 
	target_type_id, 
	subject, body, 
	b_date, 
	e_date, 
	author_id, 
	account_ids, 
	image, 
	"immutable", 
	"renewable", 
	pid
    ) values(
	tid, 
	case when (_opt).strict = 1 then 'target:strict' else 'target:normal' end, 
	(_opt).sub, 
	"L10n_format_a"(u_lang,'targets','',d_code,array['fix_date',"L"(current_date),'msg',(_opt).msg,'u_name',author_name],(_opt).msg), 
	current_date, 
	current_date + "paramInteger"('target:offset'), 
	_login, 
	array[aid::varchar], 
	blob_id, 
	1, 
	re, 
	tpid
    );

    if blob_id is not null and (select count(*) from thumbnail_stream where photo=blob_id) = 0 then
	insert into thumbnail_stream(photo) 
	    values(blob_id);
    end if;

    if (_opt).urgent = 1 and d_code in ('photo','posm') then
	select urgent_add(
	    uid, 
	    aid, 
	    '7', 
	    _reqdt::date_t, 
	    _login, 
	    "L10n_format_a"(u_lang,'urgent','',d_code,array['fix_date',"L"(_reqdt::date_t),'u_name',author_name])
	) into tmp;
	if tmp > 0 then
	    insert into reminders(
		reminder_id, 
		subject, 
		body, 
		b_date, 
		e_date, 
		author_id, 
		user_ids
	    ) values(
		tid, 
		(select upper(descr) from activity_types where activity_type_id='7'), 
		"L10n_format_a"(u_lang,'reminder','',d_code,array['u_name',author_name,'fix_date',"L"(_reqdt::date_t),'a_name',a_name,'address',a_address]), 
		_reqdt::date, 
		_reqdt::date + 1, 
		_login, 
		array[uid::varchar]
	    );
        end if;
    end if;


    if d_code in ('photo','posm') then
	perform evmail_add(
	    uid, 
	    'target/caption', 
	    format('target/body:%s',d_code), 
	    3::smallint /*normal*/, 
	    array[
		'subject',(_opt).sub,
		'body',(_opt).msg,
		'u_name',author_name,
		'a_name',a_name,
		'address',a_address,
		'fix_dt',"L"(_reqdt),
		'b_date',"L"(current_date),
		'e_date',"L"(current_date + "paramInteger"('target:offset'))
	    ]
	);
    end if;

    perform content_add('targets_compliance', '', '', '');

    hs := hstore(array['target_id',tid]);
    hs := hs || hstore(array['subject',(_opt).sub]);
    hs := hs || hstore(array['body',(_opt).msg]);
    hs := hs || hstore(array['strict',case when (_opt).strict = 1 then 'yes' else 'no' end]);
    hs := hs || hstore(array['urgent',case when (_opt).urgent = 1 then 'yes' else 'no' end]);
    hs := hs || hstore(array['author_id',_login]);
    hs := hs || hstore(array['doc_id',(_opt).doc_id]);
    hs := hs || hstore(array['d_code',d_code]);
    if blob_id is not null then
	hs := hs || hstore(array['blob_id',blob_id::varchar]);
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, 'add_at', hs);

    return tid;
end;
$BODY$ language plpgsql;
