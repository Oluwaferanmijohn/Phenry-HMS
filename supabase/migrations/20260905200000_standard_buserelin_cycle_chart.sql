-- Phase-based fertility cycle chart based on the hospital's standard printed
-- Buserelin chart. Safe to run repeatedly in the Supabase SQL editor.

begin;
set local lock_timeout = '5s';

alter table public.cycle_daily_logs add column if not exists phase_key text;
alter table public.cycle_daily_logs add column if not exists phase_day int;
alter table public.cycle_daily_logs add column if not exists action_status text;
alter table public.cycle_daily_logs add column if not exists actual_medication text;
alter table public.cycle_daily_logs add column if not exists administered_by uuid references public.profiles(id) on delete set null;
alter table public.cycle_daily_logs add column if not exists administered_at timestamptz;
alter table public.cycle_daily_logs add column if not exists updated_by uuid references public.profiles(id) on delete set null;
alter table public.cycle_daily_logs add column if not exists change_reason text;

update public.cycle_daily_logs
set phase_key = case when lower(coalesce(phase, '')) like '%down%' then 'down_regulation' else 'stimulation' end,
    phase_day = coalesce(phase_day, day),
    action_status = coalesce(action_status, case when medication_administered then 'Administered' else 'Planned' end)
where phase_key is null or phase_day is null or action_status is null;

alter table public.cycle_daily_logs alter column phase_key set default 'stimulation';
alter table public.cycle_daily_logs alter column phase_key set not null;
alter table public.cycle_daily_logs alter column phase_day set default 1;
alter table public.cycle_daily_logs alter column phase_day set not null;
alter table public.cycle_daily_logs alter column action_status set default 'Planned';
alter table public.cycle_daily_logs alter column action_status set not null;

alter table public.cycle_daily_logs drop constraint if exists cycle_daily_logs_phase_key_check;
alter table public.cycle_daily_logs add constraint cycle_daily_logs_phase_key_check
  check (phase_key in ('down_regulation', 'stimulation', 'procedure', 'other')) not valid;
alter table public.cycle_daily_logs validate constraint cycle_daily_logs_phase_key_check;
alter table public.cycle_daily_logs drop constraint if exists cycle_daily_logs_action_status_check;
alter table public.cycle_daily_logs add constraint cycle_daily_logs_action_status_check
  check (action_status in ('Planned', 'Administered', 'Completed', 'Held', 'Missed', 'Changed')) not valid;
alter table public.cycle_daily_logs validate constraint cycle_daily_logs_action_status_check;
alter table public.cycle_daily_logs drop constraint if exists cycle_daily_logs_phase_day_positive_check;
alter table public.cycle_daily_logs add constraint cycle_daily_logs_phase_day_positive_check check (phase_day > 0) not valid;
alter table public.cycle_daily_logs validate constraint cycle_daily_logs_phase_day_positive_check;

create table if not exists public.cycle_daily_log_audit (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.cycle_daily_logs(id) on delete cascade,
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  changed_by uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now(),
  change_reason text,
  previous_data jsonb not null,
  current_data jsonb not null
);
create index if not exists cycle_daily_log_audit_cycle_idx on public.cycle_daily_log_audit(cycle_id, changed_at desc);
alter table public.cycle_daily_log_audit enable row level security;

drop policy if exists "matron reads cycle log audit" on public.cycle_daily_log_audit;
create policy "matron reads cycle log audit" on public.cycle_daily_log_audit for select to authenticated
  using (public.current_app_role() = 'matron');
drop policy if exists "doctor reads assigned cycle log audit" on public.cycle_daily_log_audit;
create policy "doctor reads assigned cycle log audit" on public.cycle_daily_log_audit for select to authenticated
  using (public.current_app_role() = 'doctor' and exists (
    select 1 from public.cycles c join public.bio_details bd on bd.patient_id = c.patient_id
    where c.id = cycle_daily_log_audit.cycle_id and bd.assigned_doctor_id = auth.uid()
  ));
drop policy if exists "nurse reads accessible cycle log audit" on public.cycle_daily_log_audit;
create policy "nurse reads accessible cycle log audit" on public.cycle_daily_log_audit for select to authenticated
  using (public.current_app_role() = 'nurse' and exists (
    select 1 from public.cycles c where c.id = cycle_daily_log_audit.cycle_id
      and public.nurse_has_patient_access(c.patient_id)
  ));
