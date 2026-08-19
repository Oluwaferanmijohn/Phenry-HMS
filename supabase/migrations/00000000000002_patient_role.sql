-- ============================================================================
-- Phenry Health — Patient role migration
-- Tables the Patient role touches (spec §1, §2.2 "Patient" column) plus the
-- linking column patient portal logins need. Adds RLS for the `patient` role
-- only; later role migrations add more policies to these same tables.
--
-- FLAGGED ASSUMPTION (surfaced in chat, not silently decided):
-- Spec's `mrn_sequences` (§4.1) generates SURNAME/YYYYMMDD/SEQ strings, and
-- `patient_names`'s only key column is `patient_id (PK)` — no separate `mrn`
-- column exists anywhere in §1. The natural reading is that patient_id IS
-- the MRN string (text, not a UUID). But `profiles` (a portal login) also
-- has no `patient_id` column in §1, so there is no documented way to map a
-- logged-in patient's auth.uid() to their clinical patient_id. I've added
-- one nullable linking column, `profiles.patient_id text references
-- patient_names(patient_id)`, populated when a patient is given portal
-- access (at registration or later). Every "own row" patient RLS policy
-- below depends on this column existing. Please confirm this is the
-- intended mapping — it's foundational to every later role too.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Link a portal login to its clinical record. Nullable: a patient can exist
-- (registered by Receptionist) before/without ever getting portal access.
-- ----------------------------------------------------------------------------
alter table public.profiles
  add column patient_id text;

create or replace function public.current_patient_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select patient_id from public.profiles where id = auth.uid();
$$;
comment on function public.current_patient_id() is 'The clinical patient_id (MRN) linked to the calling portal login, or NULL if none/not a patient.';

-- ----------------------------------------------------------------------------
-- patient_names / bio_details — split per spec (identity vs clinical detail),
-- both "Stakeholder RLS-blocked, no exceptions" (§2.2).
-- ----------------------------------------------------------------------------
create table public.patient_names (
  patient_id text primary key,
  first_name text not null,
  surname text not null,
  full_name text not null,
  created_at timestamptz not null default now()
);
comment on table public.patient_names is 'patient_id is the clinic MRN (SURNAME/YYYYMMDD/SEQ from mrn_sequences, §4.1), not a UUID.';

alter table public.profiles
  add constraint profiles_patient_id_fk foreign key (patient_id) references public.patient_names (patient_id);

create table public.bio_details (
  patient_id text primary key references public.patient_names (patient_id) on delete cascade,
  dob date,
  sex text,
  blood_group text,
  phone text,
  email text,
  address text,
  emergency_contact jsonb,
  allergies text[] not null default '{}',
  chronic_conditions text[] not null default '{}',
  obstetric_history text,
  past_surgeries jsonb not null default '[]',
  referral_source text,
  registered_on date not null default current_date,
  assigned_doctor_id uuid references public.profiles (id),
  status text not null default 'Scheduled',
  spouse jsonb,
  updated_at timestamptz not null default now()
);

