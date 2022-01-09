/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

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
	    values (string_to_array("paramText"('srv:push'),','), format('OMOBUS: Ticket #%s (user_id: %s)', t_id, u_id), 
		format(E'Registered a new unclosed ticket #%s (user_id: %s): %s.\r\n%s', t_id, u_id, d, n));
    end if;

    insert into console.requests(req_login, req_type, status, attrs)
	values(rlogin, fcesig, 'set', hstore(array['user_id',u_id,'issue_id',i_id,'doc_note',n,'closed',c::varchar]));

    return 0;
end;
$BODY$ language plpgsql;
