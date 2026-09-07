-- Reusable fertility-cycle plans. Run after
-- 20260905200000_standard_buserelin_cycle_chart.sql.
-- Safe to run repeatedly in the Supabase SQL editor.

begin;
set local lock_timeout = '5s';

create table if not exists public.cycle_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(btrim(name)) between 3 and 100),
  description text,
  cycle_type text,
  protocol text,
  days jsonb not null
    check (jsonb_typeof(days) = 'array' and jsonb_array_length(days) > 0),
  is_system boolean not null default false,
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists cycle_templates_set_updated_at on public.cycle_templates;
create trigger cycle_templates_set_updated_at before update on public.cycle_templates
  for each row execute function public.set_updated_at();

alter table public.cycle_templates enable row level security;

drop policy if exists "cycle staff read active templates" on public.cycle_templates;
create policy "cycle staff read active templates" on public.cycle_templates for select to authenticated
  using (active and public.current_app_role() in ('doctor', 'matron', 'nurse'));

-- Writes happen through the guarded save RPC below. Direct table writes are not
-- granted so system templates cannot be silently changed by the browser.
revoke all on public.cycle_templates from anon;
revoke insert, update, delete on public.cycle_templates from authenticated;
grant select on public.cycle_templates to authenticated;

insert into public.cycle_templates(
  id, name, description, cycle_type, protocol, days, is_system
)
select
  'b57e1e11-6e99-4de3-9280-b05e7e11c001'::uuid,
  'Standard Buserelin Cycle',
  'Hospital standard down-regulation and stimulation plan. Review and individualise it for every patient.',
  'IVF Cycle',
  'Standard Buserelin Protocol',
  jsonb_agg(
    jsonb_build_object(
      'sequence_day', sequence_day,
      'offset_days', sequence_day - 1,
      'phase', case when sequence_day <= 21 then 'Down-Regulation' else 'Stimulation' end,
      'phase_key', case when sequence_day <= 21 then 'down_regulation' else 'stimulation' end,
      'phase_day', case when sequence_day <= 21 then sequence_day else sequence_day - 21 end,
      'medication', case
        when sequence_day between 1 and 14 then 'OCP'
        when sequence_day between 15 and 17 then 'Free / No scheduled medication'
        when sequence_day between 18 and 20 then 'Buserelin 0.5 ml'
        when sequence_day between 21 and 26 then 'Pure FSH 200 IU + HMG 2 ampoules + Buserelin 0.5 ml'
        when sequence_day between 27 and 28 then 'HMG 3 ampoules + Buserelin 0.5 ml'
        when sequence_day = 29 then 'HMG 3 ampoules'
        when sequence_day = 30 then 'HMG 3 ampoules + trigger as directed by the clinical team'
        else null
      end,
      'milestone', case sequence_day
        when 20 then 'Scan 1'
        when 26 then 'Scan 2'
        when 30 then 'Scan 3'
        when 32 then 'Egg Collection'
        else null
      end
    ) order by sequence_day
  ),
  true
from generate_series(1, 32) as g(sequence_day)
on conflict (name) do nothing;

