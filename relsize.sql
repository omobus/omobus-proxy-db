select current_date, nspname || '.' || relname, pg_total_relation_size(c.oid) from pg_class c
    left join pg_namespace n on (n.oid = c.relnamespace)
where c.relkind in ('r','i') and nspname !~ '^pg_toast'
order by 3 desc