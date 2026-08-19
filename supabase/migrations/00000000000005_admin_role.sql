-- ============================================================================
-- Phenry Health — Admin Manager role migration
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles.active — "Revoke System Access" needs a real flag, not just a
-- cosmetic status string. Checked by middleware/auth.global.ts to actually
-- block login, not just gray out a UI row.
-- ----------------------------------------------------------------------------
alter table public.profiles add column active boolean not null default true;

-- ----------------------------------------------------------------------------
-- audit_log (§2.2 "exclusive" to Admin). No INSERT/UPDATE/DELETE policy is
-- granted to `authenticated` at all — the only way in is log_audit_event(),
-- a SECURITY DEFINER function trusted callers invoke internally. This is
-- what "comprehensive immutable record" (the prototype's own audit-page
-- copy) actually requires: not even Admin can edit it from the client.
-- ----------------------------------------------------------------------------
create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  staff_name text not null,
  role text not null,
  action_type text not null,
  target text,
  created_at timestamptz not null default now()
);
create index audit_log_created_at_idx on public.audit_log (created_at desc);

create or replace function public.log_audit_event(p_action_type text, p_target text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  actor_role text;
begin
  select coalesce(full_name, 'Unknown'), coalesce(role, custom_role_key, 'unknown')
    into actor_name, actor_role
    from public.profiles where id = auth.uid();

  insert into public.audit_log (actor_id, staff_name, role, action_type, target)
  values (auth.uid(), coalesce(actor_name, 'Unknown'), coalesce(actor_role, 'unknown'), p_action_type, p_target);
end;
$$;

alter table public.audit_log enable row level security;
create policy "admin exclusively reads audit_log"
  on public.audit_log for select to authenticated
  using (public.is_admin());

-- register_new_patient (Receptionist migration) didn't log to audit_log yet
-- because audit_log didn't exist until now — closing that gap here rather
-- than carrying it forward.
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

  perform public.log_audit_event('Created Record', new_patient_id);

  return query select new_patient_id, new_patient_id;
end;
$$;

-- ----------------------------------------------------------------------------
-- Financial approvals — RPCs instead of raw client UPDATEs, both so the
-- status transition is enforced server-side (same reasoning as the
-- Patient-role trigger) and so every approval/rejection is audit-logged.
-- The prototype's "reject" sets status back to a plain "Pending" — spec's
-- own enum for payment_milestones.status is Upcoming|Pending
-- Verification|Paid, so "reject" here reverts to Upcoming (its closest
-- real equivalent) rather than a status the schema doesn't have.
-- ----------------------------------------------------------------------------
create or replace function public.approve_milestone(p_milestone_id uuid)
returns public.payment_milestones
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.payment_milestones;
  patient_name text;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  update public.payment_milestones m
  set status = 'Paid', approved_on = current_date, approved_by = auth.uid()
  where m.id = p_milestone_id
  returning * into result;

  select pn.full_name into patient_name
  from public.payment_plans pp join public.patient_names pn on pn.patient_id = pp.patient_id
  where pp.id = result.plan_id;

  perform public.log_audit_event('Authorized Payment', patient_name);
  return result;
end;
$$;
grant execute on function public.approve_milestone(uuid) to authenticated;

create or replace function public.reject_milestone(p_milestone_id uuid)
returns public.payment_milestones
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.payment_milestones;
  patient_name text;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;

  update public.payment_milestones m
  set status = 'Upcoming', proof_url = null
  where m.id = p_milestone_id
  returning * into result;

  select pn.full_name into patient_name
  from public.payment_plans pp join public.patient_names pn on pn.patient_id = pp.patient_id
  where pp.id = result.plan_id;

  perform public.log_audit_event('Flagged Payment', patient_name);
  return result;
end;
$$;
grant execute on function public.reject_milestone(uuid) to authenticated;

-- Admin gets to see proof-of-payment images regardless of which patient
-- folder they're in (Receptionist migration only let a patient read their
-- own folder).
create policy "admin reads all payment proof uploads"
  on storage.objects for select to authenticated
  using (bucket_id = 'payment-proofs' and public.is_admin());