create or replace function public.assert_cycle_template_staff_access(p_patient_id text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare caller_role text := public.current_app_role();
begin
  if auth.uid() is null or caller_role not in ('doctor', 'matron', 'nurse') then
    raise exception 'not authorized to manage cycle templates' using errcode = '42501';
  end if;
  if caller_role = 'doctor' and not exists (
    select 1 from public.bio_details
    where patient_id = p_patient_id and assigned_doctor_id = auth.uid()
  ) then
    raise exception 'doctor is not assigned to this patient' using errcode = '42501';
  end if;
  if caller_role = 'nurse' and not public.nurse_has_patient_access(p_patient_id) then
    raise exception 'nurse does not have access to this patient' using errcode = '42501';
  end if;
end;
$$;
revoke all on function public.assert_cycle_template_staff_access(text) from public, anon, authenticated;

create or replace function public.save_cycle_as_template(
  p_cycle_id uuid,
  p_name text,
  p_description text default null
)
returns public.cycle_templates language plpgsql security definer set search_path = public, pg_temp as $$
declare
  target_cycle public.cycles;
  saved public.cycle_templates;
  reusable_days jsonb;
  clean_name text := btrim(coalesce(p_name, ''));
begin
  select * into target_cycle from public.cycles where id = p_cycle_id;
  if not found then raise exception 'cycle not found' using errcode = 'P0002'; end if;
  perform public.assert_cycle_template_staff_access(target_cycle.patient_id);
  if target_cycle.start_date is null then raise exception 'cycle start date is required'; end if;
  if char_length(clean_name) not between 3 and 100 then
    raise exception 'template name must be between 3 and 100 characters';
  end if;
  if exists (
    select 1 from public.cycle_templates
    where lower(name) = lower(clean_name) and is_system
  ) then
    raise exception 'the hospital system template cannot be overwritten';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'sequence_day', day,
      'offset_days', date - target_cycle.start_date,
      'phase', phase,
      'phase_key', phase_key,
      'phase_day', phase_day,
      'medication', medication,
      'milestone', milestone
    ) order by day
  )
  into reusable_days
  from public.cycle_daily_logs
  where cycle_id = p_cycle_id;

  if reusable_days is null or jsonb_array_length(reusable_days) = 0 then
    raise exception 'this cycle has no daily plan to save';
  end if;

  insert into public.cycle_templates(
    name, description, cycle_type, protocol, days, created_by, updated_by
  ) values (
    clean_name, nullif(btrim(coalesce(p_description, '')), ''),
    target_cycle.type, target_cycle.protocol, reusable_days, auth.uid(), auth.uid()
  )
  on conflict (name) do update set
    description = excluded.description,
    cycle_type = excluded.cycle_type,
    protocol = excluded.protocol,
    days = excluded.days,
    active = true,
    updated_by = auth.uid()
  where not public.cycle_templates.is_system
  returning * into saved;

  if saved.id is null then raise exception 'the hospital system template cannot be overwritten'; end if;
  perform public.log_audit_event('Reusable Cycle Template Saved', saved.id::text || ' · ' || saved.name);
  return saved;
end;
$$;
revoke all on function public.save_cycle_as_template(uuid,text,text) from public, anon;
grant execute on function public.save_cycle_as_template(uuid,text,text) to authenticated;

create or replace function public.apply_cycle_template(
  p_cycle_id uuid,
  p_template_id uuid
)
returns int language plpgsql security definer set search_path = public, pg_temp as $$
declare
  target_cycle public.cycles;
  selected_template public.cycle_templates;
  item jsonb;
  inserted_count int := 0;
begin
  select * into target_cycle from public.cycles where id = p_cycle_id for update;
  if not found then raise exception 'cycle not found' using errcode = 'P0002'; end if;
  perform public.assert_cycle_template_staff_access(target_cycle.patient_id);
  if target_cycle.start_date is null then raise exception 'cycle start date is required'; end if;
  select * into selected_template from public.cycle_templates
  where id = p_template_id and active;
  if not found then raise exception 'cycle template not found' using errcode = 'P0002'; end if;
  if exists (select 1 from public.cycle_daily_logs where cycle_id = p_cycle_id) then
    raise exception 'this cycle already has a daily chart';
  end if;

  for item in select value from jsonb_array_elements(selected_template.days)
  loop
    insert into public.cycle_daily_logs(
      cycle_id, day, date, phase, phase_key, phase_day, medication, milestone,
      action_status, medication_administered, vitals_logged, updated_by
    ) values (
      p_cycle_id,
      (item->>'sequence_day')::int,
      target_cycle.start_date + (item->>'offset_days')::int,
      coalesce(nullif(item->>'phase', ''), 'Treatment'),
      coalesce(nullif(item->>'phase_key', ''), 'other'),
      greatest(coalesce((item->>'phase_day')::int, 1), 1),
      nullif(item->>'medication', ''),
      nullif(item->>'milestone', ''),
      'Planned', false, false, auth.uid()
    );
    inserted_count := inserted_count + 1;
  end loop;

  update public.cycles
  set protocol = coalesce(selected_template.protocol, protocol),
      stage = case
        when selected_template.days->0->>'phase_key' = 'down_regulation' then 'Down-Regulation'
        when selected_template.days->0->>'phase_key' = 'stimulation' then 'Stimulation'
        else stage
      end,
      cycle_day = 1
  where id = p_cycle_id;
  perform public.log_audit_event('Reusable Cycle Template Applied', p_cycle_id::text || ' · ' || selected_template.name);
  return inserted_count;
