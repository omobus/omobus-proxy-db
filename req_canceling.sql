/* Copyright (c) 2006 - 2019 omobus-proxy-db authors, see the included COPYRIGHT file. */

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
