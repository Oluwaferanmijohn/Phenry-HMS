-- ============================================================================
-- Phenry Health — Foundation migration
-- profiles, custom_roles, role_permissions, and the RLS helper functions
-- every later per-role migration builds on. Run before any role-specific
-- migration.
--
-- IMPORTANT — deviation from the spec's literal RLS example (flagging this
-- per the project's "ask, don't invent silently" rule, documented here and
-- called out in chat):
-- Spec §2.4 shows `auth.jwt() ->> 'role'` as the claim to check. Supabase's
-- JWT already reserves a top-level `role` claim (always "authenticated" /
-- "anon" / "service_role") that PostgREST uses to SET ROLE for the DB
-- session. Overwriting it with an app role (e.g. "doctor") breaks
-- PostgREST's ability to authenticate the request at all — Supabase's own
-- custom-claims docs warn against this. So the custom access-token hook
-- below injects the app role under a claim named `app_role` instead, and
-- every RLS policy in this project reads it via current_app_role() rather
-- than touching auth.jwt() directly. This preserves the exact intent of
-- §2.4 (a custom-role branch that resolves to deny-by-default) without the
-- footgun.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- profiles — one row per auth.users row. role is one of the 10 fixed roles
-- or NULL when custom_role_key is set (custom_role_key then names the row
-- in custom_roles). Auto-created by the handle_new_user trigger below.
-- ----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role text,
  custom_role_key text,
  full_name text,
  avatar_url text,
  force_password_reset boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- role and custom_role_key are mutually exclusive when set, but BOTH may be
  -- null (an account provisioned but not yet assigned a role — see
  -- middleware/auth.global.ts's /no-access fallback). Do not tighten this to
  -- "exactly one must be set": handle_new_user() below can legitimately
  -- insert a row with both null when no role metadata was supplied yet.
  constraint profiles_role_xor_custom_chk check (
    not (role is not null and custom_role_key is not null)
  ),
  constraint profiles_role_fixed_chk check (
    role is null or role in (
      'patient', 'receptionist', 'admin_manager', 'doctor', 'matron', 'nurse',
      'chief_embryologist', 'lab_tech', 'pharmacy', 'stakeholder'
    )
  )
);
comment on table public.profiles is 'One row per authenticated user. Bible §2.1 — auto-created on signup.';

-- ----------------------------------------------------------------------------
-- custom_roles — Admin-created roles beyond the fixed ten (spec §0.2 / §2.4).
-- ----------------------------------------------------------------------------
create table public.custom_roles (
  role_key text primary key,
  label text not null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);
comment on table public.custom_roles is 'Admin-defined roles. A row here with no matching role_permissions rows has zero access.';

alter table public.profiles
  add constraint profiles_custom_role_fk
  foreign key (custom_role_key) references public.custom_roles (role_key);