grant select on public.cycle_daily_log_audit to authenticated;

create or replace function public.audit_cycle_daily_log_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if to_jsonb(old) is distinct from to_jsonb(new) then
    insert into public.cycle_daily_log_audit(log_id, cycle_id, changed_by, change_reason, previous_data, current_data)
    values (new.id, new.cycle_id, auth.uid(), nullif(btrim(coalesce(new.change_reason, '')), ''), to_jsonb(old), to_jsonb(new));
  end if;
  return new;
end;
$$;
drop trigger if exists cycle_daily_logs_audit_change on public.cycle_daily_logs;
create trigger cycle_daily_logs_audit_change after update on public.cycle_daily_logs
  for each row execute function public.audit_cycle_daily_log_change();
revoke all on function public.audit_cycle_daily_log_change() from public, anon, authenticated;

-- Planned future rows must not make a newly-created cycle appear to be on Day
-- 32. Progress moves only when staff document an actual action.
drop trigger if exists cycle_daily_logs_sync_cycle_day on public.cycle_daily_logs;
create or replace function public.sync_cycle_progress_from_log()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.action_status in ('Administered', 'Completed')
     and (tg_op = 'INSERT' or old.action_status is distinct from new.action_status) then
    update public.cycles
    set stage = case
          when new.phase_key = 'down_regulation' and stage in ('Baseline', 'Down-Regulation') then 'Down-Regulation'
          when new.phase_key = 'stimulation' and stage in ('Baseline', 'Down-Regulation', 'Stimulation') then 'Stimulation'
          else stage
        end,
        cycle_day = case
          when new.phase_key = 'stimulation' and stage <> 'Stimulation' then new.phase_day
          else greatest(cycle_day, new.phase_day)
        end
    where id = new.cycle_id;
  end if;
  return new;
end;
$$;
create trigger cycle_daily_logs_sync_cycle_progress after insert or update of action_status
  on public.cycle_daily_logs for each row execute function public.sync_cycle_progress_from_log();
revoke all on function public.sync_cycle_progress_from_log() from public, anon, authenticated;

create or replace function public.initialize_standard_buserelin_cycle(p_cycle_id uuid)
returns int language plpgsql security definer set search_path = public, pg_temp as $$
declare
  target_cycle public.cycles;
  caller_role text := public.current_app_role();
  sequence_day int;
  display_day int;
  inserted_count int := 0;
begin
  select * into target_cycle from public.cycles where id = p_cycle_id for update;
  if not found then raise exception 'cycle not found' using errcode = 'P0002'; end if;
  if target_cycle.start_date is null then raise exception 'cycle start date is required'; end if;
  if caller_role = 'doctor' and not exists (
    select 1 from public.bio_details bd where bd.patient_id = target_cycle.patient_id and bd.assigned_doctor_id = auth.uid()
  ) then raise exception 'not authorized for this cycle' using errcode = '42501';
  elsif caller_role = 'nurse' and not public.nurse_has_patient_access(target_cycle.patient_id) then
    raise exception 'not authorized for this cycle' using errcode = '42501';
  elsif caller_role not in ('doctor', 'matron', 'nurse') then
    raise exception 'not authorized to initialize cycle charts' using errcode = '42501';
  end if;
  if exists (select 1 from public.cycle_daily_logs where cycle_id = p_cycle_id) then
    raise exception 'this cycle already has a daily chart';
  end if;

  for sequence_day in 1..32 loop
    display_day := case when sequence_day <= 21 then sequence_day else sequence_day - 21 end;
    insert into public.cycle_daily_logs(
      cycle_id, day, date, phase, phase_key, phase_day, medication, milestone,
      action_status, medication_administered, vitals_logged, updated_by
    ) values (
      p_cycle_id,
      sequence_day,
      target_cycle.start_date + (sequence_day - 1),
      case when sequence_day <= 21 then 'Down-Regulation' else 'Stimulation' end,
      case when sequence_day <= 21 then 'down_regulation' else 'stimulation' end,
      display_day,
      case
        when sequence_day between 1 and 14 then 'OCP'
        when sequence_day between 15 and 17 then 'Free / No scheduled medication'
        when sequence_day between 18 and 20 then 'Buserelin 0.5 ml'
        when sequence_day between 21 and 26 then 'Pure FSH 200 IU + HMG 2 ampoules + Buserelin 0.5 ml'
        when sequence_day between 27 and 28 then 'HMG 3 ampoules + Buserelin 0.5 ml'
        when sequence_day = 29 then 'HMG 3 ampoules'
        when sequence_day = 30 then 'HMG 3 ampoules + trigger as directed by the clinical team'
        else null
      end,
      case sequence_day when 20 then 'Scan 1' when 26 then 'Scan 2' when 30 then 'Scan 3' when 32 then 'Egg Collection' else null end,
      'Planned', false, false, auth.uid()
    );
    inserted_count := inserted_count + 1;
  end loop;
  update public.cycles set protocol = 'Standard Buserelin Protocol', stage = 'Down-Regulation', cycle_day = 1 where id = p_cycle_id;
  perform public.log_audit_event('Standard Buserelin Cycle Chart Initialized', p_cycle_id::text);
  return inserted_count;
