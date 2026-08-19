-- ============================================================================
-- Phenry Health — Doctor role migration
--
-- FLAGGED SPEC-VS-PROTOTYPE CONFLICT: the prototype's Consultation page lets
-- Doctor create follow-up appointments (scheduleFollowUp). Spec §2.2's
-- matrix gives Doctor only "read own + waiting room" on `appointments` —
-- no create. I've gone with the spec (per your rule) and made the
-- "Schedule Next Appointment" card in Consultation Matron-only for now;
-- Doctor doesn't get it. This is a real workflow restriction worth you
-- double-checking — in practice most clinics do let doctors book follow-ups
-- themselves, so if that matrix cell was meant to be broader, say so and
-- I'll open it back up.
-- ============================================================================

-- doctor_has_patient_access: "assigned + waiting-room visibility" (§2.2).
-- Permanent access to assigned patients, plus same-day access to whoever's
-- on today's schedule with this doctor (walk-ins / coverage).
create or replace function public.doctor_has_patient_access(p_patient_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bio_details bd where bd.patient_id = p_patient_id and bd.assigned_doctor_id = auth.uid()
  ) or exists (
    select 1 from public.appointments a
    where a.patient_id = p_patient_id and a.provider_profile_id = auth.uid()
      and a.provider_role = 'doctor' and a.date = current_date and a.status <> 'Cancelled'
  );
$$;

create policy "doctor reads assigned or waiting-room patient_names"
  on public.patient_names for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));
create policy "doctor reads assigned or waiting-room bio_details"
  on public.bio_details for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));

-- cycles/logs/investigations/ultrasounds: "own patients, full" — narrower
-- than the above: assigned only, not just anyone in today's waiting room.
create policy "doctor full access to own patients' cycles"
  on public.cycles for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.bio_details bd where bd.patient_id = cycles.patient_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.bio_details bd where bd.patient_id = cycles.patient_id and bd.assigned_doctor_id = auth.uid()));

create policy "doctor full access to own patients' cycle_daily_logs"
  on public.cycle_daily_logs for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_daily_logs.cycle_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_daily_logs.cycle_id and bd.assigned_doctor_id = auth.uid()));

create policy "doctor full access to own patients' cycle_investigations"
  on public.cycle_investigations for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_investigations.cycle_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_investigations.cycle_id and bd.assigned_doctor_id = auth.uid()));

create policy "doctor full access to own patients' cycle_ultrasounds"
  on public.cycle_ultrasounds for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_ultrasounds.cycle_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id where c.id = cycle_ultrasounds.cycle_id and bd.assigned_doctor_id = auth.uid()));

-- consultations: write (own), read (all via waiting room)
create policy "doctor reads all consultations"
  on public.consultations for select to authenticated
  using (public.current_app_role() = 'doctor');
create policy "doctor writes consultations for accessible patients"
  on public.consultations for insert to authenticated
  with check (public.current_app_role() = 'doctor' and provider_profile_id = auth.uid() and public.doctor_has_patient_access(patient_id));

-- appointments: read-only (see flagged note above)
create policy "doctor reads own appointments"
  on public.appointments for select to authenticated
  using (public.current_app_role() = 'doctor' and provider_profile_id = auth.uid());

-- payment_plans/milestones: create for own (assigned) patients
create policy "doctor accesses own patients' payment_plans"
  on public.payment_plans for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.bio_details bd where bd.patient_id = payment_plans.patient_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.bio_details bd where bd.patient_id = payment_plans.patient_id and bd.assigned_doctor_id = auth.uid()));
create policy "doctor accesses own patients' payment_milestones"
  on public.payment_milestones for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.payment_plans pp join public.bio_details bd on bd.patient_id = pp.patient_id where pp.id = payment_milestones.plan_id and bd.assigned_doctor_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.payment_plans pp join public.bio_details bd on bd.patient_id = pp.patient_id where pp.id = payment_milestones.plan_id and bd.assigned_doctor_id = auth.uid()));

-- prescriptions: create/read, scoped like consultations (assigned + waiting room)
-- Widening prescribed_by_role here: the prototype's own comment on this
-- shared modal is "Shared prescribing (Doctor / Matron / Nurse)" — the
-- Patient-role migration's check constraint only allowed doctor/nurse
-- because Matron's prescribing capability wasn't visible yet at that point.
alter table public.prescriptions drop constraint prescriptions_prescribed_by_role_check;
alter table public.prescriptions add constraint prescriptions_prescribed_by_role_check check (prescribed_by_role in ('doctor', 'nurse', 'matron'));

create policy "doctor reads/creates prescriptions for accessible patients"
  on public.prescriptions for all to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id))
  with check (public.current_app_role() = 'doctor' and prescribed_by_role = 'doctor' and prescribed_by_profile_id = auth.uid() and public.doctor_has_patient_access(patient_id));

-- ----------------------------------------------------------------------------
-- surgery_schedule — minimal now (Consultation's "Schedule Procedure"
-- button needs somewhere to write). Matron/Nurse's migration adds the full
-- pre-op/op-notes/post-op workflow UI on top of the same `report` jsonb
-- column, so no schema change needed later, just more RLS + UI.
-- ----------------------------------------------------------------------------
create table public.surgery_schedule (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null references public.patient_names (patient_id) on delete cascade,
  procedure text not null,
  date date not null,
  time text,
  location text,
  assigned_doctor_id uuid references public.profiles (id),
  recovery_bed_id text references public.recovery_beds (id),
  status text not null default 'Scheduled',
  notes text,
  report jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index surgery_schedule_patient_id_idx on public.surgery_schedule (patient_id);
create trigger surgery_schedule_set_updated_at before update on public.surgery_schedule for each row execute function public.set_updated_at();

alter table public.surgery_schedule enable row level security;
create policy "doctor schedules procedures for accessible patients"
  on public.surgery_schedule for insert to authenticated
  with check (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));
create policy "doctor reads procedures they scheduled or are assigned to"
  on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'doctor' and (assigned_doctor_id = auth.uid() or public.doctor_has_patient_access(patient_id)));
