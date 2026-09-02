-- Embryology workspace: Day 0 grading, starter result templates, and a
-- lab-owned equipment / supplies register.

-- Oocyte maturity is assessed on Day 0, before the Day 1 fertilization check.
alter table public.embryo_batches drop constraint if exists embryo_batches_day_key_check;
alter table public.embryo_batches
  add constraint embryo_batches_day_key_check
  check (day_key in ('day0', 'day1', 'day2', 'day3', 'day5'));

-- Asset identity and location fields needed for a useful equipment register.
alter table public.lab_equipment add column if not exists asset_code text;
alter table public.lab_equipment add column if not exists manufacturer text;
alter table public.lab_equipment add column if not exists model text;
alter table public.lab_equipment add column if not exists serial_number text;
alter table public.lab_equipment add column if not exists location text;
alter table public.lab_equipment add column if not exists purchase_date date;

-- Traceability fields for media, consumables, reagents, and test kits.
alter table public.lab_store add column if not exists item_type text not null default 'Supply';
alter table public.lab_store add column if not exists manufacturer text;
alter table public.lab_store add column if not exists lot_number text;
alter table public.lab_store add column if not exists expiry_date date;
alter table public.lab_store add column if not exists received_on date;

-- The lab team owns these records. Chief Embryologist already has full access;
-- Lab Technicians now have the same operational CRUD access instead of being
-- limited to a pharmacy-style read-only list.
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

-- Starter templates intentionally do not impose universal reference ranges.
-- Each laboratory should enter the intervals validated for its assay and
-- specimen method in the template editor before clinical use.
insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000001'::uuid,
  'SFA (Semen Fluid Analysis)',
  'Andrology',
  'Routine semen examination structure. Configure locally validated reference intervals before clinical use.',
  '[
    {"name":"Abstinence period","unit":"days","ref":""},
    {"name":"Liquefaction time","unit":"minutes","ref":""},
    {"name":"Appearance","unit":"","ref":""},
    {"name":"Viscosity","unit":"","ref":""},
    {"name":"Semen volume","unit":"mL","ref":""},
    {"name":"pH","unit":"","ref":""},
    {"name":"Sperm concentration","unit":"million/mL","ref":""},
    {"name":"Total sperm number","unit":"million/ejaculate","ref":""},
    {"name":"Progressive motility","unit":"%","ref":""},
    {"name":"Non-progressive motility","unit":"%","ref":""},
    {"name":"Immotile sperm","unit":"%","ref":""},
    {"name":"Vitality","unit":"% live","ref":""},
    {"name":"Normal morphology","unit":"%","ref":""},
    {"name":"Leukocytes","unit":"million/mL","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) in ('sfa (semen fluid analysis)', 'semen fluid analysis', 'semen analysis'));

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000002'::uuid,
  'Sperm Preparation / Post-Wash Analysis',
  'Andrology',
  'Pre- and post-preparation semen measurements for IUI, IVF, or ICSI laboratory workflows.',
  '[
    {"name":"Preparation method","unit":"","ref":""},
    {"name":"Pre-wash volume","unit":"mL","ref":""},
    {"name":"Pre-wash concentration","unit":"million/mL","ref":""},
    {"name":"Pre-wash progressive motility","unit":"%","ref":""},
    {"name":"Post-wash volume","unit":"mL","ref":""},
    {"name":"Post-wash concentration","unit":"million/mL","ref":""},
    {"name":"Post-wash progressive motility","unit":"%","ref":""},
    {"name":"Total motile sperm count","unit":"million","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) = 'sperm preparation / post-wash analysis');

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000003'::uuid,
  'Hormonal Panel (FSH, LH, E2)',
  'Reproductive Endocrinology',
  'Fertility hormone reporting panel. Record cycle day and apply assay-specific reference intervals.',
  '[
    {"name":"Cycle day","unit":"day","ref":""},
    {"name":"FSH","unit":"IU/L","ref":""},
    {"name":"LH","unit":"IU/L","ref":""},
    {"name":"Estradiol (E2)","unit":"pg/mL","ref":""},
    {"name":"Progesterone","unit":"ng/mL","ref":""},
    {"name":"Prolactin","unit":"ng/mL","ref":""},
    {"name":"TSH","unit":"mIU/L","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) in ('hormonal panel (fsh, lh, e2)', 'hormonal screening'));

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000004'::uuid,
  'IVF Cycle Monitoring Panel',
  'IVF',
  'Serial endocrine monitoring structure for an active ovarian-stimulation cycle.',
  '[
    {"name":"Stimulation day","unit":"day","ref":""},
    {"name":"Estradiol (E2)","unit":"pg/mL","ref":""},
    {"name":"LH","unit":"IU/L","ref":""},
    {"name":"Progesterone","unit":"ng/mL","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) = 'ivf cycle monitoring panel');

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000005'::uuid,
  'Ovarian Reserve Screening',
  'Reproductive Endocrinology',
  'Biochemical ovarian-reserve report. Interpret alongside age, cycle timing, ultrasound findings, and treatment context.',
  '[
    {"name":"Cycle day","unit":"day","ref":""},
    {"name":"Anti-Müllerian hormone (AMH)","unit":"ng/mL","ref":""},
    {"name":"Basal FSH","unit":"IU/L","ref":""},
    {"name":"Basal estradiol (E2)","unit":"pg/mL","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) = 'ovarian reserve screening');

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000006'::uuid,
  'Pregnancy Test (Quantitative β-hCG)',
  'Pregnancy',
  'Quantitative serum beta-hCG reporting template. Interpret serially and in clinical context.',
  '[{"name":"Beta-hCG","unit":"mIU/mL","ref":""}]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) in ('pregnancy test (quantitative β-hcg)', 'pregnancy test', 'beta-hcg'));

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000007'::uuid,
  'Pre-IVF Infectious Disease Screening',
  'Serology',
  'Structured screening record. Use the laboratory assay result wording and follow the clinic testing protocol.',
  '[
    {"name":"HIV-1/2 antigen/antibody","unit":"Reactive / Non-reactive","ref":""},
    {"name":"Hepatitis B surface antigen (HBsAg)","unit":"Reactive / Non-reactive","ref":""},
    {"name":"Hepatitis C antibody","unit":"Reactive / Non-reactive","ref":""},
    {"name":"Syphilis screen (RPR/VDRL)","unit":"Reactive / Non-reactive","ref":""},
    {"name":"Rubella IgG","unit":"IU/mL","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) = 'pre-ivf infectious disease screening');

insert into public.lab_templates (id, name, category, description, variables)
select
  '6a8cb770-5697-4b71-9d67-000000000008'::uuid,
  'Blood Group & Full Blood Count',
  'Haematology',
  'Baseline blood group and haematology reporting structure.',
  '[
    {"name":"ABO blood group","unit":"","ref":""},
    {"name":"Rhesus (RhD) type","unit":"Positive / Negative","ref":""},
    {"name":"Haemoglobin","unit":"g/dL","ref":""},
    {"name":"Packed cell volume","unit":"%","ref":""},
    {"name":"White blood cell count","unit":"×10⁹/L","ref":""},
    {"name":"Platelet count","unit":"×10⁹/L","ref":""}
  ]'::jsonb
where not exists (select 1 from public.lab_templates where lower(name) in ('blood group & full blood count', 'blood screening'));
