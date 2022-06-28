/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema logs;

create sequence logs.seq_consents;

create table logs.consents (
    log_id 		int64_t 	not null primary key default nextval('logs.seq_consents'),
    contact_id 		uid_t 		null,
    consent_dt 		datetime_t 	not null,
    consent_data 	blob_t 		null,
    consent_type 	varchar(32) 	null check(consent_type in ('application/pdf')),
    consent_status 	varchar(24) 	null check(consent_status in ('collecting','collecting_and_informing')),
    author_id 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null
);

create trigger trig_lock_update before update on logs.consents for each row execute procedure tf_lock_update();

create or replace function logs.tf_protect_consents() returns trigger as
$body$
declare
    f int = 0;
begin
    if( TG_OP = 'UPDATE') then
	if coalesce(new.consent_data,0/*InvalidOid*/) <> coalesce(old.consent_data,0/*InvalidOid*/) then
	    f := 1;
	end if;
    elsif( TG_OP = 'INSERT') then
	if new.consent_data is not null then
	    f := 1;
	end if;
    end if;

    if f then
	insert into logs.consents(contact_id, consent_dt, consent_data, consent_type, consent_status, author_id)
	    values(new.contact_id, new.consent_dt, new.consent_data, new.consent_type, new.consent_status, new.author_id);
    end if;

    return new;
end;
$body$
language 'plpgsql';

create trigger trig_protect_consent after insert or update on contacts for each row execute procedure logs.tf_protect_consents();