-- ----------------------------------------------------------------------------
-- clinic_settings: Admin write access + a monthly acquisition target. The
-- target is a business-set goal, not something derived from data — there's
-- nowhere else in spec §1 to put it, and it's needed for the Growth
-- Executive View's "X of target" comparison. No settings-page control for
-- it yet (the prototype's own Settings page doesn't expose one either) —
-- it's just a sane configurable default (35, matching the prototype).
-- ----------------------------------------------------------------------------
alter table public.clinic_settings add column monthly_acquisition_target int not null default 35;

create policy "admin updates clinic_settings"
  on public.clinic_settings for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- recovery_beds — minimal structure now (Admin's Operations view needs an
-- occupancy count). Matron's migration adds the write-side occupy/discharge
-- workflow and its own RLS on top of this same table.
-- ----------------------------------------------------------------------------
create table public.recovery_beds (
  id text primary key,
  status text not null default 'Free' check (status in ('Free', 'Occupied')),
  occupied_by_patient_id text references public.patient_names (patient_id),
  occupied_since timestamptz
);
insert into public.recovery_beds (id) values ('B-01'), ('B-02'), ('B-03'), ('B-04'), ('B-05'), ('B-06'), ('B-07'), ('B-08')
on conflict (id) do nothing;

alter table public.recovery_beds enable row level security;
create policy "any authenticated user reads recovery_beds"
  on public.recovery_beds for select to authenticated
  using (true);

-- ----------------------------------------------------------------------------
-- Admin: full read (and, per §2.2, write) on the clinical tables, so the
-- shared Patients search/detail page (components/shared/PatientsSearchPage
-- + PatientDetailModal) works for Admin now and for Doctor/Matron/Nurse
-- once their migrations add their own (differently-scoped) policies here.
-- ----------------------------------------------------------------------------
create policy "admin full access to patient_names"
  on public.patient_names for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to bio_details"
  on public.bio_details for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to cycles"
  on public.cycles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to cycle_daily_logs"
  on public.cycle_daily_logs for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to cycle_investigations"
  on public.cycle_investigations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to cycle_ultrasounds"
  on public.cycle_ultrasounds for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin reads consultations"
  on public.consultations for select to authenticated
  using (public.is_admin());
create policy "admin reads lab_results"
  on public.lab_results for select to authenticated
  using (public.is_admin());
create policy "admin full access to payment_plans"
  on public.payment_plans for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "admin full access to payment_milestones"
  on public.payment_milestones for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- Executive View aggregates (§0.3 — Doctor reuses this too; Stakeholder
-- will when that role is built). SECURITY DEFINER + explicit role gate so
-- the underlying per-patient rows never need to be exposed to any of these
-- three roles just to compute a sum/count — the "architecturally
-- impossible to see patient PII" bar applies to Doctor's exec view too,
-- not just Stakeholder's.
-- ----------------------------------------------------------------------------
create or replace function public.exec_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if public.current_app_role() not in ('admin_manager', 'doctor', 'stakeholder') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'total_revenue', coalesce((select sum(amount) from public.payment_milestones where status = 'Paid'), 0),
    'active_cycles', (select count(*) from public.cycles where status <> 'Closed'),
    -- No formal outcome taxonomy exists yet in spec §1 (see chat) — this is
    -- a best-effort match on the only positive-outcome strings observed in
    -- the prototype's mock data ("Positive", "Biochemical Pregnancy").
    'success_rate', (
      select case when count(*) filter (where status = 'Closed') = 0 then 0
        else round(100.0 * count(*) filter (where status = 'Closed' and (outcome ilike '%positive%' or outcome ilike '%pregnan%')) / count(*) filter (where status = 'Closed'))
      end
      from public.cycles
    ),
    'monthly_acquisition', (select count(*) from public.bio_details where registered_on >= date_trunc('month', current_date)),
    'acquisition_target', (select monthly_acquisition_target from public.clinic_settings where id = 1),
    'revenue_by_month', (
      select coalesce(jsonb_agg(jsonb_build_object('m', to_char(month, 'Mon'), 'v', total) order by month), '[]'::jsonb)
      from (
        select date_trunc('month', gs)::date as month,
               coalesce((select sum(amount) from public.payment_milestones where status = 'Paid' and date_trunc('month', approved_on) = date_trunc('month', gs)), 0) as total
        from generate_series(date_trunc('month', current_date) - interval '5 months', date_trunc('month', current_date), interval '1 month') gs
      ) months
    ),
    'treatment_breakdown', (
      select coalesce(jsonb_agg(jsonb_build_object('label', type, 'pct', pct)), '[]'::jsonb)
      from (
        select coalesce(type, 'Unspecified') as type, round(100.0 * count(*) / greatest(1, (select count(*) from public.cycles))) as pct
        from public.cycles group by type
      ) t
    )
  ) into result;

  return result;
