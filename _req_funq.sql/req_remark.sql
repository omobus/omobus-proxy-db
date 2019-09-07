/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_remark(rlogin uid_t, cmd code_t, _doc_id uid_t, _note note_t, _attrs hstore) returns int
as $BODY$
declare
    stack text; fcesig text;
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
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    cmd := lower(cmd);
    _note := NIL(trim(_note));

    if( cmd not in ('accept','reject') ) then
	raise exception '% doesn''t support [%] command.', fcesig, cmd;
    end if;
    if( _doc_id is null or (cmd = 'reject' and _note is null)) then
	raise exception '% invalid input attribute.', fcesig;
    end if;
    if( (select count(doc_id) from h_confirmation where doc_id = _doc_id) = 0 ) then
	raise exception '% unable to find confirmation with [doc_id=%] .', fcesig, _doc_id;
    end if;

    if( cmd = 'accept' ) then
	if( (select count(doc_id) from j_remarks where doc_id = _doc_id) = 0 ) then
	    insert into j_remarks(doc_id, status, note, attrs)
		values(_doc_id, 'accepted', _note, _attrs);
	else
	    update j_remarks set status = 'accepted', note = _note, attrs = _attrs
		where doc_id = _doc_id and status <> 'accepted';
	end if;
	GET DIAGNOSTICS rows = ROW_COUNT;
    elsif( cmd = 'reject' ) then
	if( (select count(doc_id) from j_remarks where doc_id = _doc_id) = 0 ) then
	    insert into j_remarks(doc_id, status, note, attrs)
		values(_doc_id, 'rejected', _note, _attrs);
	else
	    update j_remarks set status = 'rejected', note = _note, attrs = _attrs
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
	    where user_id = rlogin
	into author_name;

	select evaddrs, lang_id from users
	    where user_id = u_id
	into rcpt_to, u_lang;

	update targets set e_date = current_date, hidden = 1 
	    where pid = _doc_id and e_date > current_date::date_t and hidden = 0;

	if( cmd = 'reject' and x > current_date and done = 1 ) then
	    insert into targets (target_type_id, subject, body, b_date, e_date, author_id, account_ids, image, "immutable", "renewable", pid)
		values(
		    case when strict = 1 then 'target:strict' else 'target:normal' end, format('RE: %s',sub),
		    "L10n_format_a"(u_lang,'targets','','confirmation',array['fix_date',"L"(current_date),'msg',_note,'u_name',coalesce(author_name,rlogin)],_note),
		    current_date, 
		    case when re = 1 then current_date + "paramInteger"('target:depth') else x end, 
		    rlogin, 
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

	perform evmail_add(rcpt_to, u_lang, format('remark/caption:%s', cmd), 
	    format('remark/body:%s', case 
		when cmd = 'reject' then cmd || (case when target_created = 1 then '1' else '0' end) 
		else cmd || (case when _note is null then '1' else '0' end) 
	    end),
	    case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array[
		'a_name',a_name,
		'address',a_address,
		'fix_dt',"L"(f_dt),
		'u_name',coalesce(author_name,rlogin),
		'sub',sub,
		'note',_note
	    ]);

	    perform content_add('stat_confirmations', '', "monthDate_First"(f_dt::date_t), "monthDate_Last"(f_dt::date_t));
	    perform content_add('targets_compliance', '', '', '');
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, coalesce(_attrs,''::hstore) || hstore(array['doc_id',_doc_id,'note',_note,'rows',rows::varchar]));

    return rows;
end;
$BODY$ language plpgsql;