end;
$$;
revoke all on function public.apply_cycle_template(uuid,uuid) from public, anon;
grant execute on function public.apply_cycle_template(uuid,uuid) to authenticated;

-- Six-argument overload used by the UI when a saved template is selected.
-- The original five-argument function remains available for queued/offline work.
create or replace function public.start_fertility_cycle(
  p_patient_id text,
  p_type text,
  p_protocol text,
  p_start_date date,
  p_cycle_manager_id uuid,
  p_template_id uuid
)
returns public.cycles language plpgsql security definer set search_path = public, pg_temp as $$
declare
  caller_role text := public.current_app_role();
  history jsonb;
  next_number int;
  saved public.cycles;
begin
  if auth.uid() is null or caller_role not in ('doctor', 'matron', 'nurse') then
    raise exception 'not authorized to start treatment cycles' using errcode = '42501';
  end if;
  if not exists (select 1 from public.patient_names where patient_id = p_patient_id) then
    raise exception 'patient not found';
  end if;
  if caller_role = 'doctor' and not exists (
    select 1 from public.bio_details where patient_id = p_patient_id and assigned_doctor_id = auth.uid()
  ) then raise exception 'doctor is not assigned to this patient' using errcode = '42501'; end if;
  if caller_role = 'nurse' and not public.nurse_has_patient_access(p_patient_id) then
    raise exception 'nurse does not have access to this patient' using errcode = '42501'; end if;
  if exists (select 1 from public.cycles where patient_id = p_patient_id and status <> 'Closed') then
    raise exception 'patient already has an active cycle';
  end if;
  if p_cycle_manager_id is not null and not exists (
    select 1 from public.profiles where id = p_cycle_manager_id and role = 'nurse' and active
  ) then raise exception 'cycle manager must be an active Nurse'; end if;
  if p_template_id is not null and not exists (
    select 1 from public.cycle_templates where id = p_template_id and active
  ) then raise exception 'cycle template not found'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'cycle_number', cycle_number, 'type', type, 'protocol', protocol,
    'start_date', start_date, 'opu_date', opu_date, 'transfer_date', transfer_date,
    'outcome', outcome, 'status', status
  ) order by cycle_number), '[]'::jsonb), coalesce(max(cycle_number), 0) + 1
  into history, next_number from public.cycles where patient_id = p_patient_id;

  insert into public.cycles(
    patient_id, cycle_number, prior_cycles, protocol, type, start_date,
    stage, cycle_day, status, cycle_manager_id, physician_notes
  ) values (
    p_patient_id, next_number, history, p_protocol, p_type, p_start_date,
    case when p_template_id is not null or p_protocol = 'Standard Buserelin Protocol'
      then 'Down-Regulation' else 'Baseline' end,
    1, 'Active', p_cycle_manager_id,
    'Cycle started by ' || coalesce(
      (select full_name from public.profiles where id = auth.uid()),
      initcap(replace(caller_role, '_', ' '))
    ) || '.'
  )
  returning * into saved;

  update public.bio_details set status = 'Active' where patient_id = p_patient_id;
  if p_template_id is not null then
    perform public.apply_cycle_template(saved.id, p_template_id);
  elsif p_protocol = 'Standard Buserelin Protocol' then
    perform public.initialize_standard_buserelin_cycle(saved.id);
  end if;
  select * into saved from public.cycles where id = saved.id;
  perform public.log_audit_event('Treatment Cycle Started', saved.id::text || ' · ' || p_patient_id);
  return saved;
end;
$$;
revoke all on function public.start_fertility_cycle(text,text,text,date,uuid,uuid) from public, anon;
grant execute on function public.start_fertility_cycle(text,text,text,date,uuid,uuid) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'cycle_templates_table_present', to_regclass('public.cycle_templates') is not null,
  'starter_template_count', (select count(*) from public.cycle_templates where active),
  'save_template_function_present', to_regprocedure('public.save_cycle_as_template(uuid,text,text)') is not null,
  'apply_template_function_present', to_regprocedure('public.apply_cycle_template(uuid,uuid)') is not null,
  'start_with_template_function_present', to_regprocedure('public.start_fertility_cycle(text,text,text,date,uuid,uuid)') is not null
)) as reusable_cycle_template_verification;
