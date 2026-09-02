-- Phenry Health live-schema alignment.
-- Safe to run more than once. Existing clinical rows are preserved.

begin;
set local lock_timeout = '5s';

-- ---------------------------------------------------------------------------
-- Embryology: allow Day 0 and activate the policies already defined on the
-- table. The live table had policies but RLS itself was disabled.
-- ---------------------------------------------------------------------------
alter table public.embryo_batches drop constraint if exists embryo_batches_day_key_check;
alter table public.embryo_batches
  add constraint embryo_batches_day_key_check
  check (day_key in ('day0', 'day1', 'day2', 'day3', 'day5'));

alter table public.embryo_batches enable row level security;
revoke all privileges on table public.embryo_batches from anon;

drop policy if exists "doctor reads embryo_batches" on public.embryo_batches;
create policy "doctor reads embryo_batches"
  on public.embryo_batches for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));

drop policy if exists "nurse reads embryo_batches" on public.embryo_batches;
create policy "nurse reads embryo_batches"
  on public.embryo_batches for select to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id));

-- MRN counters must only be changed through the SECURITY DEFINER generator.
alter table public.mrn_sequences enable row level security;
revoke all privileges on table public.mrn_sequences from anon, authenticated;

-- Remove a duplicate legacy validation trigger. cycles_enforce_manager remains.
drop trigger if exists cycles_enforce_cycle_manager on public.cycles;

-- ---------------------------------------------------------------------------
-- Laboratory-owned equipment, supplies, media, reagents, and kits.
-- ---------------------------------------------------------------------------
alter table public.lab_equipment add column if not exists asset_code text;
alter table public.lab_equipment add column if not exists manufacturer text;
alter table public.lab_equipment add column if not exists model text;
alter table public.lab_equipment add column if not exists serial_number text;
alter table public.lab_equipment add column if not exists location text;
alter table public.lab_equipment add column if not exists purchase_date date;

alter table public.lab_store add column if not exists item_type text not null default 'Supply';
alter table public.lab_store add column if not exists manufacturer text;
alter table public.lab_store add column if not exists lot_number text;
alter table public.lab_store add column if not exists expiry_date date;
alter table public.lab_store add column if not exists received_on date;

drop policy if exists "lab tech reads lab_equipment" on public.lab_equipment;
drop policy if exists "lab tech reads lab_store" on public.lab_store;
drop policy if exists "lab tech manages lab_equipment" on public.lab_equipment;
drop policy if exists "lab tech manages lab_store" on public.lab_store;

create policy "lab tech manages lab_equipment"
  on public.lab_equipment for all to authenticated
  using (public.current_app_role() = 'lab_tech')
  with check (public.current_app_role() = 'lab_tech');

create policy "lab tech manages lab_store"
  on public.lab_store for all to authenticated
  using (public.current_app_role() = 'lab_tech')
  with check (public.current_app_role() = 'lab_tech');

