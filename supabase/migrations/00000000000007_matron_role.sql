-- ============================================================================
-- Phenry Health — Matron role migration
--
-- SCHEMA CORRECTION (spec wins): spec §1 explicitly gives
-- `surgery_schedule.assigned_provider_id` (not assigned_doctor_id — Matron
-- can be primary surgeon too, per the prototype's own opNotes.surgeon
-- dropdown listing both doctor and matron staff) and a SEPARATE
-- `operative_reports` table (surgery_id, pre_op jsonb, op_notes jsonb,
-- post_op jsonb), not the single `report jsonb` column I built in the
-- Doctor migration from the prototype's in-memory shape. Correcting forward
-- here rather than rewriting an already-shipped migration.
-- ============================================================================

alter table public.surgery_schedule rename column assigned_doctor_id to assigned_provider_id;
alter table public.surgery_schedule drop column report;

create table public.operative_reports (
  surgery_id uuid primary key references public.surgery_schedule (id) on delete cascade,
  pre_op jsonb not null default '{"consentVerified": false, "fastingConfirmed": false, "gownChanged": false, "allergiesReviewed": false, "notes": ""}',
  op_notes jsonb not null default '{"surgeon": "", "anesthetist": "", "narrative": "", "eggsRetrieved": "", "complications": "No"}',
  post_op jsonb not null default '{"recoveryInstructions": "", "painManagement": "", "dischargeCriteriaMet": false}',
  updated_at timestamptz not null default now()
);
create trigger operative_reports_set_updated_at before update on public.operative_reports for each row execute function public.set_updated_at();

-- A surgery_schedule row should always have a matching (default-valued)
-- report row so the UI never has to special-case "no report yet".
create or replace function public.create_operative_report_stub()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.operative_reports (surgery_id) values (new.id);
  return new;
end;
$$;
create trigger surgery_schedule_create_report_stub
  after insert on public.surgery_schedule
  for each row execute function public.create_operative_report_stub();

-- ----------------------------------------------------------------------------
-- patient_names/bio_details/cycles/consultations/appointments/payment_plans/
-- payment_milestones/prescriptions: Matron gets "full" / "all-access" —
-- broader than Doctor's assigned-only scoping, no "own patients" narrowing.
-- ----------------------------------------------------------------------------
create policy "matron full access to patient_names"
  on public.patient_names for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to bio_details"
  on public.bio_details for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to cycles"
  on public.cycles for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to cycle_daily_logs"
  on public.cycle_daily_logs for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to cycle_investigations"
  on public.cycle_investigations for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to cycle_ultrasounds"
  on public.cycle_ultrasounds for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to consultations"
  on public.consultations for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron reads/writes appointments"
  on public.appointments for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to payment_plans"
  on public.payment_plans for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron full access to payment_milestones"
  on public.payment_milestones for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
create policy "matron creates/reads prescriptions"
  on public.prescriptions for all to authenticated
  using (public.current_app_role() = 'matron')
  with check (public.current_app_role() = 'matron' and prescribed_by_role = 'matron' and prescribed_by_profile_id = auth.uid());
create policy "matron reads lab_results"
  on public.lab_results for select to authenticated
  using (public.current_app_role() = 'matron');

-- ----------------------------------------------------------------------------
-- surgery_schedule / operative_reports: full scheduling + report authority.
-- ----------------------------------------------------------------------------
create policy "matron full access to surgery_schedule"
  on public.surgery_schedule for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
alter table public.operative_reports enable row level security;
create policy "matron full access to operative_reports"
  on public.operative_reports for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
-- Doctor also gets report access — Consultation lets Doctor schedule
-- procedures too (§3.4 openScheduleProcedureModal is shared), and §3.5's
-- opNotes.surgeon dropdown lists doctors as possible primary surgeons.
create policy "doctor full access to operative_reports for their procedures"
  on public.operative_reports for all to authenticated
  using (public.current_app_role() = 'doctor' and exists (select 1 from public.surgery_schedule s where s.id = operative_reports.surgery_id and s.assigned_provider_id = auth.uid()))
  with check (public.current_app_role() = 'doctor' and exists (select 1 from public.surgery_schedule s where s.id = operative_reports.surgery_id and s.assigned_provider_id = auth.uid()));

-- ----------------------------------------------------------------------------
-- recovery_beds: occupy (via Schedule Procedure's bed allocation) + discharge.
-- ----------------------------------------------------------------------------
create policy "matron manages recovery_beds"
  on public.recovery_beds for update to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
-- Doctor also needs to be able to occupy a bed at the moment they schedule
-- a procedure with a bed selected (ScheduleProcedureModal is shared).
create policy "doctor occupies a bed when scheduling a procedure"
  on public.recovery_beds for update to authenticated
  using (public.current_app_role() = 'doctor' and status = 'Free')
  with check (public.current_app_role() = 'doctor' and status = 'Occupied');

-- ----------------------------------------------------------------------------
-- duty_roster (§1: date PK, morning/afternoon/night text[] — staff NAMES,
-- exactly as specified, not a normalized FK array). Matron-editable, Nurse
-- read-only (added in Nurse's migration).
-- ----------------------------------------------------------------------------
create table public.duty_roster (
  date date primary key,
  morning text[] not null default '{}',
  afternoon text[] not null default '{}',
  night text[] not null default '{}'
);
alter table public.duty_roster enable row level security;
create policy "matron manages duty_roster"
  on public.duty_roster for all to authenticated
  using (public.current_app_role() = 'matron') with check (public.current_app_role() = 'matron');
