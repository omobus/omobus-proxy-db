/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema chatbots;

create sequence chatbots.seq_feedbacks;
create sequence chatbots.seq_photos;

create or replace function chatbots.tf_pinned_ts() returns trigger as
$body$
begin
    if old.pinned_id is null and new.pinned_id is not null then
	new.pinned_ts = current_timestamp;
    elsif old.pinned_id is not null and new.pinned_id is null then
	new.pinned_ts = null;
    elsif old.pinned_id is not null and new.pinned_id is not null and old.pinned_id != new.pinned_id then
	new.pinned_ts = current_timestamp;
    end if;
    return new;
end;
$body$
language 'plpgsql';

create table chatbots.chats (
    bot_type 		code_t 		not null,
    bot_id 		uid_t 		not null,
    chat_id 		uid_t 		not null,
    from_id 		uid_t 		not null,
    account_ids 	uids_t 		null,
    lang_id 		lang_t 		not null default 'ru',
    status 		text 		not null default 'unknown',
    is_bot 		bool_t 		null,
    banned 		bool_t 		not null default 0, -- banned by chatbot admins
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    inbound_ts 		ts_t 		null,
    outbound_ts 	ts_t 		null,
    inprogress_command 	text 		null,
    attrs 		hstore		null,
    pinned_id 		uid_t 		null,
    pinned_ts 		ts_t 		null,
    primary key(bot_type, bot_id, chat_id)
);

create trigger trig_updated_ts before update on chatbots.chats for each row execute procedure tf_updated_ts();
create trigger trig_pinned_ts before update on chatbots.chats for each row execute procedure chatbots.tf_pinned_ts();

create table chatbots.feedbacks (
    fb_id 		int64_t 	not null primary key default nextval('chatbots.seq_feedbacks'),
    bot_type 		code_t 		not null,
    bot_id 		uid_t 		not null,
    chat_id 		uid_t 		not null,
    account_id 		uid_t 		null, -- message only for destination account
    cookie 		uid_t 		null, -- код объединения в нескольких записей созданных в ходе обработки одного входного запроса
    msg 		text 		not null,
    priority 		int2 		not null default 3 check (priority between 1 /* highest-priority*/ and 5 /* lowest-priority */),
    msg_type 		varchar(10) 	not null check(msg_type in('text/html','text/plain')),
    reply_to_message_id uid_t 		null,
    step 		int32_t 	not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    sent_ts 		ts_t 		null,
    message_id 		uid_t 		null
);

create index i_bot_keys_feedbacks on chatbots.feedbacks(bot_type, bot_id);

create table chatbots.photos (
    photo_id 		int64_t 	not null primary key default nextval('chatbots.seq_photos'),
    bot_type 		code_t 		not null,
    bot_id 		uid_t 		not null,
    chat_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    cookie 		uid_t 		null,
    photo 		blob_t 		not null,
    width 		int32_t 	not null,
    height 		int32_t 	not null,
    length 		int32_t 	not null,
    caption 		text 		null,
    message_id 		uid_t 		not null,
    hashsum 		uid_t 		not null,
    inserted_ts 	ts_auto_t 	not null
);

create trigger trig_lock_update before update on chatbots.photos for each row execute procedure tf_lock_update();
create unique index i_hashsum_photos on chatbots.photos (hashsum);