-- Starter structures only: each laboratory supplies its validated reference
-- intervals before clinical use. Existing templates with these names win.
with starter_templates as (
  select *
  from jsonb_to_recordset($templates$
  [
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000001",
      "name":"SFA (Semen Fluid Analysis)",
      "category":"Andrology",
      "description":"Routine semen examination structure. Configure locally validated reference intervals before clinical use.",
      "variables":[
        {"name":"Abstinence period","unit":"days","ref":""},{"name":"Liquefaction time","unit":"minutes","ref":""},
        {"name":"Appearance","unit":"","ref":""},{"name":"Viscosity","unit":"","ref":""},{"name":"Semen volume","unit":"mL","ref":""},
        {"name":"pH","unit":"","ref":""},{"name":"Sperm concentration","unit":"million/mL","ref":""},
        {"name":"Total sperm number","unit":"million/ejaculate","ref":""},{"name":"Progressive motility","unit":"%","ref":""},
        {"name":"Non-progressive motility","unit":"%","ref":""},{"name":"Immotile sperm","unit":"%","ref":""},
        {"name":"Vitality","unit":"% live","ref":""},{"name":"Normal morphology","unit":"%","ref":""},{"name":"Leukocytes","unit":"million/mL","ref":""}
      ]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000002","name":"Sperm Preparation / Post-Wash Analysis","category":"Andrology",
      "description":"Pre- and post-preparation semen measurements for IUI, IVF, or ICSI workflows.",
      "variables":[{"name":"Preparation method","unit":"","ref":""},{"name":"Pre-wash volume","unit":"mL","ref":""},{"name":"Pre-wash concentration","unit":"million/mL","ref":""},{"name":"Pre-wash progressive motility","unit":"%","ref":""},{"name":"Post-wash volume","unit":"mL","ref":""},{"name":"Post-wash concentration","unit":"million/mL","ref":""},{"name":"Post-wash progressive motility","unit":"%","ref":""},{"name":"Total motile sperm count","unit":"million","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000003","name":"Hormonal Panel (FSH, LH, E2)","category":"Reproductive Endocrinology",
      "description":"Fertility hormone panel with cycle-day context and laboratory-specific reference intervals.",
      "variables":[{"name":"Cycle day","unit":"day","ref":""},{"name":"FSH","unit":"IU/L","ref":""},{"name":"LH","unit":"IU/L","ref":""},{"name":"Estradiol (E2)","unit":"pg/mL","ref":""},{"name":"Progesterone","unit":"ng/mL","ref":""},{"name":"Prolactin","unit":"ng/mL","ref":""},{"name":"TSH","unit":"mIU/L","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000004","name":"IVF Cycle Monitoring Panel","category":"IVF",
      "description":"Serial endocrine monitoring structure for an active ovarian-stimulation cycle.",
      "variables":[{"name":"Stimulation day","unit":"day","ref":""},{"name":"Estradiol (E2)","unit":"pg/mL","ref":""},{"name":"LH","unit":"IU/L","ref":""},{"name":"Progesterone","unit":"ng/mL","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000005","name":"Ovarian Reserve Screening","category":"Reproductive Endocrinology",
      "description":"Biochemical ovarian-reserve structure for interpretation with age, cycle timing, and ultrasound findings.",
      "variables":[{"name":"Cycle day","unit":"day","ref":""},{"name":"Anti-Müllerian hormone (AMH)","unit":"ng/mL","ref":""},{"name":"Basal FSH","unit":"IU/L","ref":""},{"name":"Basal estradiol (E2)","unit":"pg/mL","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000006","name":"Pregnancy Test (Quantitative β-hCG)","category":"Pregnancy",
      "description":"Quantitative serum beta-hCG reporting structure for serial clinical interpretation.",
      "variables":[{"name":"Beta-hCG","unit":"mIU/mL","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000007","name":"Pre-IVF Infectious Disease Screening","category":"Serology",
      "description":"Pre-treatment infectious disease screening record using the laboratory assay wording.",
      "variables":[{"name":"HIV-1/2 antigen/antibody","unit":"Reactive / Non-reactive","ref":""},{"name":"Hepatitis B surface antigen (HBsAg)","unit":"Reactive / Non-reactive","ref":""},{"name":"Hepatitis C antibody","unit":"Reactive / Non-reactive","ref":""},{"name":"Syphilis screen (RPR/VDRL)","unit":"Reactive / Non-reactive","ref":""},{"name":"Rubella IgG","unit":"IU/mL","ref":""}]
    },
    {
      "id":"6a8cb770-5697-4b71-9d67-000000000008","name":"Blood Group & Full Blood Count","category":"Haematology",
      "description":"Baseline blood-group and full-blood-count reporting structure.",
      "variables":[{"name":"ABO blood group","unit":"","ref":""},{"name":"Rhesus (RhD) type","unit":"Positive / Negative","ref":""},{"name":"Haemoglobin","unit":"g/dL","ref":""},{"name":"Packed cell volume","unit":"%","ref":""},{"name":"White blood cell count","unit":"×10⁹/L","ref":""},{"name":"Platelet count","unit":"×10⁹/L","ref":""}]
    }
  ]
  $templates$::jsonb) as template(id text, name text, category text, description text, variables jsonb)
)
insert into public.lab_templates (id, name, category, description, variables)
select id::uuid, name, category, description, variables
from starter_templates incoming
where not exists (
  select 1 from public.lab_templates existing
  where lower(existing.name) = lower(incoming.name)
)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Cycle initialization and assigned-nurse access.
-- ---------------------------------------------------------------------------
update public.cycle_daily_logs set phase = '' where phase is null;
alter table public.cycle_daily_logs alter column phase set default '';
alter table public.cycle_daily_logs alter column phase set not null;

create or replace function public.nurse_has_patient_access(p_patient_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bio_details bd
    where bd.patient_id = p_patient_id and bd.assigned_doctor_id is not null
  ) or exists (
    select 1 from public.cycles c
    where c.patient_id = p_patient_id and c.cycle_manager_id = auth.uid()
  );
$$;
revoke all on function public.nurse_has_patient_access(text) from public, anon;
grant execute on function public.nurse_has_patient_access(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Nursing observations and fertility intake.
-- ---------------------------------------------------------------------------
alter table public.nurse_visits add column if not exists respiratory_rate_bpm int;
alter table public.nurse_visits add column if not exists pain_score int;
alter table public.nurse_visits add column if not exists waist_cm numeric(5,1);
alter table public.nurse_visits add column if not exists blood_glucose_mmol_l numeric(5,1);
alter table public.nurse_visits add column if not exists visit_type text;
alter table public.nurse_visits add column if not exists chief_complaint text;
alter table public.nurse_visits add column if not exists reproductive_intake jsonb not null default '{}'::jsonb;
alter table public.nurse_visits add column if not exists medical_intake jsonb not null default '{}'::jsonb;
alter table public.bio_details add column if not exists registration_consent_at timestamptz;

alter table public.nurse_visits drop constraint if exists nurse_visits_pain_score_check;
alter table public.nurse_visits add constraint nurse_visits_pain_score_check
  check (pain_score is null or pain_score between 0 and 10);
alter table public.nurse_visits drop constraint if exists nurse_visits_respiratory_rate_check;
alter table public.nurse_visits add constraint nurse_visits_respiratory_rate_check
  check (respiratory_rate_bpm is null or respiratory_rate_bpm between 1 and 100);

comment on column public.nurse_visits.reproductive_intake is
  'Sex-appropriate fertility context reported during nursing intake; not a diagnosis.';
comment on column public.nurse_visits.medical_intake is
  'Current medications, reported allergies/conditions, lifestyle context, and triage observations.';

-- ---------------------------------------------------------------------------
-- Complete receptionist patient profile and consent timestamp.
-- ---------------------------------------------------------------------------
create or replace function public.patient_front_desk_profile_v2(p_patient_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized';
  end if;

  select to_jsonb(pn) || to_jsonb(bd) into result
  from public.patient_names pn
  join public.bio_details bd on bd.patient_id = pn.patient_id
  where pn.patient_id = p_patient_id;

  return result;
end;
$$;
revoke all on function public.patient_front_desk_profile_v2(text) from public, anon;
grant execute on function public.patient_front_desk_profile_v2(text) to authenticated;

create or replace function public.record_registration_consent(p_patient_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized';
  end if;

  update public.bio_details
  set registration_consent_at = now()
  where patient_id = p_patient_id;

  if not found then
    raise exception 'patient not found';
  end if;
end;
$$;
revoke all on function public.record_registration_consent(text) from public, anon;
grant execute on function public.record_registration_consent(text) to authenticated;

-- Trigger helpers must not be exposed as public RPCs.
revoke all on function public.create_operative_report_stub() from public, anon, authenticated;
revoke all on function public.enforce_lab_tech_incubator_update() from public, anon, authenticated;
revoke all on function public.enforce_lab_tech_tank_update() from public, anon, authenticated;
revoke all on function public.enforce_pharmacy_prescription_update() from public, anon, authenticated;
revoke all on function public.enforce_pharmacy_requisition_update() from public, anon, authenticated;

commit;

-- Verification: every value should be true or show the new Day 0 definition.
select jsonb_pretty(jsonb_build_object(
  'embryo_rls_enabled', (
    select relrowsecurity from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'embryo_batches'
  ),
  'mrn_rls_enabled', (
    select relrowsecurity from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'mrn_sequences'
  ),
  'embryo_day_constraint', (
    select pg_get_constraintdef(oid, true) from pg_constraint
    where conname = 'embryo_batches_day_key_check'
      and conrelid = 'public.embryo_batches'::regclass
  ),
  'cycle_phase_default', (
    select column_default from information_schema.columns
    where table_schema = 'public' and table_name = 'cycle_daily_logs' and column_name = 'phase'
  ),
  'required_columns_present', not exists (
    select 1
    from (values
      ('lab_equipment','asset_code'), ('lab_equipment','serial_number'), ('lab_equipment','purchase_date'),
      ('lab_store','item_type'), ('lab_store','lot_number'), ('lab_store','expiry_date'),
      ('nurse_visits','respiratory_rate_bpm'), ('nurse_visits','pain_score'), ('nurse_visits','waist_cm'),
      ('nurse_visits','blood_glucose_mmol_l'), ('nurse_visits','visit_type'), ('nurse_visits','chief_complaint'),
      ('nurse_visits','reproductive_intake'), ('nurse_visits','medical_intake'),
      ('bio_details','registration_consent_at')
    ) required(table_name, column_name)
    where not exists (
      select 1 from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = required.table_name
        and c.column_name = required.column_name
    )
  ),
  'required_functions_present',
    to_regprocedure('public.patient_front_desk_profile_v2(text)') is not null
    and to_regprocedure('public.record_registration_consent(text)') is not null,
  'starter_template_count', (
    select count(*) from public.lab_templates
    where lower(name) in (
      'sfa (semen fluid analysis)',
      'sperm preparation / post-wash analysis',
      'hormonal panel (fsh, lh, e2)',
      'ivf cycle monitoring panel',
      'ovarian reserve screening',
      'pregnancy test (quantitative β-hcg)',
      'pre-ivf infectious disease screening',
      'blood group & full blood count'
    )
  ),
  'duplicate_cycle_manager_trigger_removed', not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.cycles'::regclass
      and tgname = 'cycles_enforce_cycle_manager'
      and not tgisinternal
  )
)) as alignment_verification;
