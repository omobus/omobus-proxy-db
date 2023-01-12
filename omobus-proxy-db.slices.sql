/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema slices;

create table slices.accounts (
    slice_date 		date_t 		not null,
    account_id 		uid_t 		not null,
    code 		code_t 		null,
    descr 		descr_t 	not null,
    address 		address_t 	not null,
    region_id 		uid_t		null,
    city_id 		uid_t		null,
    rc_id 		uid_t		null,
    chan_id 		uid_t 		null,
    poten_id 		uid_t 		null,
    latitude 		gps_t 		null,
    longitude 		gps_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    primary key (slice_date, account_id)
);

create trigger trig_lock_update before update on slices.accounts for each row execute procedure tf_lock_update();

create table slices.agreements1 (
    slice_date 		date_t 		not null,
    account_id		uid_t		not null,
    placement_id 	uid_t 		not null,
    posm_id 		uid_t 		not null,
    strict 		bool_t 		not null default 1,
    cookie 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    primary key (slice_date, account_id, placement_id, posm_id)
);

create index i_exist_agreements1 on slices.agreements1(slice_date, account_id);
create trigger trig_lock_update before update on slices.agreements1 for each row execute procedure tf_lock_update();

create table slices.agreements2 (
    slice_date 		date_t 		not null,
    account_id		uid_t		not null,
    prod_id 		uid_t 		not null,
    facing 		int32_t 	null check(facing > 0),
    strict 		bool_t 		not null default 1,
    cookie 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    primary key (slice_date, account_id, prod_id)
);

create index i_exist_agreements2 on slices.agreements2(slice_date, account_id);
create trigger trig_lock_update before update on slices.agreements2 for each row execute procedure tf_lock_update();

create table slices.agreements3 (
    slice_date 		date_t 		not null,
    account_id		uid_t		not null,
    prod_id 		uid_t 		not null,
    stock 		int32_t 	not null check(stock > 0),
    strict 		bool_t 		not null default 1,
    cookie 		uid_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    primary key (slice_date, account_id, prod_id)
);

create index i_exist_agreements3 on slices.agreements3(slice_date, account_id);
create trigger trig_lock_update before update on slices.agreements3 for each row execute procedure tf_lock_update();

create table slices.matrices(
    slice_date 		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    row_no 		int32_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (slice_date, account_id, prod_id)
);

create index i_exist_matrices on slices.matrices(slice_date, account_id);
create trigger trig_lock_update before update on slices.matrices for each row execute procedure tf_lock_update();

create table slices.my_accounts (
    slice_date 		date_t 		not null,
    user_id 		uid_t 		not null,
    account_id		uid_t		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (slice_date, user_id, account_id)
);

create index i_exist_my_accounts on slices.my_accounts(slice_date, user_id);
create index i_slice_date_my_accounts on slices.my_accounts(slice_date);
create trigger trig_lock_update before update on slices.my_accounts for each row execute procedure tf_lock_update();

create table slices.outlet_stocks (
    slice_date 		date_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    s_date 		date_t 		not null,
    stock 		int32_t 	not null check(stock > 0),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key(slice_date, account_id, prod_id)
);

create index i_exist_outlet_stocks on slices.outlet_stocks(slice_date, account_id);
create trigger trig_lock_update before update on slices.outlet_stocks for each row execute procedure tf_lock_update();
