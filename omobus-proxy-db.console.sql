/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema console;

create sequence console.seq_requests;


create table console.requests (
    req_id 		uid_t 		not null primary key default nextval('console.seq_requests'),
    req_login 		uid_t 		not null,
    req_type 		code_t 		not null,
    status 		code_t 		not null,
    attrs 		hstore 		null,
    inserted_ts 	ts_auto_t 	not null
);

create table console.sessions (
    ses_id 		uid_t 		not null primary key,
    ses_ip 		hostname_t 	not null,
    u_name 		uid_t 		not null,
    u_id 		uid_t 		null,
    params 		json 		not null default '{}',
    lifetime 		int32_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    access_ts 		ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    closed 		bool_t 		not null default 0,
    gc 			bool_t 		null
);

create trigger trig_lock_update before update on console.requests for each row execute procedure tf_lock_update();
create trigger trig_updated_ts before update on console.sessions for each row execute procedure tf_updated_ts();


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

create or replace function console.req_canceling(rlogin uid_t, /*attrs:*/ u_id uid_t, t_id uid_t, b date_t, e date_t, n note_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    r date_t;
    auth descr_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or t_id is null or b is null or e is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    for i in 0..(e::date-b::date) loop
	r = (b::date+i)::date_t;
	if( (select count(*) from j_cancellations where user_id = u_id and route_date = r) > 0 ) then
	    update j_cancellations set canceling_type_id = t_id, note = n, updated_ts = current_timestamp
		where user_id = u_id and route_date = r;
	else
	    insert into j_cancellations(user_id, route_date, canceling_type_id, note, hidden)
		values(u_id, r, t_id, n, 0);
	    if( (select count(*) from j_user_activities where user_id = u_id and route_date = r) > 0 ) then
		/* revokes cancellation: */
		update j_cancellations set hidden=1 where user_id = u_id and route_date = r;
	    end if;
	end if;
	perform content_add('tech_route', u_id, r, r);
	perform content_add('route_compliance', '', r, r);
    end loop;

    select descr from users where user_id=rlogin
	into auth;

    perform evmail_add(u_id, 'canceling/caption:new', 'canceling/body:new', 3::smallint /*normal*/, array[
	'doc_note',NIL(trim(n)),'b_date',"L"(b),'e_date',"L"(e),
	'canceling_type',(select lower(descr) from canceling_types where canceling_type_id = t_id),
	'u_name',case when auth is null then lower(rlogin) else auth end]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'set', hstore(array['user_id',u_id,'b_date',b,'e_date',e,'canceling_type_id',t_id,'doc_note',n]));

    return 0;
end;
$BODY$ language plpgsql;

create or replace function console.req_canceling(rlogin uid_t, cmd code_t, /*attrs:*/ u_id uid_t, p_date date_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    auth descr_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or p_date is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( cmd = 'revoke' ) then
	update j_cancellations set hidden=1, updated_ts=current_timestamp
	    where user_id=u_id and route_date=p_date;
    elsif( cmd = 'restore' ) then
	update j_cancellations set hidden=0, updated_ts=current_timestamp
	    where user_id=u_id and route_date=p_date;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [revoke|restore].', fcesig, cmd;
    end if;

    perform content_add('tech_route', u_id, p_date, p_date);
    perform content_add('route_compliance', '', p_date, p_date);

    select descr from users where user_id=rlogin
	into auth;

    perform evmail_add(u_id, 'canceling/caption:'||cmd, 'canceling/body:'||cmd, case when cmd = 'revoke' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, array[
	'route_date',"L"(p_date), 'u_name',case when auth is null then lower(rlogin) else auth end]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['user_id',u_id,'route_date',p_date]));

    return 0;
end;
$BODY$ language plpgsql;

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

create or replace function console.req_discard(rlogin uid_t, cmd code_t, /*attrs:*/ a_id uid_t, u_id uid_t, p_date date_t, t_id uid_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or p_date is null or u_id is null or t_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( cmd = 'validate' ) then
	update j_discards set validator_id=rlogin, validated=1
	    where account_id=a_id and user_id=u_id and route_date=p_date and activity_type_id=t_id;
    elsif( cmd = 'reject' ) then
	update j_discards set hidden=1
	    where account_id=a_id and user_id=u_id and route_date=p_date and activity_type_id=t_id;
    else
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, cmd;
    end if;

    select descr from users where user_id=rlogin
	into auth;
    select descr, address from accounts where account_id=a_id
	into a_name, a_address;

    perform evmail_add(u_id, 'discard/caption:'||cmd, 'discard/body:'||cmd, case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, array[
	'a_name',a_name,'address',a_address,'route_date',"L"(p_date),'u_name',case when auth is null then lower(rlogin) else auth end]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['account_id',a_id,'user_id',u_id,'route_date',p_date,'activity_type_id',t_id]));

    return 0;
end;
$BODY$ language plpgsql;

create or replace function console.req_resolution(rlogin uid_t, /*attrs:*/ t_id uid_t, n note_t) returns int
as $BODY$
declare
    stack text; fcesig text;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( t_id is null or n is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    update tickets set resolution=n, closed=1, updated_ts=current_timestamp
	where ticket_id=t_id;

    perform evmail_add((select user_id from tickets where ticket_id=t_id), 'resolution/caption', 'resolution/body', 3::smallint /*normal*/, array[
	'ticket_id',t_id,'inserted_ts',"L"(current_timestamp),'doc_note',n]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'set', hstore(array['ticket_id',t_id,'doc_note',n]));

    return 0;
end;
$BODY$ language plpgsql;

create type console.route_t as (user_id uid_t, cycle_id uid_t, account_id uid_t);

create or replace function console.req_route(rlogin uid_t, cmd code_t, attrs console.route_t, arg int) returns int
as $BODY$
declare
    stack text; fcesig text;
    weeks int; x bool_t;
    u_wdays smallint[];
    rc int = 0;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    cmd := lower(cmd);

    if( not cmd in ('set/week','drop/week','set/day','drop/day','remove','restore','add') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [set/week|drop/week|set/day|drop/day].', fcesig, cmd;
    end if;
    if( attrs is null or (attrs).user_id is null or (attrs).cycle_id is null or (attrs).account_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select ceil((e_date::date - b_date::date)::float/7), closed from route_cycles where cycle_id = (attrs).cycle_id
	into weeks, x;

    if( weeks is null or x = 1 ) then
	raise exception '% unable to edit unknown or closed cycle!', fcesig;
    end if;
    if( weeks <= 0 or weeks > 6  ) then
	raise exception '% cycle [%] dates are invalid!', fcesig, (attrs).cycle_id;
    end if;
    if( cmd in ('set/week', 'set/day') and (select count(*) from accounts where account_id = (attrs).account_id and (hidden=1 or locked=1)) > 0 ) then
	raise exception '% account [%] is locked or deleted!', fcesig, (attrs).account_id;
    end if;
    if( cmd = 'set/week' ) then
	if( arg is null or arg < 1 or arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=rlogin, weeks[arg] = 1
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'drop/week' ) then
	if( arg is null or arg < 1 or arg > weeks ) then
	    raise exception '% invalid week number!', fcesig;
	else
	    update routes set author_id=rlogin, weeks[arg] = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'set/day' ) then
	if( arg is null or arg < 1 or arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    select coalesce("rules:wdays"/*, 5-days work week: array[1,1,1,1,1,0,0]*/) from users where user_id = (attrs).user_id
		into u_wdays;
	    if( u_wdays is null or u_wdays[arg] = 1 ) then
		update routes set author_id=rlogin, days[arg] = 1
		    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
		rc := 1;
	    else
		raise notice '% unables to set days[%]=1 to the route (user_id=%, account_idm%, cycle_id=%), please, check users.rules:wdays rules.', 
		    fcesig, arg, (attrs).user_id, (attrs).account_id, (attrs).cycle_id;
	    end if;
	end if;
    elsif( cmd = 'drop/day') then
	if( arg is null or arg < 1 or arg > 7 ) then
	    raise exception '% invalid day number!', fcesig;
	else
	    update routes set author_id=rlogin, days[arg] = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    elsif( cmd = 'remove' ) then
	update routes set author_id=rlogin, hidden = 1
	    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	rc := 1;
    elsif( cmd = 'restore' ) then
	update routes set author_id=rlogin, hidden = 0
	    where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	rc := 1;
    elsif( cmd = 'add' ) then
	select hidden from routes where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id
	    into x;
	if( x is null ) then
	    insert into routes(user_id, cycle_id, account_id, author_id)
		values((attrs).user_id, (attrs).cycle_id, (attrs).account_id, rlogin);
	    rc := 1;
	elsif( x = 1 ) then
	    update routes set author_id=rlogin, days=array[0,0,0,0,0,0,0], weeks=array[0,0,0,0], hidden = 0
		where user_id = (attrs).user_id and account_id = (attrs).account_id and cycle_id = (attrs).cycle_id;
	    rc := 1;
	end if;
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['user_id',(attrs).user_id,'cycle_id',(attrs).cycle_id,'account_id',(attrs).account_id,
	    'arg',arg::varchar,'out:rc',rc::varchar]));

    return rc;
end;
$BODY$ language plpgsql;

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
    elsif d_code = 'confirmation' then
	select h.account_id, u.lang_id, target_id from h_confirmation h, users u
	    where doc_id = (opt).doc_id and h.user_id=u.user_id
	into a_id, u_lang, t_pid;
    else
	raise exception '% invalid input attribute!', fcesig;
    end if;
    if( a_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    select descr from users where user_id=rlogin
	into author_name;

    insert into targets (target_id, target_type_id, subject, body, b_date, e_date, author_id, account_ids, image, "immutable", pid)
	values(t_id, case when (opt).strict = 1 then 'target:strict' else 'target:normal' end, (opt).sub, 
	    "L10n_format_a"(u_lang,'targets','',d_code,array['fix_date',"L"(current_date),'msg',(opt).msg,'u_name',coalesce(author_name,rlogin)],(opt).msg), 
	    current_date, current_date + "paramInteger"('target:depth'), rlogin, array[a_id::varchar], blob_id, 1, t_pid);

    if blob_id is not null and (select count(*) from thumbnail_stream where photo=blob_id) = 0 then
	insert into thumbnail_stream(photo) 
	    values(blob_id);
    end if;

    perform content_add('targets_compliance', '', '', '');

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'add/'||d_code, hstore(array['target_id',t_id,'subject',(opt).sub,'body',(opt).msg,'strict',(opt).strict::varchar,'author_id',
	    rlogin,'doc_id',(opt).doc_id,'blob_id',blob_id::varchar]));

    return t_id;
end;
$BODY$ language plpgsql;

create or replace function console.req_ticket(rlogin uid_t, /*attrs:*/ u_id uid_t, i_id uid_t, n note_t, c bool_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    t_id uid_t;
    d descr_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( u_id is null or i_id is null or c is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    t_id := nextval('seq_tickets');
    select descr from issues where issue_id=i_id into d;

    insert into tickets (ticket_id, user_id, issue_id, note, author_id, closed, inserted_ts)
	values(t_id, u_id, i_id, n, rlogin, c, current_timestamp);

    perform evmail_add(u_id, 'ticket/caption'||case c when 1 then ':closed' else '' end, 'ticket/body'||case c when 1 then ':closed' else '' end, 
	3::smallint /*normal*/, array['ticket_id',t_id,'inserted_ts',"L"(current_timestamp),'doc_note',n,'issue',d]);

    if( c = 0 ) then
	insert into mail_stream (rcpt_to, cap, msg)
	    values (string_to_array("paramUID"('srv:bcc'),','), format('OMOBUS: Ticket #%s (user_id: %s)', t_id, u_id), 
		format(E'Registered a new unclosed ticket #%s (user_id: %s): %s.\r\n%s', t_id, u_id, d, n));
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'set', hstore(array['user_id',u_id,'issue_id',i_id,'doc_note',n,'closed',c::varchar]));

    return 0;
end;
$BODY$ language plpgsql;

create or replace function console.req_wish(rlogin uid_t, cmd code_t, /*attrs:*/ a_id uid_t, u_id uid_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( cmd not in ('validate','reject') ) then
	raise exception '% doesn''t support [%] command.', fcesig, cmd;
    end if;
    if( a_id is null or u_id is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( cmd = 'validate' ) then
	update j_wishes set validator_id = rlogin, validated = 1
	    where account_id = a_id and user_id = u_id;
    elsif( cmd = 'reject' ) then
	update j_wishes set hidden = 1
	    where account_id = a_id and user_id = u_id;
    end if;

    select descr from users where user_id = rlogin
	into auth;
    select descr, address from accounts where account_id = a_id
	into a_name, a_address;

    perform evmail_add(u_id, 'wish/caption:'||cmd, 'wish/body:'||cmd, case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, array[
	'a_name',a_name,'address',a_address,'u_name',case when auth is null then lower(rlogin) else auth end]);

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['account_id',a_id,'user_id',u_id]));

    return 0;
end;
$BODY$ language plpgsql;

create or replace function console.req_zstatus(rlogin uid_t, cmd code_t, cookie uuid, note note_t) returns int
as $BODY$
declare
    stack text; fcesig text;
    zrows int;
    author descr_t;
    u_id uid_t;
    a_name descr_t;
    a_address address_t;
    a_type descr_t;
    p_date date_t;
    f_date date_t;
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');
    cmd := lower(cmd);
    note := NIL(trim(note));

    if( cmd not in ('accept','reject') ) then
	raise exception '% doesn''t support [%] command.', fcesig, cmd;
    end if;
    if( cookie is null or (cmd = 'reject' and note is null)) then
	raise exception '% invalid input attribute.', fcesig;
    end if;

    if( cmd = 'accept' ) then
	update j_user_activities set zstatus = 'accepted', znote = note
	    where guid = cookie and (zstatus is null or zstatus <> 'accepted') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    elsif( cmd = 'reject' ) then
	update j_user_activities set zstatus = 'rejected', znote = note
	    where guid = cookie and (zstatus is null or zstatus <> 'rejected') and b_dt is not null and e_dt is not null;
	GET DIAGNOSTICS zrows = ROW_COUNT;
    end if;

    if( zrows > 0 ) then
	select j.user_id, a.descr, a.address, t.descr, j.route_date, j.fix_date from j_user_activities j, activity_types t, accounts a
	    where j.guid = cookie and j.account_id = a.account_id and j.activity_type_id = t.activity_type_id
	into u_id, a_name, a_address, a_type, p_date, f_date;

	select descr from users 
	    where user_id = rlogin
	into author;

	if( f_date is not null ) then
	    perform content_add('tech_route', u_id, f_date, f_date);
	end if;
	if( p_date is not null and (f_date is null or f_date <> p_date) ) then
	    perform content_add('tech_route', u_id, p_date, p_date);
	end if;

	perform evmail_add(u_id, format('zstatus/caption:%s', cmd), 
	    format('zstatus/body:%s', case when cmd = 'reject' then cmd else cmd || (case when note is null then '1' else '0' end) end), 
	    case when cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array['a_name',a_name,'address',a_address,'fix_date',"L"(f_date),'u_name',case when author is null then lower(rlogin) else author end,
		'a_type',lower(a_type),'note',note]);
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, cmd, hstore(array['guid',cookie::varchar,'note',note,'zrows',zrows::varchar]));

    return zrows;
end;
$BODY$ language plpgsql;


create or replace function console.ses_create(p json) returns uid_t as
$body$
declare
    sid uid_t;
    erpid uid_t;
    username uid_t;
    ip hostname_t;
    lt int32_t;
begin
    sid := p ->> 'sid';
    erpid := p ->> 'erpid';
    username := p ->> 'username';
    ip := p ->> 'ip';
    lt := p ->> 'lifetime';
    if( sid is null or username is null or ip is null ) then
	sid := null;
    elsif( erpid is not null and (select count(*) from users where user_id=erpid and hidden=0) = 0 ) then
	sid := null;
    else
	insert into console.sessions(ses_id, u_name, u_id, ses_ip, params, lifetime) 
	    values(sid, username, erpid, ip, p, case when lt is null then 600 else lt end);
    end if;
    return sid;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_get(sid uid_t, ip hostname_t, out p json, out "obsolete" bool_t) as
$body$
declare
    x hostname_t;
begin
    select params, ses_ip, case when (extract(epoch from (current_timestamp - access_ts)))::int32_t > lifetime then 1 else 0 end from console.sessions 
	where ses_id = sid and closed = 0 into p, x, "obsolete";
    if( x = ip ) then
	update console.sessions set access_ts=current_timestamp where ses_id = sid and closed = 0;
	if( "obsolete" = 1) then
	    update console.sessions set closed=1 where ses_id = sid and closed = 0;
	end if;
    end if;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_destroy(sid uid_t, ip hostname_t) returns json as
$body$
declare
    p json;
    x hostname_t;
begin
    select params, ses_ip from console.sessions where ses_id = sid and closed = 0 into p, x;
    if( x = ip ) then
	update console.sessions set closed=1 where ses_id = sid and closed = 0;
    end if;
    return p;
end;
$body$
language plpgsql volatile;

create or replace function console.ses_gc() returns table(sid uid_t, ip hostname_t, username uid_t) as
$body$
begin
    for sid, ip, username in
	select ses_id, ses_ip, u_name from console.sessions where closed=0 and (extract(epoch from (current_timestamp - access_ts)))::int32_t > lifetime
    loop
	update console.sessions set closed = 1, gc = 1 where ses_id = sid;
	return next;
    end loop;
end;
$body$
language plpgsql volatile;
