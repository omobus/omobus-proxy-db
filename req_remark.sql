/* Copyright (c) 2006 - 2021 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_remark(_login uid_t, _reqdt datetime_t, _cmd code_t, _doc_id uid_t, _remark_type_id uid_t, _note note_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    rows int;
    author_name descr_t;
    u_id uid_t;
    u_lang lang_t;
    a_id uid_t;
    a_name descr_t;
    a_address address_t;
    f_dt datetime_t;
    sub descr_t;
    "strict" bool_t;
    done bool_t;
    re bool_t;
    x date;
    blob_id blob_t;
    target_created int = 0;
    rcpt_to emails_t;
    ar text array;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    _cmd := lower(_cmd);
    _remark_type_id := NIL(_remark_type_id);
    _note := NIL(trim(_note));

    if( _cmd not in ('accept','reject') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [accept|reject].', fcesig, _cmd;
    end if;
    if( _doc_id is null or (_cmd = 'reject' and _remark_type_id is null and _note is null)) then
	raise exception '% invalid input attribute.', fcesig;
    end if;
    if( (select count(doc_id) from h_confirmation where doc_id = _doc_id) = 0 ) then
	raise exception '% unable to find confirmation with [doc_id=%] .', fcesig, _doc_id;
    end if;

    if( _cmd = 'accept' ) then
	if( (select count(doc_id) from j_remarks where doc_id = _doc_id) = 0 ) then
	    insert into j_remarks(doc_id, status, remark_type_id, note)
		values(_doc_id, 'accepted', _remark_type_id, _note);
	else
	    update j_remarks set status = 'accepted', remark_type_id = _remark_type_id, note = _note
		where doc_id = _doc_id and status <> 'accepted';
	end if;
	GET DIAGNOSTICS rows = ROW_COUNT;
    elsif( _cmd = 'reject' ) then
	if( (select count(doc_id) from j_remarks where doc_id = _doc_id) = 0 ) then
	    insert into j_remarks(doc_id, status, remark_type_id, note)
		values(_doc_id, 'rejected', _remark_type_id, _note);
	else
	    update j_remarks set status = 'rejected', remark_type_id = _remark_type_id, note = _note
		where doc_id = _doc_id and status <> 'rejected';
	end if;
	GET DIAGNOSTICS rows = ROW_COUNT;
    end if;

    if( rows > 0 ) then
	select 
	    h.user_id, h.account_id, a.descr, a.address, t.subject, g.photo_needed, g.accomplished, t.renewable, t.e_date, t.image, h.fix_dt
	from h_confirmation h, targets t, confirmation_types g, accounts a
	    where h.doc_id = _doc_id and h.account_id = a.account_id and h.target_id = t.target_id and h.confirmation_type_id = g.confirmation_type_id
	into u_id, a_id, a_name, a_address, sub, "strict", done, re, x, blob_id, f_dt;

	select descr from users 
	    where user_id = _login
	into author_name;

	select evaddrs, lang_id from users
	    where user_id = u_id
	into rcpt_to, u_lang;

	update targets set e_date = current_date, hidden = 1 
	    where pid = _doc_id and e_date > current_date::date_t and hidden = 0;

	if( _remark_type_id is not null ) then
	    ar := array_append(ar, coalesce((select descr from remark_types where remark_type_id = _remark_type_id)::text,'-'));
	end if;
	if( _note is not null ) then
	    ar := array_append(ar, coalesce(_note::text,'-'));
	end if;

	if( _cmd = 'reject' and x > current_date and done = 1 ) then
	    insert into targets (
		target_type_id, 
		subject, 
		body, 
		b_date, 
		e_date, 
		author_id, 
		account_ids, 
		image, 
		"immutable", 
		"renewable", 
		pid
	    ) values(
		case when strict = 1 then 'target:strict' else 'target:normal' end, format('RE: %s',sub),
		"L10n_format_a"(u_lang,'targets','','confirmation',array['fix_date',"L"(current_date),'msg',array_to_string(ar,'<br/>'),
		    'u_name',coalesce(author_name,_login)],_note),
		current_date, 
		case when re = 1 then current_date + "paramInteger"('target:offset') else x end, 
		_login, 
		array[a_id::varchar],
		blob_id, 
		1, 
		re,
		_doc_id
	    );
	    GET DIAGNOSTICS target_created = ROW_COUNT;

	    if( blob_id is not null and (select count(*) from thumbnail_stream where photo=blob_id) = 0 ) then
		insert into thumbnail_stream(photo)
		    values(blob_id)
		on conflict do nothing;
	    end if;
	end if;

	perform evmail_add(
	    rcpt_to, 
	    u_lang, 
	    format('remark/caption:%s', _cmd), 
	    format('remark/body:%s', 
	    case 
		when _cmd = 'reject' then _cmd || (case when target_created = 1 then '1' else '0' end) 
		else _cmd || (case when ar is null then '1' else '0' end) 
	    end),
	    case when _cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array[
		'a_name',a_name,
		'address',a_address,
		'fix_dt',"L"(f_dt),
		'u_name',coalesce(author_name,_login),
		'sub',sub,
		'note',array_to_string(ar,'<br/>')
	    ]
	);

	perform content_add('stat_confirmations', '', "monthDate_First"(f_dt::date_t), "monthDate_Last"(f_dt::date_t));
	perform content_add('targets_compliance', '', '', '');
    end if;

    hs := hstore(array['doc_id',_doc_id]);
    hs := hs || hstore(array['rows',rows::varchar]);
    if _note is not null then
	hs := hs || hstore(array['note',_note]);
    end if;
    if _remark_type_id is not null then
	hs := hs || hstore(array['remark_type_id',_remark_type_id]);
    end if;

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return rows;
end;
$BODY$ language plpgsql;
