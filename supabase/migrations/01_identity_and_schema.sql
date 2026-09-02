-- Phenry Health migration 18 — part 1 of 5
-- RUN SEQUENTIALLY. Do not execute this file in parallel with another part.
-- If this part fails, correct the reported issue and rerun this same part before continuing.

begin;
-- ============================================================================
-- Phenry Health — reconciliation, security hardening, and missing migrations
--
-- This migration replaces the missing 00000000000013..16 changes and closes
-- the security/integrity gaps found in the supplied archive. It is deliberately
-- idempotent: it may be applied after 1..12 + 17, or after equivalent fixes
-- were applied manually in a hosted Supabase project.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Identity and authorization: do not trust a stale JWT role, and never let
--    an end user update arbitrary columns in their own profiles row.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists active boolean not null default true;

create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(p.role, '')
  from public.profiles p
  where p.id = auth.uid() and p.active = true;
$$;

create or replace function public.current_custom_role_key()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.custom_role_key
  from public.profiles p
  where p.id = auth.uid() and p.active = true;
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id,role,custom_role_key,full_name,patient_id,force_password_reset,active)
  values(
    new.id,
    nullif(new.raw_user_meta_data->>'role',''),
    nullif(new.raw_user_meta_data->>'custom_role_key',''),
    nullif(trim(new.raw_user_meta_data->>'full_name'),''),
    nullif(new.raw_user_meta_data->>'patient_id',''),
    coalesce((new.raw_user_meta_data->>'force_password_reset')::boolean,false),
    true
  );
  return new;
end;
$$;

drop policy if exists "users can update their own force_password_reset + name fields" on public.profiles;
drop policy if exists "admin can insert/update/delete profiles" on public.profiles;

-- Password-reset completion is the sole self-write path for a protected
-- profile. The Auth user must have been updated after the profile was created.
create or replace function public.complete_password_reset()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1
    from auth.users u
    join public.profiles p on p.id = u.id
    where u.id = auth.uid()
      and p.force_password_reset = true
      and u.updated_at > p.created_at
  ) then
    raise exception 'password update could not be verified';
  end if;

  update public.profiles
  set force_password_reset = false
  where id = auth.uid();
end;
$$;

revoke all on function public.complete_password_reset() from public, anon;
grant execute on function public.complete_password_reset() to authenticated;

-- Staff phone numbers are isolated from the broadly-readable display-name
-- profile rows. Only Admin can manage them; the emergency RPC reads them as a
-- SECURITY DEFINER operation.
create table if not exists public.staff_contacts (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  email text,
  phone text,
  updated_at timestamptz not null default now()
);
alter table public.staff_contacts add column if not exists email text;
alter table public.staff_contacts enable row level security;
drop trigger if exists staff_contacts_set_updated_at on public.staff_contacts;
create trigger staff_contacts_set_updated_at before update on public.staff_contacts
  for each row execute function public.set_updated_at();
drop policy if exists "admin manages staff contacts" on public.staff_contacts;
create policy "admin manages staff contacts" on public.staff_contacts
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "staff reads own contact" on public.staff_contacts;
create policy "staff reads own contact" on public.staff_contacts
  for select to authenticated using (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Missing columns and tables referenced by the current frontend.
-- ---------------------------------------------------------------------------
alter table public.payment_milestones add column if not exists claimed_amount numeric(14,2);
alter table public.payment_milestones add column if not exists claimed_payment_date date;

create or replace function public.enforce_patient_milestone_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.current_app_role()='patient' then
    if new.plan_id is distinct from old.plan_id or new.label is distinct from old.label
      or new.amount is distinct from old.amount or new.due_context is distinct from old.due_context
      or new.approved_on is distinct from old.approved_on or new.approved_by is distinct from old.approved_by
      or new.created_at is distinct from old.created_at then
      raise exception 'patients may only submit payment proof fields';
    end if;
    if new.status <> 'Pending Verification' or nullif(new.proof_url,'') is null
      or new.proof_url not like public.current_patient_id() || '/%'
      or new.claimed_amount is null or new.claimed_amount <= 0 or new.claimed_amount > new.amount
      or new.claimed_payment_date is null or new.claimed_payment_date > current_date then
      raise exception 'invalid payment proof submission';
    end if;
  end if;
  return new;
end;
$$;

alter table public.cycles add column if not exists cycle_manager_id uuid;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'cycles_cycle_manager_fk') then
    alter table public.cycles add constraint cycles_cycle_manager_fk
      foreign key (cycle_manager_id) references public.profiles(id) on delete set null;
  end if;