end;
$$;
revoke all on function public.initialize_standard_buserelin_cycle(uuid) from public, anon;
grant execute on function public.initialize_standard_buserelin_cycle(uuid) to authenticated;

-- The user has confirmed that Nurses have the same operational cycle powers as
-- Doctors and Matrons for patients accessible to the nursing team.
drop policy if exists "nurse reads assigned cycles" on public.cycles;
drop policy if exists "nurse manages accessible cycles" on public.cycles;
create policy "nurse manages accessible cycles" on public.cycles for all to authenticated
  using (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id))
  with check (public.current_app_role() = 'nurse' and public.nurse_has_patient_access(patient_id));

create or replace function public.start_fertility_cycle(
  p_patient_id text,
  p_type text,
  p_protocol text,
  p_start_date date,
  p_cycle_manager_id uuid default null
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
  if not exists (select 1 from public.patient_names where patient_id = p_patient_id) then raise exception 'patient not found'; end if;
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

  select coalesce(jsonb_agg(jsonb_build_object(
    'cycle_number', cycle_number, 'type', type, 'protocol', protocol,
    'start_date', start_date, 'opu_date', opu_date, 'transfer_date', transfer_date,
    'outcome', outcome, 'status', status
  ) order by cycle_number), '[]'::jsonb), coalesce(max(cycle_number), 0) + 1
  into history, next_number from public.cycles where patient_id = p_patient_id;

  insert into public.cycles(patient_id, cycle_number, prior_cycles, protocol, type, start_date, stage, cycle_day, status, cycle_manager_id, physician_notes)
  values (p_patient_id, next_number, history, p_protocol, p_type, p_start_date,
    case when p_protocol = 'Standard Buserelin Protocol' then 'Down-Regulation' else 'Baseline' end,
    1, 'Active', p_cycle_manager_id, 'Cycle started by ' || coalesce((select full_name from public.profiles where id = auth.uid()), initcap(replace(caller_role, '_', ' '))) || '.')
  returning * into saved;

  update public.bio_details set status = 'Active' where patient_id = p_patient_id;
  if p_protocol = 'Standard Buserelin Protocol' then perform public.initialize_standard_buserelin_cycle(saved.id); end if;
  select * into saved from public.cycles where id = saved.id;
  perform public.log_audit_event('Treatment Cycle Started', saved.id::text || ' · ' || p_patient_id);
  return saved;
end;
$$;
revoke all on function public.start_fertility_cycle(text,text,text,date,uuid) from public, anon;
grant execute on function public.start_fertility_cycle(text,text,text,date,uuid) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'phase_columns_present', (select count(*) = 8 from information_schema.columns where table_schema = 'public' and table_name = 'cycle_daily_logs' and column_name in ('phase_key','phase_day','action_status','actual_medication','administered_by','administered_at','updated_by','change_reason')),
  'standard_template_function_present', to_regprocedure('public.initialize_standard_buserelin_cycle(uuid)') is not null,
  'start_cycle_function_present', to_regprocedure('public.start_fertility_cycle(text,text,text,date,uuid)') is not null,
  'audit_table_present', to_regclass('public.cycle_daily_log_audit') is not null,
  'nurse_cycle_management_policy_present', exists (select 1 from pg_policies where schemaname='public' and tablename='cycles' and policyname='nurse manages accessible cycles' and cmd='ALL')
)) as standard_cycle_chart_verification;
