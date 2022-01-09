/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create or replace function console.req_wish(_login uid_t, _reqdt datetime_t, _cmd code_t, /*attrs:*/ _aid uid_t, _uid uid_t) 
    returns int
as $BODY$
declare
    stack text; fcesig text;
    hs hstore;
    updated_rows int = 0;
    auth descr_t;
    a_name descr_t;
    a_address address_t;
    cid uid_t;
    tmp bool_t;
    d int2[];
    w int2[];
begin
    GET DIAGNOSTICS stack = PG_CONTEXT;
    fcesig := substring(stack from 'function console\.(.*?)\(');

    if( _cmd not in ('validate','reject') ) then
	raise exception '% doesn''t support [%] command! Accepted commands are [validate|reject].', fcesig, _cmd;
    end if;
    if( _aid is null or _uid is null ) then
	raise exception '% invalid input attribute!', fcesig;
    end if;

    if( _cmd = 'validate' ) then
	select cycle_id from route_cycles
	    where (status is null or status = 'inprogress') and hidden = 0
	order by b_date
	into cid;

	if( cid is not null ) then
	    select hidden from routes 
		where cycle_id = cid and account_id = _aid and user_id = _uid
	    into tmp;
	    select days, weeks from j_wishes
		where account_id = _aid and user_id = _uid
	    into d, w;
	    if( tmp is null ) then
		insert into routes(user_id, cycle_id, account_id, days, weeks, author_id)
		    values(_uid, cid, _aid, d, w, _login);
	    else
		update routes set days = d, weeks = w, author_id = _login, hidden = 0
		    where cycle_id = cid and account_id = _aid and user_id = _uid;
	    end if;
	end if;

	update j_wishes set validator_id = _login, validated = 1, hidden = 0, attrs = case when cid is null then null else hstore(array['cycle_id',cid]) end
	    where account_id = _aid and user_id = _uid and validated = 0;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;
    elsif( _cmd = 'reject' ) then
	select cycle_id from route_cycles
	    where (status is null or status = 'inprogress') and hidden = 0 and cycle_id = (
		select attrs->'cycle_id' from j_wishes where account_id = _aid and user_id = _uid and hidden = 0 and attrs is not null
	    )
	order by b_date
	into cid;

	if( cid is not null ) then
	    update routes set hidden = 1
		where cycle_id = cid and account_id = _aid and user_id = _uid and hidden = 0 and
		    format('%s:%s',array_to_string(weeks,''),array_to_string(days,'')) = (
			select format('%s:%s',array_to_string(weeks,''),array_to_string(days,'')) from j_wishes 
			    where account_id = _aid and user_id = _uid
		    );
	end if;

	update j_wishes set hidden = 1
	    where account_id = _aid and user_id = _uid and hidden = 0;
	GET DIAGNOSTICS updated_rows = ROW_COUNT;
    end if;

    if updated_rows > 0 then
	select descr from users where user_id = _login
	    into auth;
	select descr, address from accounts where account_id = _aid
	    into a_name, a_address;

	perform evmail_add(
	    _uid, 
	    'wish/caption:'||_cmd, 
	    'wish/body:'||_cmd, 
	    case when _cmd = 'reject' then 2::smallint /*high*/ else 3::smallint /*normal*/ end, 
	    array[
		'a_name',a_name,
		'address',a_address,
		'u_name',case when auth is null then lower(_login) else auth end
	    ]
	);
    end if;

    hs := hstore(array['user_id',_uid]);
    hs := hs || hstore(array['account_id',_aid]);
    if cid is not null  then
	hs := hs || hstore(array['cycle_id',cid]);
    end if;
    hs := hs || hstore(array['_updated_rows',updated_rows::varchar]);

    insert into console.requests(req_login, req_type, req_dt, status, attrs)
	values(_login, fcesig, _reqdt, _cmd, hs);

    return updated_rows;
end;
$BODY$ language plpgsql;