create trigger bio_details_set_updated_at
  before update on public.bio_details
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- cycles / cycle_daily_logs / cycle_investigations / cycle_ultrasounds
-- ----------------------------------------------------------------------------
create table public.cycles (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  cycle_number int not null default 1,
  protocol text,
  type text,
  start_date date,
  opu_date date,
  transfer_date date,
  stage text not null default 'Baseline',
  cycle_day int not null default 0,
  status text not null default 'Pending Start',
  outcome text,
  physician_notes text,
  prior_cycles jsonb not null default '[]',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index cycles_patient_id_idx on public.cycles (patient_id);
create trigger cycles_set_updated_at before update on public.cycles for each row execute function public.set_updated_at();

create table public.cycle_daily_logs (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles (id) on delete cascade,
  day int not null,
  date date not null,
  medication_administered boolean not null default false,
  vitals_logged boolean not null default false,
  note text,
  created_at timestamptz not null default now()
);
create index cycle_daily_logs_cycle_id_idx on public.cycle_daily_logs (cycle_id);

create table public.cycle_investigations (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles (id) on delete cascade,
  hormone text not null,
  value numeric,
  unit text,
  ref_range text,
  date date not null default current_date,
  flag boolean not null default false,
  created_at timestamptz not null default now()
);
create index cycle_investigations_cycle_id_idx on public.cycle_investigations (cycle_id);

create table public.cycle_ultrasounds (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references public.cycles (id) on delete cascade,
  endometrial numeric,
  right_ovary jsonb,
  left_ovary jsonb,
  date date not null default current_date,
  created_at timestamptz not null default now()
);
create index cycle_ultrasounds_cycle_id_idx on public.cycle_ultrasounds (cycle_id);

-- ----------------------------------------------------------------------------
-- consultations — Patient gets read-only per §2.2; write access (Doctor/
-- Matron) is added in later role migrations.
-- ----------------------------------------------------------------------------
create table public.consultations (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  provider_profile_id uuid references public.profiles (id),
  provider_role text check (provider_role in ('doctor', 'matron')),
  date date not null default current_date,
  type text,
  notes text,
  diagnosis text,
  icd10 text,
  created_at timestamptz not null default now()
);
create index consultations_patient_id_idx on public.consultations (patient_id);

-- ----------------------------------------------------------------------------
-- appointments — powers the appointment engine (§4.2). Patient can read own
-- + self-book (insert only, no reschedule/cancel — that's Receptionist).
-- A partial unique index makes double-booking impossible by construction,
-- exactly per §4.2's own wording.
-- ----------------------------------------------------------------------------
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  provider_role text not null check (provider_role in ('doctor', 'matron')),
  provider_profile_id uuid not null references public.profiles (id),
  type text not null,
  date date not null,
  time time not null,
  duration int not null default 30,
  status text not null default 'Scheduled',
  room text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index appointments_patient_id_idx on public.appointments (patient_id);
create index appointments_provider_date_idx on public.appointments (provider_profile_id, date);
create unique index appointments_no_double_book
  on public.appointments (provider_profile_id, date, time)
  where status <> 'Cancelled';
create trigger appointments_set_updated_at before update on public.appointments for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- payment_plans / payment_milestones
-- ----------------------------------------------------------------------------
create table public.payment_plans (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  package text not null,
  total_cost numeric(14, 2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payment_plans_patient_id_idx on public.payment_plans (patient_id);
create trigger payment_plans_set_updated_at before update on public.payment_plans for each row execute function public.set_updated_at();

create table public.payment_milestones (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.payment_plans (id) on delete cascade,
  label text not null,
  amount numeric(14, 2) not null default 0,
  status text not null default 'Upcoming' check (status in ('Upcoming', 'Pending Verification', 'Paid')),
  due_context text,
  proof_url text,
  approved_on date,
  approved_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payment_milestones_plan_id_idx on public.payment_milestones (plan_id);
create trigger payment_milestones_set_updated_at before update on public.payment_milestones for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- prescriptions — §0.1: nurses can originate these too, not just doctors.
-- ----------------------------------------------------------------------------
create table public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  prescribed_by_profile_id uuid references public.profiles (id),
  prescribed_by_role text not null check (prescribed_by_role in ('doctor', 'nurse')),
  medication text not null,
  sig text not null,
  date timestamptz not null default now(),
  status text not null default 'Pending' check (status in ('Pending', 'Dispensed', 'Cancelled')),
  requires_cosign boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index prescriptions_patient_id_idx on public.prescriptions (patient_id);
create trigger prescriptions_set_updated_at before update on public.prescriptions for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- lab_templates / lab_results — Patient gets read on both per §2.2.
-- ----------------------------------------------------------------------------
create table public.lab_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  description text,
  variables jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create table public.lab_results (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  template_id uuid references public.lab_templates (id),
  entered_by_profile_id uuid references public.profiles (id),
  collected_on timestamptz not null default now(),
  values jsonb not null default '[]',
  remarks text,
  external boolean not null default false,
  external_file_url text,
  created_at timestamptz not null default now()
);
create index lab_results_patient_id_idx on public.lab_results (patient_id);

-- ----------------------------------------------------------------------------
-- clinic_settings — singleton row. Patient gets read-only (bank details +
-- own booking uses `schedule`). Admin-only write is added when Admin is built.
-- ----------------------------------------------------------------------------
create table public.clinic_settings (
  id smallint primary key default 1 check (id = 1),
  clinic_name text not null default 'Phenry Health',
  company_name text,
  company_address text,
  company_phone text,
  logo_url text,
  id_format text not null default 'SURNAME/YYYYMMDD/SEQ',
  bank jsonb not null default '{}',
  appointment_interval int not null default 30,
  schedule jsonb not null default '{}',
  updated_at timestamptz not null default now()
);
create trigger clinic_settings_set_updated_at before update on public.clinic_settings for each row execute function public.set_updated_at();

-- Seed with the prototype's demo values so the app is usable immediately;
-- Admin's Global Settings page (built later) is the real editor for these.
insert into public.clinic_settings (
  id, clinic_name, company_name, company_address, company_phone, logo_url,
  id_format, bank, appointment_interval, schedule
) values (
  1, 'Phenry Health', 'Phenry Health Clinics Ltd', '14 Kofo Abayomi Street, Victoria Island, Lagos, Nigeria',
  '+234 700 123 4567', null, 'SURNAME/YYYYMMDD/SEQ',
  '{"name": "Phenry National Bank", "accountName": "Phenry Health Clinics Ltd", "accountNumber": "0123456789"}',
  30,
  '{
    "Mon": {"consultation": true,  "clinical": true,  "transfersSurgeries": false, "open": "08:00", "close": "17:00"},
    "Tue": {"consultation": true,  "clinical": true,  "transfersSurgeries": true,  "open": "08:00", "close": "17:00"},
    "Wed": {"consultation": true,  "clinical": true,  "transfersSurgeries": false, "open": "08:00", "close": "17:00"},
    "Thu": {"consultation": true,  "clinical": false, "transfersSurgeries": true,  "open": "09:00", "close": "14:00"},
    "Fri": {"consultation": true,  "clinical": true,  "transfersSurgeries": false, "open": "08:00", "close": "17:00"},
    "Sat": {"consultation": false, "clinical": false, "transfersSurgeries": false, "open": "--",    "close": "--"},
    "Sun": {"consultation": false, "clinical": false, "transfersSurgeries": false, "open": "--",    "close": "--"}
  }'::jsonb
)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- messages_log — WhatsApp notification log (§4.3). Created now because the
-- appointments trigger below writes to it; the Messages *page* (read UI) is
-- Receptionist's and is built in that role's pass.
-- ----------------------------------------------------------------------------
create table public.messages_log (
  id uuid primary key default gen_random_uuid(),
  patient_id text references public.patient_names (patient_id) on delete set null,
  trigger_type text not null check (trigger_type in ('new_appointment', 'rescheduled')),
  body text not null,
  sent_at timestamptz,
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed')),
  created_at timestamptz not null default now()
);
create index messages_log_patient_id_idx on public.messages_log (patient_id);

-- ----------------------------------------------------------------------------
-- Appointment engine helper (§4.2): available slots = clinic_settings.schedule
-- for that weekday, in appointment_interval chunks, minus this provider's
-- existing (non-cancelled) appointments that day. security definer so a
-- patient can compute free/busy slots without gaining direct visibility into
-- other patients' appointment rows.
-- ----------------------------------------------------------------------------
create or replace function public.available_appointment_slots(p_date date, p_provider_profile_id uuid)
returns table (slot_time time)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  dow text := to_char(p_date, 'Dy'); -- 'Mon'.."Sun" — assumes default (English) server locale
  day_cfg jsonb;
  interval_min int;
  open_t time;
  close_t time;
  cur time;
begin
  select schedule -> dow, appointment_interval into day_cfg, interval_min from public.clinic_settings where id = 1;

  if day_cfg is null or (day_cfg ->> 'open') = '--' or (day_cfg ->> 'open') is null then
    return;
  end if;

  open_t := (day_cfg ->> 'open')::time;
  close_t := (day_cfg ->> 'close')::time;
  cur := open_t;

  while cur < close_t loop
    if not exists (
      select 1 from public.appointments a
      where a.date = p_date
        and a.provider_profile_id = p_provider_profile_id
        and a.time = cur
        and a.status <> 'Cancelled'
    ) then
      slot_time := cur;
      return next;
    end if;
    cur := cur + make_interval(mins => coalesce(interval_min, 30));
  end loop;
end;
$$;
grant execute on function public.available_appointment_slots(date, uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- WhatsApp trigger (§4.3, exactly two triggers): new appointment + reschedule.
-- Queues a messages_log row and asks pg_net to invoke the notify-whatsapp
-- Edge Function (supabase/functions/notify-whatsapp), which holds the
-- Evolution API key and does the actual send + status update.
-- ----------------------------------------------------------------------------
create extension if not exists pg_net;

create or replace function public.notify_appointment_whatsapp()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  patient_full_name text;
  msg_body text;
  msg_id uuid;
  trigger_kind text;
  project_url text := current_setting('app.settings.supabase_url', true);
  service_key text := current_setting('app.settings.service_role_key', true);
begin
  if tg_op = 'INSERT' then
    trigger_kind := 'new_appointment';
  elsif tg_op = 'UPDATE' and (new.date <> old.date or new.time <> old.time) then
    trigger_kind := 'rescheduled';
  else
    return new;
  end if;

  select full_name into patient_full_name from public.patient_names where patient_id = new.patient_id;

  msg_body := format(
    '%s your appointment for %s has been %s for %s at %s. — Phenry Health',
    coalesce(patient_full_name, 'Hi,'),
    new.type,
    case when trigger_kind = 'rescheduled' then 'moved' else 'confirmed' end,
    to_char(new.date, 'Mon DD, YYYY'),
    to_char(new.time, 'HH12:MI AM')
  );

  insert into public.messages_log (patient_id, trigger_type, body, status)
  values (new.patient_id, trigger_kind, msg_body, 'queued')
  returning id into msg_id;

  -- Fire-and-forget webhook to the Edge Function. Requires
  -- app.settings.supabase_url / app.settings.service_role_key to be set at
  -- the database level (`alter database postgres set app.settings.supabase_url = '...'`)
  -- — documented in supabase/functions/notify-whatsapp/README.md.
  if project_url is not null and service_key is not null then
    perform net.http_post(
      url := project_url || '/functions/v1/notify-whatsapp',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
      body := jsonb_build_object('message_id', msg_id)
    );
  end if;

  return new;
end;
$$;

create trigger appointments_notify_whatsapp
  after insert or update on public.appointments
  for each row execute function public.notify_appointment_whatsapp();

-- ----------------------------------------------------------------------------
-- Enable RLS + Patient-role policies. (Other roles' policies are additive,
-- created in their own migrations — nothing here should be edited later,
-- only extended.)
-- ----------------------------------------------------------------------------
alter table public.patient_names enable row level security;
alter table public.bio_details enable row level security;
alter table public.cycles enable row level security;
alter table public.cycle_daily_logs enable row level security;
alter table public.cycle_investigations enable row level security;
alter table public.cycle_ultrasounds enable row level security;
alter table public.consultations enable row level security;
alter table public.appointments enable row level security;
alter table public.payment_plans enable row level security;
alter table public.payment_milestones enable row level security;
alter table public.prescriptions enable row level security;
alter table public.lab_templates enable row level security;
alter table public.lab_results enable row level security;
alter table public.clinic_settings enable row level security;
alter table public.messages_log enable row level security;

create policy "patient reads own patient_names row"
  on public.patient_names for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient reads own bio_details row"
  on public.bio_details for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient reads own cycles"
  on public.cycles for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient reads own cycle_daily_logs"
  on public.cycle_daily_logs for select to authenticated
  using (exists (select 1 from public.cycles c where c.id = cycle_daily_logs.cycle_id and c.patient_id = public.current_patient_id()));

create policy "patient reads own cycle_investigations"
  on public.cycle_investigations for select to authenticated
  using (exists (select 1 from public.cycles c where c.id = cycle_investigations.cycle_id and c.patient_id = public.current_patient_id()));

create policy "patient reads own cycle_ultrasounds"
  on public.cycle_ultrasounds for select to authenticated
  using (exists (select 1 from public.cycles c where c.id = cycle_ultrasounds.cycle_id and c.patient_id = public.current_patient_id()));

create policy "patient reads own consultations"
  on public.consultations for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient reads own appointments"
  on public.appointments for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient self-books an appointment"
  on public.appointments for insert to authenticated
  with check (
    patient_id = public.current_patient_id()
    and provider_role = 'doctor'
    and status = 'Scheduled'
    and exists (
      select 1 from public.bio_details bd
      where bd.patient_id = public.current_patient_id()
        and bd.assigned_doctor_id = appointments.provider_profile_id
    )
  );

create policy "patient reads own payment_plans"
  on public.payment_plans for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "patient reads own payment_milestones"
  on public.payment_milestones for select to authenticated
  using (exists (select 1 from public.payment_plans pp where pp.id = payment_milestones.plan_id and pp.patient_id = public.current_patient_id()));

-- RLS's WITH CHECK can only validate the NEW row's values, not diff it
-- against OLD — so on its own it can't stop a patient's proof-upload UPDATE
-- from also sneaking in a changed `amount` or `label`. This trigger closes
-- that: when the caller is a patient, only proof_url/status may move.
create or replace function public.enforce_patient_milestone_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() = 'patient' then
    if new.plan_id is distinct from old.plan_id
      or new.label is distinct from old.label
      or new.amount is distinct from old.amount
      or new.due_context is distinct from old.due_context
      or new.approved_on is distinct from old.approved_on
      or new.approved_by is distinct from old.approved_by
    then
      raise exception 'Patients may only update proof_url and status on a payment milestone';
    end if;
  end if;
  return new;
end;
$$;

create trigger payment_milestones_enforce_patient_update
  before update on public.payment_milestones
  for each row execute function public.enforce_patient_milestone_update();

create policy "patient uploads proof of payment on own milestone"
  on public.payment_milestones for update to authenticated
  using (exists (select 1 from public.payment_plans pp where pp.id = payment_milestones.plan_id and pp.patient_id = public.current_patient_id()))
  with check (
    exists (select 1 from public.payment_plans pp where pp.id = payment_milestones.plan_id and pp.patient_id = public.current_patient_id())
    -- A patient upload can only move Upcoming -> Pending Verification and attach proof_url;
    -- it can never set status to 'Paid' directly (that's Admin-only, added in that role's migration).
    and status = 'Pending Verification'
  );

create policy "patient reads own prescriptions"
  on public.prescriptions for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "any authenticated user reads lab_templates"
  on public.lab_templates for select to authenticated
  using (true);

create policy "patient reads own lab_results"
  on public.lab_results for select to authenticated
  using (patient_id = public.current_patient_id());

create policy "any authenticated user reads clinic_settings"
  on public.clinic_settings for select to authenticated
  using (true);

-- Lets a patient's Home page resolve their assigned doctor's display name
-- (bio_details.assigned_doctor_id -> profiles.full_name), and generally lets
-- the app show staff names anywhere they're referenced by id (e.g. "seen by
-- Dr. Adeleke"). Scoped to staff rows only — one patient still cannot read
-- another patient's profiles row this way (patient_names/bio_details, the
-- actual sensitive data, stay locked down by the policies above regardless).
create policy "authenticated users read staff display names"
  on public.profiles for select to authenticated
  using (role is not null and role <> 'patient');
