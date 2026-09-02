-- READ-ONLY schema audit for the Phenry Health Supabase project.
-- Returns structure and access rules only. It does not read patient/business rows.
-- Run in Supabase Dashboard > SQL Editor, then download/copy the single JSON result.

with
database_info as (
  select jsonb_build_object(
    'database', current_database(),
    'postgres_version', current_setting('server_version'),
    'current_role', current_user
  ) as item
),
extensions as (
  select coalesce(jsonb_agg(
    jsonb_build_object('name', extname, 'version', extversion)
    order by extname
  ), '[]'::jsonb) as items
  from pg_extension
),
table_objects as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', n.nspname,
      'name', c.relname,
      'kind', case c.relkind
        when 'r' then 'table'
        when 'p' then 'partitioned table'
        when 'v' then 'view'
        when 'm' then 'materialized view'
        when 'f' then 'foreign table'
        else c.relkind::text
      end,
      'rls_enabled', c.relrowsecurity,
      'rls_forced', c.relforcerowsecurity
    ) order by n.nspname, c.relname
  ), '[]'::jsonb) as items
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p', 'v', 'm', 'f')
),
columns as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', table_schema,
      'table', table_name,
      'position', ordinal_position,
      'name', column_name,
      'data_type', data_type,
      'udt_name', udt_name,
      'nullable', is_nullable,
      'default', column_default,
      'identity', is_identity,
      'generated', is_generated
    ) order by table_schema, table_name, ordinal_position
  ), '[]'::jsonb) as items
  from information_schema.columns
  where table_schema = 'public'
),
constraints as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', n.nspname,
      'table', c.relname,
      'name', con.conname,
      'type', case con.contype
        when 'p' then 'primary key'
        when 'f' then 'foreign key'
        when 'u' then 'unique'
        when 'c' then 'check'
        when 'x' then 'exclusion'
        else con.contype::text
      end,
      'definition', pg_get_constraintdef(con.oid, true),
      'validated', con.convalidated
    ) order by n.nspname, c.relname, con.conname
  ), '[]'::jsonb) as items
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
),
indexes as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', schemaname,
      'table', tablename,
      'name', indexname,
      'definition', indexdef
    ) order by schemaname, tablename, indexname
  ), '[]'::jsonb) as items
  from pg_indexes
  where schemaname = 'public'
),
policies as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', schemaname,
      'table', tablename,
      'name', policyname,
      'permissive', permissive,
      'roles', to_jsonb(roles),
      'command', cmd,
      'using', qual,
      'with_check', with_check
    ) order by schemaname, tablename, policyname
  ), '[]'::jsonb) as items
  from pg_policies
  where schemaname in ('public', 'storage')
),
triggers as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', event_object_schema,
      'table', event_object_table,
      'name', trigger_name,
      'event', event_manipulation,
      'timing', action_timing,
      'orientation', action_orientation,
      'statement', action_statement
    ) order by event_object_schema, event_object_table, trigger_name, event_manipulation
  ), '[]'::jsonb) as items
  from information_schema.triggers
  where event_object_schema in ('public', 'storage')
),
functions as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', n.nspname,
      'name', p.proname,
      'identity_arguments', pg_get_function_identity_arguments(p.oid),
      'result', pg_get_function_result(p.oid),
      'language', l.lanname,
      'security_definer', p.prosecdef,
      'volatility', p.provolatile,
      'definition', pg_get_functiondef(p.oid)
    ) order by n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)
  ), '[]'::jsonb) as items
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_language l on l.oid = p.prolang
  where n.nspname = 'public'
    and p.prokind in ('f', 'p')
    and not exists (
      select 1
      from pg_depend d
      join pg_extension e on e.oid = d.refobjid
      where d.classid = 'pg_proc'::regclass
        and d.objid = p.oid
        and d.deptype = 'e'
    )
),
views as (
  select coalesce(jsonb_agg(
    jsonb_build_object('schema', schemaname, 'name', viewname, 'definition', definition)
    order by schemaname, viewname
  ), '[]'::jsonb) as items
  from pg_views
  where schemaname = 'public'
),
enums as (
  select coalesce(jsonb_agg(
    jsonb_build_object('schema', n.nspname, 'name', t.typname, 'values', enum_values.items)
    order by n.nspname, t.typname
  ), '[]'::jsonb) as items
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  cross join lateral (
    select jsonb_agg(e.enumlabel order by e.enumsortorder) as items
    from pg_enum e
    where e.enumtypid = t.oid
  ) enum_values
  where n.nspname = 'public' and t.typtype = 'e'
),
domains as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', n.nspname,
      'name', t.typname,
      'data_type', format_type(t.typbasetype, t.typtypmod),
      'nullable', case when t.typnotnull then false else true end,
      'default', t.typdefault
    )
  ), '[]'::jsonb) as items
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public'
    and t.typtype = 'd'
),
sequences as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', sequence_schema,
      'name', sequence_name,
      'data_type', data_type,
      'start', start_value,
      'increment', increment,
      'minimum', minimum_value,
      'maximum', maximum_value,
      'cycle', cycle_option
    ) order by sequence_schema, sequence_name
  ), '[]'::jsonb) as items
  from information_schema.sequences
  where sequence_schema = 'public'
),
table_grants as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', table_schema,
      'table', table_name,
      'grantee', grantee,
      'privilege', privilege_type,
      'grantable', is_grantable
    ) order by table_schema, table_name, grantee, privilege_type
  ), '[]'::jsonb) as items
  from information_schema.role_table_grants
  where table_schema in ('public', 'storage')
    and grantee in ('anon', 'authenticated', 'service_role')
),
routine_grants as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'schema', routine_schema,
      'routine', routine_name,
      'grantee', grantee,
      'privilege', privilege_type,
      'grantable', is_grantable
    ) order by routine_schema, routine_name, grantee, privilege_type
  ), '[]'::jsonb) as items
  from information_schema.role_routine_grants
  where routine_schema = 'public'
    and grantee in ('anon', 'authenticated', 'service_role')
),
storage_buckets as (
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'name', name,
      'public', public,
      'file_size_limit', file_size_limit,
      'allowed_mime_types', to_jsonb(allowed_mime_types)
    ) order by name
  ), '[]'::jsonb) as items
  from storage.buckets
),
publications as (
  select coalesce(jsonb_agg(
    jsonb_build_object('publication', pubname, 'schema', schemaname, 'table', tablename)
    order by pubname, schemaname, tablename
  ), '[]'::jsonb) as items
  from pg_publication_tables
  where schemaname = 'public'
),
migration_history as (
  -- Dashboard-created projects may not have CLI migration tracking yet. Avoid
  -- referencing the optional relation directly because PostgreSQL resolves it
  -- before CASE conditions can protect the query.
  select jsonb_build_object(
    'tracking_table_exists', to_regclass('supabase_migrations.schema_migrations') is not null,
    'items', '[]'::jsonb
  ) as item
)
select jsonb_pretty(jsonb_build_object(
  'audit_version', 1,
  'generated_at', now(),
  'database_info', (select item from database_info),
  'extensions', (select items from extensions),
  'tables', (select items from table_objects),
  'columns', (select items from columns),
  'constraints', (select items from constraints),
  'indexes', (select items from indexes),
  'policies', (select items from policies),
  'triggers', (select items from triggers),
  'functions', (select items from functions),
  'views', (select items from views),
  'enums', (select items from enums),
  'domains', (select items from domains),
  'sequences', (select items from sequences),
  'table_grants', (select items from table_grants),
  'routine_grants', (select items from routine_grants),
  'storage_buckets', (select items from storage_buckets),
  'realtime_publications', (select items from publications),
  'migration_history', (select item from migration_history)
)) as schema_snapshot;