end $$;

create or replace function public.enforce_cycle_manager_is_nurse()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.cycle_manager_id is not null and not exists (
    select 1 from public.profiles p
    where p.id = new.cycle_manager_id and p.role = 'nurse' and p.active
  ) then
    raise exception 'cycle manager must be an active Nurse';
  end if;
  return new;
end;
$$;
drop trigger if exists cycles_enforce_manager on public.cycles;
create trigger cycles_enforce_manager before insert or update of cycle_manager_id
  on public.cycles for each row execute function public.enforce_cycle_manager_is_nurse();

alter table public.cycle_daily_logs add column if not exists phase text;
alter table public.cycle_daily_logs add column if not exists medication text;
alter table public.cycle_daily_logs add column if not exists milestone text;
alter table public.cycle_daily_logs add column if not exists updated_at timestamptz not null default now();
create table if not exists public.cycle_daily_log_conflicts (
  id uuid primary key default gen_random_uuid(),
  source_log_id uuid not null unique,
  cycle_id uuid not null,
  day int not null,
  original_log jsonb not null,
  archived_at timestamptz not null default now()
);
alter table public.cycle_daily_log_conflicts enable row level security;
drop policy if exists "admin reads archived cycle log conflicts" on public.cycle_daily_log_conflicts;
create policy "admin reads archived cycle log conflicts" on public.cycle_daily_log_conflicts
  for select to authenticated using (public.is_admin());
with ranked as (
  select id, row_number() over (partition by cycle_id,day order by updated_at desc,created_at desc,id desc) as row_rank
  from public.cycle_daily_logs
)
insert into public.cycle_daily_log_conflicts(source_log_id,cycle_id,day,original_log)
select log.id,log.cycle_id,log.day,to_jsonb(log)
from public.cycle_daily_logs log join ranked on ranked.id=log.id
where ranked.row_rank > 1
on conflict(source_log_id) do nothing;
with ranked as (
  select id, row_number() over (partition by cycle_id,day order by updated_at desc,created_at desc,id desc) as row_rank
  from public.cycle_daily_logs
)
delete from public.cycle_daily_logs log using ranked
where ranked.id=log.id and ranked.row_rank > 1;
create unique index if not exists cycle_daily_logs_cycle_day_uq
  on public.cycle_daily_logs(cycle_id, day);
drop trigger if exists cycle_daily_logs_set_updated_at on public.cycle_daily_logs;
create trigger cycle_daily_logs_set_updated_at before update on public.cycle_daily_logs
  for each row execute function public.set_updated_at();

create or replace function public.sync_cycle_day_from_log()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.cycles
  set cycle_day = greatest(cycle_day, new.day)
  where id = new.cycle_id;
  return new;
end;
$$;
drop trigger if exists cycle_daily_logs_sync_cycle_day on public.cycle_daily_logs;
create trigger cycle_daily_logs_sync_cycle_day after insert or update of day
  on public.cycle_daily_logs for each row execute function public.sync_cycle_day_from_log();

alter table public.recovery_beds add column if not exists reserved_for_date date;
alter table public.recovery_beds drop constraint if exists recovery_beds_status_check;
alter table public.recovery_beds add constraint recovery_beds_status_check
  check (status in ('Free', 'Reserved', 'Occupied')) not valid;
alter table public.recovery_beds validate constraint recovery_beds_status_check;

alter table public.cryo_records add column if not exists status text not null default 'Stored';
alter table public.cryo_records add column if not exists used_date date;
alter table public.cryo_records add column if not exists used_by uuid references public.profiles(id);
alter table public.cryo_records drop constraint if exists cryo_records_status_check;
alter table public.cryo_records add constraint cryo_records_status_check
  check (status in ('Stored', 'Used')) not valid;
