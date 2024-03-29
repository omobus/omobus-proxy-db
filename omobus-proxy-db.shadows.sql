/* Copyright (c) 2006 - 2022 omobus-proxy-db authors, see the included COPYRIGHT file. */

create schema shadow;

/* In the shadow tables store data received from the distributors. 
 * Everyone IDs (execept distr_id and symlinks.f_id) are in the distributor notation. 
 */

create table shadow.account_params (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    group_price_id 	uid_t 		null,
    locked 		bool_t 		null default 0,
    payment_delay 	int32_t 	null,
    payment_method_id 	uid_t 		null,
    wareh_ids 		uids_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id)
);

create trigger trig_updated_ts before update on shadow.account_params for each row execute procedure tf_updated_ts();

create table shadow.account_prices (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    price 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.account_prices for each row execute procedure tf_updated_ts();

create table shadow.blacklist (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    locked 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.blacklist for each row execute procedure tf_updated_ts();

create table shadow.debts (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    debt 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id)
);

create trigger trig_updated_ts before update on shadow.debts for each row execute procedure tf_updated_ts();

create table shadow.erp_docs (
    distr_id 		uid_t 		not null,
    doc_id 		uid_t 		null,
    erp_id 		uid_t 		not null,
    pid 		uid_t 		null, /* parent erp_id */
    erp_no 		uid_t 		not null,
    erp_dt 		datetime_t 	not null,
    amount 		currency_t 	not null,
    status 		int32_t 	not null default 0 check (status between -1 and 1), /* -1 - delete; 0 - normal; 1 - closed; */
    doc_type 		doctype_t 	not null, /* order, contract, reclamation */
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key (distr_id, erp_id)
);

create trigger trig_updated_ts before update on shadow.erp_docs for each row execute procedure tf_updated_ts();

create table shadow.erp_products (
    distr_id 		uid_t 		not null,
    doc_id 		uid_t 		null,
    erp_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack 		int32_t 	not null,
    qty 		numeric_t 	not null,
    discount 		discount_t 	not null,
    amount 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts		ts_auto_t 	not null,
    primary key (distr_id, erp_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.erp_products for each row execute procedure tf_updated_ts();

create table shadow.floating_prices (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    price 		currency_t 	not null,
    b_date 		date_t 		not null,
    e_date 		date_t 		not null,
    promo 		bool_t 		null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, prod_id, b_date)
);

create trigger trig_updated_ts before update on shadow.floating_prices for each row execute procedure tf_updated_ts();

create table shadow.group_prices (
    distr_id 		uid_t 		not null,
    group_price_id 	uid_t 		not null,
    prod_id 		uid_t 		not null,
    price 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, group_price_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.group_prices for each row execute procedure tf_updated_ts();

create table shadow.mutuals (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    mutual 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id)
);

create trigger trig_updated_ts before update on shadow.mutuals for each row execute procedure tf_updated_ts();

create table shadow.mutuals_history (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    erp_no 		uid_t 		not null,
    erp_dt 		datetime_t 	not null,
    amount 		currency_t 	not null,
    incoming 		bool_t 		not null,
    unpaid 		currency_t 	null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, erp_id)
);

create trigger trig_updated_ts before update on shadow.mutuals_history for each row execute procedure tf_updated_ts();

create table shadow.mutuals_history_products (
    distr_id 		uid_t 		not null,
    erp_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    pack 		int32_t 	not null,
    qty 		numeric_t 	not null,
    discount 		discount_t 	null,
    amount 		currency_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, erp_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.mutuals_history_products for each row execute procedure tf_updated_ts();

create table shadow.permitted_returns (
    distr_id   		uid_t  		not null,
    account_id 		uid_t  		not null,
    prod_id    		uid_t  		not null,
    price 		currency_t 	not null check (price >= 0),
    max_qty    		numeric_t      	null check (max_qty is null or (max_qty >= 0)),
    locked 		bool_t 		null default 0,
    inserted_ts        	ts_auto_t      	not null,
    updated_ts 		ts_auto_t      	not null,
    primary key (distr_id, account_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.permitted_returns for each row execute procedure tf_updated_ts();

create table shadow.restrictions (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    min_qty 		numeric_t 	null check (min_qty is null or (min_qty >= 0)),
    max_qty 		numeric_t 	null check (max_qty is null or (max_qty >= 0)),
    quantum 		numeric_t 	null check (quantum is null or quantum > 0),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.restrictions for each row execute procedure tf_updated_ts();

create table shadow.std_prices (
    distr_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    price 		currency_t 	not null check (price >= 0),
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.std_prices for each row execute procedure tf_updated_ts();

create table shadow.shipments (
    distr_id 		uid_t 		not null,
    account_id 		uid_t 		not null,
    d_date 		date_t 		not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, account_id, d_date)
);

create trigger trig_updated_ts before update on shadow.shipments for each row execute procedure tf_updated_ts();

create table shadow.warehouses (
    distr_id 		uid_t 		not null,
    wareh_id 		uid_t 		not null,
    descr 		descr_t 	not null,
    hidden 		bool_t 		not null default 0,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, wareh_id)
);

create trigger trig_updated_ts before update on shadow.warehouses for each row execute procedure tf_updated_ts();

create table shadow.wareh_stocks (
    distr_id 		uid_t 		not null,
    wareh_id 		uid_t 		not null,
    prod_id 		uid_t 		not null,
    qty 		int32_t 	not null,
    inserted_ts 	ts_auto_t 	not null,
    updated_ts 		ts_auto_t 	not null,
    primary key (distr_id, wareh_id, prod_id)
);

create trigger trig_updated_ts before update on shadow.wareh_stocks for each row execute procedure tf_updated_ts();