end;
$$;
grant execute on function public.exec_overview() to authenticated;

create or replace function public.exec_financials()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if public.current_app_role() not in ('admin_manager', 'doctor', 'stakeholder') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'collected_revenue', coalesce((select sum(amount) from public.payment_milestones where status = 'Paid'), 0),
    'outstanding_revenue', coalesce((select sum(amount) from public.payment_milestones where status <> 'Paid'), 0),
    'active_payment_plans', (select count(*) from public.payment_plans),
    'revenue_by_package', (
      select coalesce(jsonb_agg(jsonb_build_object('package', package, 'plans', plans, 'total', total, 'collected', collected)), '[]'::jsonb)
      from (
        select pp.package,
               count(distinct pp.id) as plans,
               sum(pp.total_cost) as total,
               coalesce(sum(m.amount) filter (where m.status = 'Paid'), 0) as collected
        from public.payment_plans pp
        left join public.payment_milestones m on m.plan_id = pp.id
        group by pp.package
      ) x
    )
  ) into result;

  return result;
end;
$$;
grant execute on function public.exec_financials() to authenticated;

create or replace function public.exec_operations()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if public.current_app_role() not in ('admin_manager', 'doctor', 'stakeholder') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'cycles_in_progress', (select count(*) from public.cycles where status = 'Active'),
    'beds_occupied', (select count(*) from public.recovery_beds where status = 'Occupied'),
    'beds_total', (select count(*) from public.recovery_beds),
    'clinical_staff_count', (select count(*) from public.profiles where active and role in ('doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech', 'pharmacy')),
    'stage_distribution', (
      select coalesce(jsonb_agg(jsonb_build_object('stage', stage, 'n', n) order by ord), '[]'::jsonb)
      from (
        select s.stage, s.ord, (select count(*) from public.cycles c where c.stage = s.stage) as n
        from (values ('Baseline', 1), ('Stimulation', 2), ('OPU', 3), ('Transfer', 4), ('Closed', 5)) as s(stage, ord)
      ) counted
    )
  ) into result;

  return result;
end;
$$;
grant execute on function public.exec_operations() to authenticated;

create or replace function public.exec_growth()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  result jsonb;
begin
  if public.current_app_role() not in ('admin_manager', 'doctor', 'stakeholder') then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'monthly_acquisition', (select count(*) from public.bio_details where registered_on >= date_trunc('month', current_date)),
    'acquisition_target', (select monthly_acquisition_target from public.clinic_settings where id = 1),
    'referral_breakdown', (
      select coalesce(jsonb_agg(jsonb_build_object('source', coalesce(referral_source, 'Unknown'), 'n', n) order by n desc), '[]'::jsonb)
      from (select referral_source, count(*) as n from public.bio_details group by referral_source) r
    )
  ) into result;

  return result;
end;
$$;
grant execute on function public.exec_growth() to authenticated;
