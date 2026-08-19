-- ============================================================================
-- Phenry Health — Chief Embryologist role migration
--
-- NOTE ON OMITTED DEMO DATA: chief_embryologist.js's "Pending Verifications"
-- card (ChiefUI.verifications) and "Today's Procedures" table are hardcoded
-- example rows with no backing table in spec §1. "Today's Procedures" is
-- wired to the real surgery_schedule table below (a clean win — the data
-- already exists). "Pending Verifications" has no real equivalent anywhere
-- in the schema (lab_results has no verification/sign-off status field), so
-- it ships as an honest empty state rather than fabricated queue items.
-- ============================================================================

-- lab_results needs a display title for external uploads (the prototype
-- reuses "remarks" for this, which would collide with actual lab remarks).
alter table public.lab_results add column title text;

-- ----------------------------------------------------------------------------
-- embryo_batches (§1: patient_id, day_key, total, grades jsonb — one row per
-- patient per day, not one blob covering all days).
-- ----------------------------------------------------------------------------
create table public.embryo_batches (
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  day_key text not null check (day_key in ('day1', 'day2', 'day3', 'day5')),
  total int,
  grades jsonb not null default '[]',
  updated_at timestamptz not null default now(),
  primary key (patient_id, day_key)
);
create trigger embryo_batches_set_updated_at before update on public.embryo_batches for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- transfer_cryo_schedule
-- ----------------------------------------------------------------------------
create table public.transfer_cryo_schedule (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  type text not null,
  scheduled_date date not null,
  status text not null default 'Scheduled' check (status in ('Scheduled', 'Done', 'Postponed', 'Cancelled')),
  notes text,
  documented_by uuid references public.profiles (id),
  documented_on date,
  created_at timestamptz not null default now()
);
create index transfer_cryo_schedule_patient_idx on public.transfer_cryo_schedule (patient_id);

-- ----------------------------------------------------------------------------
-- cryo_tanks / cryo_records (real tank_id FK, not the prototype's
-- string-matched tank name)
-- ----------------------------------------------------------------------------
create table public.cryo_tanks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phase text not null default 'Vapor Phase LN2',
  current_temp numeric not null default -196.0,
  capacity int not null default 100,
  used int not null default 0
);

create table public.cryo_records (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  asset_type text not null check (asset_type in ('Embryo', 'Oocyte', 'Sperm')),
  straws int not null default 1,
  per_straw int,
  freezing_date date not null default current_date,
  tank_id uuid references public.cryo_tanks (id),
  canister text,
  position text,
  notes text,
  logged_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);
create index cryo_records_patient_idx on public.cryo_records (patient_id);

-- ----------------------------------------------------------------------------
-- incubator_logs / lab_equipment / lab_store
-- ----------------------------------------------------------------------------
create table public.incubator_logs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  location text,
  temp numeric,
  co2 numeric,
  o2 numeric,
  humidity numeric,
  status text not null default 'Not Checked' check (status in ('Not Checked', 'Pass', 'Fail')),
  last_checked timestamptz,
  checked_by uuid references public.profiles (id)
);
insert into public.incubator_logs (name, location) values ('Incubator 1', 'Lab Bay A'), ('Incubator 2', 'Lab Bay A'), ('Incubator 3', 'Lab Bay B');

create table public.lab_equipment (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  last_serviced date,
  next_service_due date,
  status text not null default 'OK' check (status in ('OK', 'Due Soon', 'Overdue')),
  notes text
);
insert into public.lab_equipment (name, category, next_service_due) values
  ('ICSI Micromanipulator', 'Microscopy', current_date + 60),
  ('Centrifuge', 'General Lab', current_date + 30),
  ('Laminar Flow Hood', 'Air Handling', current_date + 90);

create table public.lab_store (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  current_qty int not null default 0,
  unit text not null default 'units',
  min_threshold int not null default 10,
  location text,
  notes text
);
insert into public.lab_store (name, category, current_qty, unit, min_threshold, location) values
  ('ICSI Pipettes', 'Consumables', 40, 'units', 15, 'Lab Storage A'),
  ('Cryo Straws', 'Consumables', 120, 'units', 30, 'Lab Storage B'),
  ('Culture Media (Cleavage)', 'Media', 8, 'bottles', 5, 'Fridge 2');

