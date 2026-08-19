-- ============================================================================
-- Phenry Health — Nurse role migration
--
-- INTERPRETATION CALL (flagging, not silently deciding): spec §2.2 scopes
-- Nurse's patient/cycle access to "assigned" — but there is no
-- assigned_nurse_id anywhere in spec §1's schema, only bio_details.
-- assigned_doctor_id (a single doctor). Since nurses aren't individually
-- assigned to patients anywhere in the data model, and the prototype's own
-- nurseVisit page shows every registered patient with zero filtering, I've
-- read "assigned" here as "patients under active care" — i.e.
-- assigned_doctor_id IS NOT NULL — rather than something tied to a specific
-- nurse. In practice this covers nearly every registered patient. If a real
-- nurse-to-patient assignment concept is wanted, that's a schema addition
-- worth discussing rather than guessing at further.
--
-- FLAGGED SPEC-VS-PROTOTYPE CONFLICT: nurse.js passes allowCreate:true to
-- the Macro Cycle View (nurses can Start New Cycle in the prototype). Spec
-- §2.2's matrix gives Nurse only "assigned, read/write LOGS" on cycles —
-- logs, not the cycle record itself. Per your rule, spec wins: Nurse does
-- NOT get cycles INSERT here, and the Nurse wrapper page passes
-- allow-create=false, overriding the prototype. Worth double-checking —
-- in practice it's often a nurse who kicks off a new cycle's paperwork.
-- ============================================================================

create or replace function public.nurse_has_patient_access(p_patient_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.bio_details bd where bd.patient_id = p_patient_id and bd.assigned_doctor_id is not null);
$$;

create policy "nurse reads assigned patient_names"
  on public.patient_names for select to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id));
create policy "nurse reads assigned bio_details"
  on public.bio_details for select to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id));

-- cycles: read-only (see flagged conflict above — no insert/update for Nurse)
create policy "nurse reads assigned cycles"
  on public.cycles for select to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id));

-- cycle_daily_logs: the one thing spec explicitly says Nurse can WRITE
create policy "nurse reads/writes cycle_daily_logs for assigned patients"
  on public.cycle_daily_logs for all to authenticated
  using (public.current_app_role() = 'nurse' and exists (select 1 from public.cycles c where c.id = cycle_daily_logs.cycle_id and public.nurse_has_patient_access(c.patient_id)))
  with check (public.current_app_role() = 'nurse' and exists (select 1 from public.cycles c where c.id = cycle_daily_logs.cycle_id and public.nurse_has_patient_access(c.patient_id)));

create policy "nurse reads cycle_investigations"
  on public.cycle_investigations for select to authenticated
  using (public.current_app_role() = 'nurse' and exists (select 1 from public.cycles c where c.id = cycle_investigations.cycle_id and public.nurse_has_patient_access(c.patient_id)));
create policy "nurse reads cycle_ultrasounds"
  on public.cycle_ultrasounds for select to authenticated
  using (public.current_app_role() = 'nurse' and exists (select 1 from public.cycles c where c.id = cycle_ultrasounds.cycle_id and public.nurse_has_patient_access(c.patient_id)));

-- appointments: read-only
create policy "nurse reads appointments"
  on public.appointments for select to authenticated
  using (public.current_app_role() = 'nurse');

-- payment_plans/milestones: read-only (no creation UI exists for Nurse in
-- the prototype despite the matrix's conditional "create (if policy
-- allows)" wording — nothing grants that policy by default)
create policy "nurse reads payment_plans"
  on public.payment_plans for select to authenticated
  using (public.current_app_role() = 'nurse');
create policy "nurse reads payment_milestones"
  on public.payment_milestones for select to authenticated
  using (public.current_app_role() = 'nurse');

-- prescriptions: full create/read per §0.1
create policy "nurse creates/reads prescriptions for accessible patients"
  on public.prescriptions for all to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id))
  with check (public.current_app_role() = 'nurse' and prescribed_by_role = 'nurse' and prescribed_by_profile_id = auth.uid() and public.nurse_has_patient_access(patient_id));

-- surgery_schedule/operative_reports/recovery_beds: not a matrix row, but
-- nurse.js explicitly passes allowSchedule:true and shares the same
-- Recovery Beds page as Matron — granting parity, same as Doctor got.
create policy "nurse full access to surgery_schedule"
  on public.surgery_schedule for all to authenticated
  using (public.current_app_role() = 'nurse') with check (public.current_app_role() = 'nurse');
create policy "nurse full access to operative_reports"
  on public.operative_reports for all to authenticated
  using (public.current_app_role() = 'nurse') with check (public.current_app_role() = 'nurse');
create policy "nurse manages recovery_beds"
  on public.recovery_beds for update to authenticated
  using (public.current_app_role() = 'nurse') with check (public.current_app_role() = 'nurse');

-- duty_roster: read-only, exactly per §1's own description ("Nurse read-only view")
create policy "nurse reads duty_roster"
  on public.duty_roster for select to authenticated
  using (public.current_app_role() = 'nurse');

-- ----------------------------------------------------------------------------
-- requisitions (§1 schema, new table — Nurse's Ward Requisition page).
-- ----------------------------------------------------------------------------
create table public.requisitions (
  id uuid primary key default gen_random_uuid(),
  requested_by_profile_id uuid references public.profiles (id),
  ward text not null default 'IVF Ward 2',
  items jsonb not null default '[]',
  urgency text not null default 'Routine' check (urgency in ('Routine', 'Urgent', 'Emergency')),
  status text not null default 'Pending' check (status in ('Pending', 'Approved & Dispensed', 'Denied')),
  requested_on timestamptz not null default now()
);
create index requisitions_requested_by_idx on public.requisitions (requested_by_profile_id);

alter table public.requisitions enable row level security;
create policy "nurse creates requisitions"
  on public.requisitions for insert to authenticated
  with check (public.current_app_role() = 'nurse' and requested_by_profile_id = auth.uid());
create policy "nurse reads own requisitions"
  on public.requisitions for select to authenticated
  using (public.current_app_role() = 'nurse' and requested_by_profile_id = auth.uid());
create policy "matron reads all requisitions (oversight)"
  on public.requisitions for select to authenticated
  using (public.current_app_role() = 'matron');
create policy "admin reads all requisitions"
  on public.requisitions for select to authenticated
  using (public.is_admin());
