/* Copyright (c) 2006 - 2021 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema slices;

create table slices.matrices(
    slice_date date_t not null,
    account_id uid_t not null,
    prod_id uid_t not null,
    placement_ids uids_t null,
    row_no int32_t null,
    inserted_ts ts_auto_t not null,
    updated_ts ts_auto_t not null,
    primary key (slice_date, account_id, prod_id)
);

create index i_exist_matrices on slices.matrices(slice_date, account_id);
create trigger trig_updated_ts before update on slices.matrices for each row execute procedure tf_updated_ts();

create table slices.agreements1 (
    slice_date 		date_t 		not null,
    account_id		uid_t		not null,
    placement_id 	uid_t 		not null,
    posm_id 		uid_t 		not null,
    strict 		bool_t 		not null default 1,
    cookie 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (slice_date, account_id, placement_id, posm_id)
);

create index i_exist_agreements1 on slices.agreements1(slice_date, account_id);
create trigger trig_updated_ts before update on slices.agreements1 for each row execute procedure tf_updated_ts();

create table slices.agreements2 (
    slice_date 		date_t 		not null,
    account_id		uid_t		not null,
    prod_id 		uid_t 		not null,
    facing 		int32_t 	not null check(facing > 0),
    strict 		bool_t 		not null default 1,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (slice_date, account_id, prod_id)
);

create index i_exist_agreements2 on slices.agreements2(slice_date, account_id);
create trigger trig_updated_ts before update on slices.agreements2 for each row execute procedure tf_updated_ts();