alter table public.cryo_records validate constraint cryo_records_status_check;
alter table public.transfer_cryo_schedule add column if not exists embryos_used int;
alter table public.transfer_cryo_schedule add column if not exists used_from_cryo boolean not null default false;
update public.cryo_tanks
set used=greatest(used,0), capacity=greatest(capacity,used,1);
alter table public.cryo_tanks drop constraint if exists cryo_tanks_capacity_check;
alter table public.cryo_tanks add constraint cryo_tanks_capacity_check
  check (capacity > 0 and used between 0 and capacity) not valid;
alter table public.cryo_tanks validate constraint cryo_tanks_capacity_check;
alter table public.pharmacy_inventory add column if not exists batch_number text;
alter table public.lab_results add column if not exists title text;

create table if not exists public.lab_test_orders (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names(patient_id) on delete cascade,
  cycle_id uuid references public.cycles(id) on delete set null,
  ordered_by_profile_id uuid not null references public.profiles(id),
  ordered_by_role text not null check (ordered_by_role in ('doctor', 'matron')),
  tests text[] not null check (cardinality(tests) > 0),
  status text not null default 'Ordered' check (status in ('Ordered', 'Collected', 'Cancelled', 'Completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists lab_test_orders_patient_idx on public.lab_test_orders(patient_id);
alter table public.lab_test_orders enable row level security;
drop trigger if exists lab_test_orders_set_updated_at on public.lab_test_orders;
create trigger lab_test_orders_set_updated_at before update on public.lab_test_orders
  for each row execute function public.set_updated_at();

-- Real nurse visit backing table (kept here as a guard for projects where 17
-- was only partially applied).
create table if not exists public.nurse_visits (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names(patient_id) on delete cascade,
  cycle_id uuid references public.cycles(id) on delete set null,
  documented_by uuid references public.profiles(id),
  visit_date date not null default current_date,
  bp_systolic int, bp_diastolic int, temperature_c numeric(4,1), pulse_bpm int,
  spo2_pct int, height_cm numeric(5,1), weight_kg numeric(5,1),
  condition text check (condition in ('Stable', 'Needs Review')),
  nursing_notes text, post_visit_instructions text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.nurse_visits add column if not exists updated_at timestamptz not null default now();
alter table public.nurse_visits enable row level security;
drop trigger if exists nurse_visits_set_updated_at on public.nurse_visits;
create trigger nurse_visits_set_updated_at before update on public.nurse_visits
  for each row execute function public.set_updated_at();

create table if not exists public.nursing_tasks (
  id uuid primary key default gen_random_uuid(),
  nurse_id uuid not null references public.profiles(id) on delete cascade,
  label text not null check (length(trim(label)) between 1 and 300),
  done boolean not null default false,
  shift_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.nursing_tasks enable row level security;
drop trigger if exists nursing_tasks_set_updated_at on public.nursing_tasks;
create trigger nursing_tasks_set_updated_at before update on public.nursing_tasks
  for each row execute function public.set_updated_at();
drop policy if exists "nurses manage own shift tasks" on public.nursing_tasks;
create policy "nurses manage own shift tasks" on public.nursing_tasks for all to authenticated
  using (public.current_app_role()='nurse' and nurse_id=auth.uid())
  with check (public.current_app_role()='nurse' and nurse_id=auth.uid());

create table if not exists public.medication_adherence (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  patient_id text not null references public.patient_names(patient_id) on delete cascade,
  taken_on date not null default current_date,
  recorded_by uuid not null references public.profiles(id),
  recorded_at timestamptz not null default now(),
  unique (prescription_id, taken_on)
);
create index if not exists medication_adherence_patient_idx
  on public.medication_adherence(patient_id, taken_on desc);
alter table public.medication_adherence enable row level security;

create table if not exists public.supplier_requests (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid references public.pharmacy_inventory(id) on delete set null,
  item_name text not null,
  requested_quantity int not null check (requested_quantity > 0),
  priority text not null default 'Emergency' check (priority in ('Routine','Urgent','Emergency')),
  status text not null default 'Requested' check (status in ('Requested','Acknowledged','Fulfilled','Cancelled')),
  requested_by uuid not null references public.profiles(id),
  requested_at timestamptz not null default now(),
  notes text
);
alter table public.supplier_requests enable row level security;


commit;