-- ----------------------------------------------------------------------------
-- RLS: Chief Embryologist
-- ----------------------------------------------------------------------------
create policy "chief embryologist reads patient context"
  on public.patient_names for select to authenticated
  using (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist reads bio_details context"
  on public.bio_details for select to authenticated
  using (public.current_app_role() = 'chief_embryologist');
-- No cycles/consultations policy for chief_embryologist — matrix gives "none"
-- on both; the shared Patients/Consultation-history views simply show
-- nothing for those sections under this role, which is correct.

create policy "chief embryologist full access to lab_results"
  on public.lab_results for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist manages lab_templates"
  on public.lab_templates for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist full access to embryo_batches"
  on public.embryo_batches for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');

alter table public.transfer_cryo_schedule enable row level security;
create policy "chief embryologist full access to transfer_cryo_schedule"
  on public.transfer_cryo_schedule for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');

alter table public.cryo_tanks enable row level security;
alter table public.cryo_records enable row level security;
create policy "chief embryologist full access to cryo_tanks"
  on public.cryo_tanks for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist full access to cryo_records"
  on public.cryo_records for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');

alter table public.incubator_logs enable row level security;
alter table public.lab_equipment enable row level security;
alter table public.lab_store enable row level security;
create policy "chief embryologist full access to incubator_logs"
  on public.incubator_logs for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist full access to lab_equipment"
  on public.lab_equipment for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');
create policy "chief embryologist full access to lab_store"
  on public.lab_store for all to authenticated
  using (public.current_app_role() = 'chief_embryologist') with check (public.current_app_role() = 'chief_embryologist');

create policy "chief embryologist creates requisitions"
  on public.requisitions for insert to authenticated
  with check (public.current_app_role() = 'chief_embryologist' and requested_by_profile_id = auth.uid());
create policy "chief embryologist reads own requisitions"
  on public.requisitions for select to authenticated
  using (public.current_app_role() = 'chief_embryologist' and requested_by_profile_id = auth.uid());

-- ----------------------------------------------------------------------------
-- Storage: external lab result uploads (PDF/scan attachments). Private
-- bucket — only staff with lab_results access can read/write, scoped by
-- role rather than by folder (unlike the patient payment-proof bucket,
-- there's no single "owner" of a clinical document).
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('lab-external-results', 'lab-external-results', false) on conflict (id) do nothing;

create policy "chief embryologist manages lab result uploads"
  on storage.objects for all to authenticated
  using (bucket_id = 'lab-external-results' and public.current_app_role() = 'chief_embryologist')
  with check (bucket_id = 'lab-external-results' and public.current_app_role() = 'chief_embryologist');

-- ----------------------------------------------------------------------------
-- Admin read access to the lab tables just created (matrix: Admin = read on
-- all of these — couldn't be granted earlier since the tables didn't exist).
-- ----------------------------------------------------------------------------
create policy "admin reads embryo_batches" on public.embryo_batches for select to authenticated using (public.is_admin());
create policy "admin reads transfer_cryo_schedule" on public.transfer_cryo_schedule for select to authenticated using (public.is_admin());
create policy "admin reads cryo_tanks" on public.cryo_tanks for select to authenticated using (public.is_admin());
create policy "admin reads cryo_records" on public.cryo_records for select to authenticated using (public.is_admin());
create policy "admin reads incubator_logs" on public.incubator_logs for select to authenticated using (public.is_admin());
create policy "admin reads lab_equipment" on public.lab_equipment for select to authenticated using (public.is_admin());
create policy "admin reads lab_store" on public.lab_store for select to authenticated using (public.is_admin());

-- Doctor/Matron/Nurse also read embryo_batches per the matrix ("read" for
-- all three) — they already got lab_results read in their own migrations;
-- embryo_batches is new, so add it for all three roles now that it exists.
create policy "doctor reads embryo_batches" on public.embryo_batches for select to authenticated using (public.current_app_role() = 'doctor');
create policy "matron reads embryo_batches" on public.embryo_batches for select to authenticated using (public.current_app_role() = 'matron');
create policy "nurse reads embryo_batches" on public.embryo_batches for select to authenticated using (public.current_app_role() = 'nurse');
