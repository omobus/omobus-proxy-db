/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema streams;

create sequence streams.seq_mail_stream;
create sequence streams.seq_sms_stream;
create sequence streams.seq_spam_stream;


create table streams.sms_stream (
    ev_id		int64_t		not null primary key default nextval('streams.seq_sms_stream'),
    sms_from		phone_t 	null,
    rcpt_to		phone_t		not null,
    msg			varchar(256)	not null,
    step		int32_t 	not null default 0,
    inserted_ts		ts_auto_t 	not null,
    sent_ts		ts_t 		null,
    msg_id 		text 		null
);

create index i_sent_ts_step_sms_stream on streams.sms_stream (step, sent_ts);


create table streams.spam_stream (
    spam_id		int64_t 	not null primary key default nextval('streams.seq_spam_stream'),
    spam_code 		code_t 		not null,
    attrs 		hstore 		null,
    inserted_ts 	ts_auto_t 	not null,
    spam_ts 		ts_t 		null
);

create or replace function streams.spam_add(_code code_t, _attrs hstore)
    returns int
as $BODY$
declare
    r int;
begin
    insert into streams.spam_stream(spam_code, attrs)
	values(_code, _attrs);
    GET DIAGNOSTICS r = ROW_COUNT;
    return r;
end;
$BODY$ language plpgsql;