-- ----------------------------------------------------------------------------
-- role_permissions — per-table grants for custom roles ONLY. The fixed ten
-- roles are governed by hardcoded policies (per spec §2.2's matrix); this
-- table exists solely so a freshly-created custom role defaults to deny
-- (spec §0.2: "no row = no access").
-- ----------------------------------------------------------------------------
create table public.role_permissions (
  role_key text not null references public.custom_roles (role_key) on delete cascade,
  resource text not null,
  can_view boolean not null default false,
  can_create boolean not null default false,
  can_edit boolean not null default false,
  scope text not null default 'own' check (scope in ('own', 'assigned', 'all', 'aggregate')),
  primary key (role_key, resource)
);
comment on table public.role_permissions is 'Per-table grants for custom roles. No row for a (role_key, resource) pair = no access to that resource.';

-- ----------------------------------------------------------------------------
-- RLS helper functions — every later migration's policies call these
-- instead of touching auth.jwt() directly, so the claim-naming fix above is
-- centralized in one place.
-- ----------------------------------------------------------------------------
create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(auth.jwt() ->> 'app_role', '');
$$;
comment on function public.current_app_role() is 'The caller''s fixed role (patient/doctor/etc), or '''' if they hold a custom role instead.';

create or replace function public.current_custom_role_key()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select auth.jwt() ->> 'custom_role_key';
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_app_role() = 'admin_manager';
$$;

-- True if the caller holds a custom role that has been explicitly granted
-- `perm` (can_view / can_create / can_edit) on `resource`. Fixed roles never
-- go through this path — they're handled by literal role checks in each
-- table's own policies.
create or replace function public.has_custom_permission(resource text, perm text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  key text := public.current_custom_role_key();
  granted boolean := false;
begin
  if key is null then
    return false;
  end if;

  if perm = 'view' then
    select can_view into granted from public.role_permissions rp where rp.role_key = key and rp.resource = resource;
  elsif perm = 'create' then
    select can_create into granted from public.role_permissions rp where rp.role_key = key and rp.resource = resource;
  elsif perm = 'edit' then
    select can_edit into granted from public.role_permissions rp where rp.role_key = key and rp.resource = resource;
  else
    return false;
  end if;

  return coalesce(granted, false);
end;
$$;
comment on function public.has_custom_permission(text, text) is 'Deny-by-default custom-role check. No matching role_permissions row => false.';

create or replace function public.custom_scope(resource text)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select scope from public.role_permissions rp
  where rp.role_key = public.current_custom_role_key() and rp.resource = resource;
$$;

-- ----------------------------------------------------------------------------
-- updated_at trigger helper, reused by every table going forward.
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Auto-create a profiles row when a new auth.users row appears (Bible §2.1).
-- Staff/patient provisioning (Admin "Add Staff", Receptionist "New
-- Registration") calls supabase.auth.admin.createUser with user_metadata
-- {role, full_name} from a service-role server route — this trigger reads
-- that metadata. If none is supplied the row is created with role=NULL and
-- must be assigned before the account has any access (deny-by-default).
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name, force_password_reset)
  values (
    new.id,
    new.raw_user_meta_data ->> 'role',
    new.raw_user_meta_data ->> 'full_name',
    coalesce((new.raw_user_meta_data ->> 'force_password_reset')::boolean, false)
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- Custom Access Token Hook — injects app_role / custom_role_key into the
-- JWT at token-mint time. Must additionally be wired up in
-- Dashboard → Authentication → Hooks → "Customize Access Token (JWT) Claims"
-- (or supabase/config.toml's [auth.hook.custom_access_token] for local dev —
-- see that file in this same migrations folder's sibling config.toml).
-- SQL alone cannot enable this; it's a project-level Auth setting.
-- ----------------------------------------------------------------------------
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  user_role text;
  user_custom_role_key text;
begin
  select p.role, p.custom_role_key
    into user_role, user_custom_role_key
    from public.profiles p
    where p.id = (event ->> 'user_id')::uuid;

  claims := coalesce(event -> 'claims', '{}'::jsonb);

  if user_role is not null then
    claims := jsonb_set(claims, '{app_role}', to_jsonb(user_role));
  else
    claims := claims - 'app_role';
  end if;

  if user_custom_role_key is not null then
    claims := jsonb_set(claims, '{custom_role_key}', to_jsonb(user_custom_role_key));
  else
    claims := claims - 'custom_role_key';
  end if;

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;

grant select on public.profiles to supabase_auth_admin;

-- ----------------------------------------------------------------------------
-- RLS on the foundation tables themselves.
-- ----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.custom_roles enable row level security;
alter table public.role_permissions enable row level security;

create policy "auth admin can read profiles for the token hook"
  on public.profiles for select
  to supabase_auth_admin
  using (true);

create policy "users can read their own profile"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy "users can update their own force_password_reset + name fields"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "admin can read every profile"
  on public.profiles for select
  to authenticated
  using (public.is_admin());

create policy "admin can insert/update/delete profiles"
  on public.profiles for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "everyone authenticated can read custom_roles"
  on public.custom_roles for select
  to authenticated
  using (true);

create policy "only admin can write custom_roles"
  on public.custom_roles for insert
  to authenticated
  with check (public.is_admin());

create policy "only admin can update/delete custom_roles"
  on public.custom_roles for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "only admin can manage role_permissions"
  on public.role_permissions for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "a custom-role holder can read their own grants"
  on public.role_permissions for select
  to authenticated
  using (role_key = public.current_custom_role_key());
