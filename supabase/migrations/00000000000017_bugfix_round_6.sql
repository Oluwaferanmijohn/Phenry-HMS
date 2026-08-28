-- ============================================================================
-- Phenry Health — Bugfix round 6
--
-- A. recovery_beds — excluded only Stakeholder; Patient could read every
--    patient's bed occupancy. Excluding both now.
-- B. surgery_schedule — Doctor could only see procedures they scheduled or
--    were assigned to (not clinic-wide theatre awareness); Chief
--    Embryologist and Lab Tech had zero access at all, despite
--    chief_embryologist/overview.vue already querying it (silently empty
--    ever since). Also worth noting: an earlier round of this same bugfix
--    effort briefly "corrected" ScheduleProcedureModal.vue/SurgeryPage.vue/
--    matron/overview.vue to reference `assigned_doctor_id` instead of
--    `assigned_provider_id`, based on reading migration 006 in isolation —
--    migration 007 (matron_role.sql) deliberately renames that column
--    right after (Matron can be primary provider too, not just Doctor) and
--    drops the old `report` column in favor of the separate
--    operative_reports table. That client-side "fix" was reverted; the
--    real column has always been `assigned_provider_id`. Flagging here so
--    the mistake and its correction are both on the record.
-- C. transfer_cryo_schedule — no structured way to record how many embryos
--    a Transfer event actually used, which is what "embryos transferred vs
--    remaining" needs as its source of truth.
-- D. Patient portal login — register_new_patient() never created an Auth
--    account; patients had no way to log in at all. handle_new_user()
--    extended to pick up patient_id from metadata (server/api/receptionist/
--    create-patient-account.post.ts sets it, mirroring create-staff's
--    pattern); force_password_reset already works generically for any role
--    including patient, so no change needed there.
-- E. Spouse/partner as a real linked record, and a signed consent file —
--    both requested for the nurse visit/vitals page.
-- F. nurse_visits — Triage & Vitals / Nursing Assessment / Post-Visit steps
--    on the nurse visit page had no backing table at all (confirmed:
--    plain unbound inputs, "Save & Proceed" only ever toasted). Only
--    Medication Admin, a separate step, actually wrote anywhere.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- A. recovery_beds
-- ----------------------------------------------------------------------------
drop policy if exists "authenticated non-stakeholders read recovery_beds" on public.recovery_beds;
create policy "authenticated clinical roles read recovery_beds"
  on public.recovery_beds for select to authenticated
  using (public.current_app_role() not in ('stakeholder', 'patient'));

-- ----------------------------------------------------------------------------
-- B. surgery_schedule visibility
-- ----------------------------------------------------------------------------
drop policy if exists "doctor reads procedures they scheduled or are assigned to" on public.surgery_schedule;
create policy "doctor reads all procedures"
  on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'doctor');

drop policy if exists "chief embryologist reads surgery_schedule" on public.surgery_schedule;
create policy "chief embryologist reads surgery_schedule"
  on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'chief_embryologist');

drop policy if exists "lab tech reads surgery_schedule" on public.surgery_schedule;
create policy "lab tech reads surgery_schedule"
  on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'lab_tech');

-- ----------------------------------------------------------------------------
-- C. Embryo transfer count tracking
-- ----------------------------------------------------------------------------
alter table public.transfer_cryo_schedule add column if not exists embryos_used int;
comment on column public.transfer_cryo_schedule.embryos_used is 'Embryos actually used in this event once marked Done (only meaningful for type ILIKE ''%Transfer%''). Source of truth for "transferred vs remaining in storage" alongside cryo_records.';

-- ----------------------------------------------------------------------------
-- D. Patient portal login
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name, patient_id, force_password_reset)
  values (
    new.id,
    new.raw_user_meta_data ->> 'role',
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'patient_id',
    coalesce((new.raw_user_meta_data ->> 'force_password_reset')::boolean, false)
  );
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- E. Spouse/partner linking + consent form
-- ----------------------------------------------------------------------------
alter table public.bio_details add column if not exists spouse_patient_id text references public.patient_names (patient_id);
comment on column public.bio_details.spouse_patient_id is 'Optional link to the partner''s own patient_names/bio_details record, when they''re also registered. The existing `spouse` jsonb stays as freeform notes (name/blood group/SFA result etc.) for when the partner isn''t a registered patient, or as a supplement when they are.';
alter table public.bio_details add column if not exists consent_form_url text;
comment on column public.bio_details.consent_form_url is 'Storage path in the consent-forms bucket for the signed Data Privacy & Medical Consent document.';

insert into storage.buckets (id, name, public)
values ('consent-forms', 'consent-forms', false)
on conflict (id) do nothing;

drop policy if exists "clinical staff upload consent forms" on storage.objects;
create policy "clinical staff upload consent forms"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'consent-forms' and public.current_app_role() in ('nurse', 'matron', 'doctor', 'receptionist'));

drop policy if exists "clinical staff read consent forms" on storage.objects;
create policy "clinical staff read consent forms"
  on storage.objects for select to authenticated
  using (bucket_id = 'consent-forms' and public.current_app_role() in ('nurse', 'matron', 'doctor', 'receptionist', 'admin_manager'));

drop policy if exists "patient reads their own consent form" on storage.objects;
create policy "patient reads their own consent form"
  on storage.objects for select to authenticated
  using (bucket_id = 'consent-forms' and (storage.foldername(name))[1] = public.current_patient_id());

-- ----------------------------------------------------------------------------
-- F. nurse_visits — real backing table for Triage & Vitals / Nursing
-- Assessment / Post-Visit Instructions.
-- ----------------------------------------------------------------------------
create table if not exists public.nurse_visits (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  cycle_id uuid references public.cycles (id) on delete set null,
  documented_by uuid references public.profiles (id),
  visit_date date not null default current_date,
  -- Triage & Vitals
  bp_systolic int,
  bp_diastolic int,
  temperature_c numeric(4, 1),
  pulse_bpm int,
  spo2_pct int,
  height_cm numeric(5, 1),
  weight_kg numeric(5, 1),
  -- Nursing Assessment
  condition text check (condition in ('Stable', 'Needs Review')),
  nursing_notes text,
  -- Post-Visit Instructions
  post_visit_instructions text,
  created_at timestamptz not null default now()
);
create index if not exists nurse_visits_patient_id_idx on public.nurse_visits (patient_id);

alter table public.nurse_visits enable row level security;

drop policy if exists "nurse manages nurse_visits" on public.nurse_visits;
create policy "nurse manages nurse_visits"
  on public.nurse_visits for all to authenticated
  using (public.current_app_role() = 'nurse')
  with check (public.current_app_role() = 'nurse');

drop policy if exists "doctor reads own patients' nurse_visits" on public.nurse_visits;
create policy "doctor reads own patients' nurse_visits"
  on public.nurse_visits for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));

drop policy if exists "matron reads nurse_visits" on public.nurse_visits;
create policy "matron reads nurse_visits"
  on public.nurse_visits for select to authenticated
  using (public.current_app_role() = 'matron');

drop policy if exists "admin reads nurse_visits" on public.nurse_visits;
create policy "admin reads nurse_visits"
  on public.nurse_visits for select to authenticated
  using (public.is_admin());

drop policy if exists "patient reads own nurse_visits" on public.nurse_visits;
create policy "patient reads own nurse_visits"
  on public.nurse_visits for select to authenticated
  using (patient_id = public.current_patient_id());
