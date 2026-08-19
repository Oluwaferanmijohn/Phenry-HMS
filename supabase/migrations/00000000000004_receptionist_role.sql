-- ============================================================================
-- Phenry Health — Receptionist role migration
--
-- FLAGGED SPEC-VS-PROTOTYPE CONFLICT (spec wins, per your instructions):
-- receptionist.js's openPatientProfile() modal shows an "Allergies" /
-- "Clinical Snapshot" line and an "Active cycle" line. But spec §2.2's RLS
-- matrix gives Receptionist `cycles` = "none" outright, and
-- `patient_names`/`bio_details` = "full (create/read)" while §3.2 explicitly
-- qualifies that as "demographic fields only, no clinical notes." I've
-- dropped both the clinical-snapshot/allergies line and the active-cycle
-- line from the Receptionist patient profile modal to match the spec.
--
-- HOW THAT'S ENFORCED (not just a UI choice): RLS is row-level, not
-- column-level, and everyone hits Postgres as the same `authenticated` role
-- — so a plain RLS SELECT policy on bio_details can't itself keep
-- Receptionist off the allergies/obstetric columns while letting Doctor see
-- them. Instead of relying on the frontend simply not asking for those
-- columns (a UI convention, not a boundary), Receptionist gets NO raw SELECT
-- policy on bio_details at all — only two SECURITY DEFINER RPCs below that
-- return a hardcoded, demographic-only column list. This is the same
-- "architecturally impossible" bar the spec sets for Stakeholder, applied
-- here at the column level. Doctor/Matron/Admin get real raw-table SELECT
-- when their migrations add it.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- mrn_sequences / generate_mrn (§4.1). Sequence resets per (surname, day) —
-- the prototype's mock counter never resets (it just counts all same-surname
-- patients ever), but a dedicated *sequences* table keyed by date only makes
-- sense if the count is scoped to that date; the always-growing prototype
-- counter is a mock-data simplification, not a deliberate design.
-- ----------------------------------------------------------------------------
create table public.mrn_sequences (
  surname_prefix text not null,
  reg_date date not null,
  next_seq int not null default 1,
  primary key (surname_prefix, reg_date)
);

create or replace function public.generate_mrn(p_surname text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  prefix text := upper(regexp_replace(p_surname, '[^a-zA-Z]', '', 'g'));
  today date := current_date;
  seq int;
begin
  insert into public.mrn_sequences (surname_prefix, reg_date, next_seq)
  values (prefix, today, 2)
  on conflict (surname_prefix, reg_date) do update set next_seq = public.mrn_sequences.next_seq + 1
  returning next_seq - 1 into seq;

  return prefix || '/' || to_char(today, 'YYYYMMDD') || '/' || lpad(seq::text, 3, '0');
end;
$$;
-- Deliberately not GRANTed to `authenticated` directly — only called from
-- inside register_new_patient() below, which does its own role check.

-- ----------------------------------------------------------------------------
-- register_new_patient (§3.2 `regSubmit`) — one atomic RPC instead of two
-- raw INSERTs from the client, for the same reason as the payment_milestones
-- trigger in the Patient migration: an RPC can enforce "assigned_doctor_id
-- is always the clinic's doctor, status always starts at Scheduled" without
-- trusting the client to send correct values, and can't leave an orphaned
-- patient_names row if the second insert fails.
-- ----------------------------------------------------------------------------
create or replace function public.register_new_patient(
  p_first text, p_last text, p_dob date, p_sex text,
  p_phone text, p_email text, p_address text,
  p_ec_name text, p_ec_relationship text, p_ec_phone text,
  p_referral_source text
)
returns table (patient_id text, mrn text)
language plpgsql
security definer
set search_path = public
as $$
declare
  new_patient_id text;
  assigned_doctor uuid;
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized to register patients';
  end if;

  new_patient_id := public.generate_mrn(p_last);
  select id into assigned_doctor from public.profiles where role = 'doctor' order by created_at asc limit 1;

  insert into public.patient_names (patient_id, first_name, surname, full_name)
  values (new_patient_id, p_first, p_last, p_first || ' ' || p_last);

  insert into public.bio_details (
    patient_id, dob, sex, phone, email, address, emergency_contact,
    referral_source, registered_on, assigned_doctor_id, status
  ) values (
    new_patient_id, p_dob, p_sex, p_phone, p_email, p_address,
    jsonb_build_object('name', p_ec_name, 'relationship', p_ec_relationship, 'phone', p_ec_phone),
    p_referral_source, current_date, assigned_doctor, 'Scheduled'
  );

  return query select new_patient_id, new_patient_id;
end;
$$;
grant execute on function public.register_new_patient(text, text, date, text, text, text, text, text, text, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- Front-desk-scoped patient reads (see the flagged note at the top of this
-- file for why these are RPCs and not a raw SELECT policy).
-- ----------------------------------------------------------------------------
create or replace function public.patients_front_desk_directory(p_search text default '')
returns table (
  patient_id text, first_name text, surname text, full_name text,
  dob date, sex text, blood_group text, phone text, email text, address text,
  emergency_contact jsonb, registered_on date, assigned_doctor_id uuid, status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized';
  end if;

  return query
  select pn.patient_id, pn.first_name, pn.surname, pn.full_name,
         bd.dob, bd.sex, bd.blood_group, bd.phone, bd.email, bd.address,
         bd.emergency_contact, bd.registered_on, bd.assigned_doctor_id, bd.status
  from public.patient_names pn
  join public.bio_details bd on bd.patient_id = pn.patient_id
  where p_search = '' or (pn.full_name || ' ' || pn.patient_id) ilike '%' || p_search || '%'
  order by pn.full_name asc;
end;
$$;
grant execute on function public.patients_front_desk_directory(text) to authenticated;

create or replace function public.patient_front_desk_profile(p_patient_id text)
returns table (
  patient_id text, first_name text, surname text, full_name text,
  dob date, sex text, blood_group text, phone text, email text, address text,
  emergency_contact jsonb, registered_on date, assigned_doctor_id uuid, status text
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.patients_front_desk_directory('') where patient_id = p_patient_id;
$$;
grant execute on function public.patient_front_desk_profile(text) to authenticated;

-- ----------------------------------------------------------------------------
-- appointments.status now has a real domain (deferred from the Patient
-- migration until this role's check-in / master-schedule flows made the
-- full value set clear).
-- ----------------------------------------------------------------------------
alter table public.appointments
  add constraint appointments_status_chk
  check (status in ('Scheduled', 'Waiting', 'In Room', 'Completed', 'Cancelled'));

-- ----------------------------------------------------------------------------
-- RLS: patient_names (name-only, not clinical — safe for a plain policy),
-- appointments (full CRUD, spec's "override authority"), messages_log (read).
-- ----------------------------------------------------------------------------
create policy "receptionist reads all patient_names"
  on public.patient_names for select to authenticated
  using (public.current_app_role() = 'receptionist');

create policy "receptionist full crud on appointments"
  on public.appointments for all to authenticated
  using (public.current_app_role() = 'receptionist')
  with check (public.current_app_role() = 'receptionist');

alter table public.messages_log enable row level security; -- already on, kept idempotent
create policy "receptionist reads messages_log"
  on public.messages_log for select to authenticated
  using (public.current_app_role() = 'receptionist');
