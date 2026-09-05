-- Unified fertility-procedure reporting and precise cryogenic storage.
-- Safe to paste into the Supabase SQL editor more than once.

begin;
set local lock_timeout = '5s';

create or replace function public.is_fertility_lab_procedure(p_procedure text)
returns boolean
language sql
immutable
set search_path = public, pg_temp
as $$
  select coalesce(p_procedure, '') ~* (
    '(^|[^a-z])(opu|iui|fet|tese|tesa|pesa|mesa|micro[- ]?tese)([^a-z]|$)'
    || '|oocyte (pick[- ]?up|retrieval|collection|freez|cryopreserv)'
    || '|egg (retrieval|collection|freez|cryopreserv)'
    || '|embryo (transfer|freez|cryopreserv|thaw|warm)'
    || '|frozen embryo transfer|intrauterine insemination'
    || '|sperm (freez|cryopreserv|thaw|preparation|retrieval)'
    || '|semen (freez|cryopreserv|preparation)'
  );
$$;

grant execute on function public.is_fertility_lab_procedure(text) to authenticated;

create table if not exists public.fertility_procedure_reports (
  schedule_id uuid primary key references public.surgery_schedule(id) on delete cascade,
  patient_id text not null references public.patient_names(patient_id) on delete cascade,
  procedure_type text not null,
  status text not null default 'Draft' check (status in ('Draft', 'Completed')),
  documentation jsonb not null default '{}'::jsonb,
  documented_by uuid references public.profiles(id) on delete set null,
  documented_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists fertility_procedure_reports_set_updated_at on public.fertility_procedure_reports;
create trigger fertility_procedure_reports_set_updated_at
before update on public.fertility_procedure_reports
for each row execute function public.set_updated_at();

alter table public.fertility_procedure_reports enable row level security;
drop policy if exists "embryology manages fertility procedure reports" on public.fertility_procedure_reports;
create policy "embryology manages fertility procedure reports"
on public.fertility_procedure_reports for all to authenticated
using (public.current_app_role() in ('chief_embryologist', 'lab_tech'))
with check (public.current_app_role() in ('chief_embryologist', 'lab_tech'));

drop policy if exists "clinical leaders read fertility procedure reports" on public.fertility_procedure_reports;
create policy "clinical leaders read fertility procedure reports"
on public.fertility_procedure_reports for select to authenticated
using (
  public.current_app_role() in ('admin_manager', 'matron')
  or (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id))
);

alter table public.cryo_records add column if not exists storage_unit_type text default 'Straw';
alter table public.cryo_records add column if not exists rack text;
alter table public.cryo_records add column if not exists cane text;
alter table public.cryo_records add column if not exists goblet text;
alter table public.cryo_records add column if not exists container_label text;
alter table public.cryo_records add column if not exists freeze_method text;
alter table public.cryo_records add column if not exists specimen_quality text;
alter table public.cryo_records add column if not exists source_procedure_id uuid references public.surgery_schedule(id) on delete set null;
alter table public.cryo_records add column if not exists witnessed_by uuid references public.profiles(id) on delete set null;
alter table public.cryo_records add column if not exists updated_at timestamptz default now();
update public.cryo_records set updated_at = coalesce(updated_at, created_at, now()) where updated_at is null;
alter table public.cryo_records alter column updated_at set not null;
drop trigger if exists cryo_records_set_updated_at on public.cryo_records;
create trigger cryo_records_set_updated_at before update on public.cryo_records
for each row execute function public.set_updated_at();

create or replace function public.save_fertility_procedure_report(
  p_schedule_id uuid,
  p_documentation jsonb,
  p_status text default 'Draft'
)
returns public.fertility_procedure_reports
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  scheduled public.surgery_schedule;
  saved public.fertility_procedure_reports;
begin
  if public.current_app_role() not in ('chief_embryologist', 'lab_tech') then
    raise exception 'not authorized to document fertility procedures' using errcode = '42501';
  end if;
  if p_status not in ('Draft', 'Completed') then raise exception 'invalid report status'; end if;
  if jsonb_typeof(coalesce(p_documentation, '{}'::jsonb)) <> 'object' then raise exception 'documentation must be an object'; end if;

  select * into scheduled from public.surgery_schedule where id = p_schedule_id for update;
  if not found then raise exception 'scheduled procedure not found' using errcode = 'P0002'; end if;
  if not public.is_fertility_lab_procedure(scheduled.procedure) then
    raise exception 'this procedure belongs on the general surgery page';
  end if;

  insert into public.fertility_procedure_reports(
    schedule_id, patient_id, procedure_type, status, documentation,
    documented_by, documented_at
  ) values (
    scheduled.id, scheduled.patient_id, scheduled.procedure, p_status,
    coalesce(p_documentation, '{}'::jsonb), auth.uid(),
    case when p_status = 'Completed' then now() else null end
  )
  on conflict (schedule_id) do update set
    patient_id = excluded.patient_id,
    procedure_type = excluded.procedure_type,
    status = excluded.status,
    documentation = excluded.documentation,
    documented_by = auth.uid(),
    documented_at = case
      when excluded.status = 'Completed' then coalesce(public.fertility_procedure_reports.documented_at, now())
      else public.fertility_procedure_reports.documented_at
    end
  returning * into saved;

  if p_status = 'Completed' then
    update public.surgery_schedule set status = 'Completed' where id = p_schedule_id;
  end if;
  perform public.log_audit_event('Fertility Procedure Report ' || p_status, p_schedule_id::text);
  return saved;
end;
$$;

revoke all on function public.save_fertility_procedure_report(uuid,jsonb,text) from public, anon;
grant execute on function public.save_fertility_procedure_report(uuid,jsonb,text) to authenticated;

create or replace function public.save_cryo_specimen(
  p_patient_id text,
  p_asset_type text,
  p_units int,
  p_per_unit int,
  p_freezing_date date,
  p_tank_id uuid,
  p_canister text,
  p_rack text,
  p_cane text,
  p_goblet text,
  p_position text,
  p_container_label text,
  p_storage_unit_type text,
  p_freeze_method text,
  p_specimen_quality text,
  p_source_procedure_id uuid,
  p_witnessed_by uuid,
  p_notes text,
  p_record_id uuid default null
)
returns public.cryo_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  existing public.cryo_records;
  target_tank public.cryo_tanks;
  saved public.cryo_records;
begin
  if public.current_app_role() not in ('chief_embryologist', 'lab_tech') then
    raise exception 'not authorized to document cryogenic storage' using errcode = '42501';
  end if;
  if p_asset_type not in ('Embryo', 'Oocyte', 'Sperm') then raise exception 'invalid specimen type'; end if;
  if coalesce(p_units, 0) < 1 then raise exception 'the number of storage units must be positive'; end if;
  if p_tank_id is null then raise exception 'storage tank is required'; end if;
  if nullif(btrim(coalesce(p_canister, '')), '') is null
     or nullif(btrim(coalesce(p_cane, '')), '') is null
     or nullif(btrim(coalesce(p_goblet, '')), '') is null
     or nullif(btrim(coalesce(p_position, '')), '') is null
     or nullif(btrim(coalesce(p_container_label, '')), '') is null then
    raise exception 'canister, cane, goblet/jar, position, and container label are required';
  end if;
  if not exists (select 1 from public.patient_names where patient_id = p_patient_id) then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;
  if p_source_procedure_id is not null and not exists (
    select 1 from public.surgery_schedule s
    where s.id = p_source_procedure_id and s.patient_id = p_patient_id
      and public.is_fertility_lab_procedure(s.procedure)
  ) then raise exception 'the selected procedure does not belong to this patient'; end if;

  if p_record_id is not null then
    select * into existing from public.cryo_records where id = p_record_id for update;
    if not found then raise exception 'cryo record not found' using errcode = 'P0002'; end if;
    if existing.status <> 'Stored' then raise exception 'only stored specimens can be edited'; end if;
    if existing.tank_id is not null then
      update public.cryo_tanks set used = greatest(0, used - existing.straws) where id = existing.tank_id;
    end if;
  end if;

  select * into target_tank from public.cryo_tanks where id = p_tank_id for update;
  if not found then raise exception 'storage tank not found' using errcode = 'P0002'; end if;
  if target_tank.used + p_units > target_tank.capacity then raise exception 'storage tank does not have enough capacity'; end if;

  if p_record_id is null then
    insert into public.cryo_records(
      patient_id, asset_type, straws, per_straw, freezing_date, tank_id,
      canister, rack, cane, goblet, position, container_label,
      storage_unit_type, freeze_method, specimen_quality, source_procedure_id,
      witnessed_by, notes, logged_by, status
    ) values (
      p_patient_id, p_asset_type, p_units, nullif(p_per_unit, 0), coalesce(p_freezing_date, current_date), p_tank_id,
      btrim(p_canister), nullif(btrim(coalesce(p_rack, '')), ''), btrim(p_cane), btrim(p_goblet), btrim(p_position), btrim(p_container_label),
      coalesce(nullif(btrim(p_storage_unit_type), ''), 'Straw'), nullif(btrim(coalesce(p_freeze_method, '')), ''),
      nullif(btrim(coalesce(p_specimen_quality, '')), ''), p_source_procedure_id,
      p_witnessed_by, nullif(btrim(coalesce(p_notes, '')), ''), auth.uid(), 'Stored'
    ) returning * into saved;
  else
    update public.cryo_records set
      patient_id = p_patient_id, asset_type = p_asset_type, straws = p_units,
      per_straw = nullif(p_per_unit, 0), freezing_date = coalesce(p_freezing_date, current_date),
      tank_id = p_tank_id, canister = btrim(p_canister), rack = nullif(btrim(coalesce(p_rack, '')), ''),
      cane = btrim(p_cane), goblet = btrim(p_goblet), position = btrim(p_position),
      container_label = btrim(p_container_label), storage_unit_type = coalesce(nullif(btrim(p_storage_unit_type), ''), 'Straw'),
      freeze_method = nullif(btrim(coalesce(p_freeze_method, '')), ''), specimen_quality = nullif(btrim(coalesce(p_specimen_quality, '')), ''),
      source_procedure_id = p_source_procedure_id, witnessed_by = p_witnessed_by,
      notes = nullif(btrim(coalesce(p_notes, '')), ''), logged_by = auth.uid()
    where id = p_record_id returning * into saved;
  end if;

  update public.cryo_tanks set used = used + p_units where id = p_tank_id;
  perform public.log_audit_event(
    case when p_record_id is null then 'Cryo Specimen Stored' else 'Cryo Storage Record Updated' end,
    saved.id::text || ' · ' || p_patient_id || ' · ' || p_asset_type
  );
  return saved;
end;
$$;

revoke all on function public.save_cryo_specimen(text,text,int,int,date,uuid,text,text,text,text,text,text,text,text,text,uuid,uuid,text,uuid) from public, anon;
grant execute on function public.save_cryo_specimen(text,text,int,int,date,uuid,text,text,text,text,text,text,text,text,text,uuid,uuid,text,uuid) to authenticated;

-- Laboratory staff work together in the cryostore. Retain all existing
-- quantity and audit protections while allowing either lab role to record use.
create or replace function public.use_cryo_record(p_record_id uuid, p_straws_used int default 1)
returns public.cryo_records
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare r public.cryo_records; remaining int;
begin
  if public.current_app_role() not in ('chief_embryologist', 'lab_tech') then raise exception 'not authorized'; end if;
  select * into r from public.cryo_records where id = p_record_id for update;
  if not found then raise exception 'cryo record not found'; end if;
  if r.status <> 'Stored' then raise exception 'cryo record is no longer in storage'; end if;
  if p_straws_used <= 0 or p_straws_used > r.straws then raise exception 'invalid storage-unit quantity'; end if;
  remaining := r.straws - p_straws_used;
  update public.cryo_records set
    straws = greatest(remaining, 0),
    status = case when remaining = 0 then 'Used' else 'Stored' end,
    used_date = case when remaining = 0 then current_date else null end,
    used_by = case when remaining = 0 then auth.uid() else null end
  where id = p_record_id returning * into r;
  if r.tank_id is not null then
    update public.cryo_tanks set used = greatest(0, used - p_straws_used) where id = r.tank_id;
  end if;
  if to_regclass('public.cryo_movements') is not null then
    insert into public.cryo_movements(cryo_record_id, quantity_delta, reason, actor_id)
    values(p_record_id, -p_straws_used, 'Removed from cryogenic storage', auth.uid());
  end if;
  perform public.log_audit_event('Cryo Specimen Removed', p_record_id::text || ' · units ' || p_straws_used);
  return r;
end;
$$;

revoke all on function public.use_cryo_record(uuid,int) from public, anon;
grant execute on function public.use_cryo_record(uuid,int) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'fertility_classifier_present', to_regprocedure('public.is_fertility_lab_procedure(text)') is not null,
  'procedure_reports_present', to_regclass('public.fertility_procedure_reports') is not null,
  'procedure_report_rpc_present', to_regprocedure('public.save_fertility_procedure_report(uuid,jsonb,text)') is not null,
  'cryo_location_columns_present', (
    select count(*) = 8 from information_schema.columns
    where table_schema = 'public' and table_name = 'cryo_records'
      and column_name in ('storage_unit_type','rack','cane','goblet','container_label','freeze_method','specimen_quality','source_procedure_id')
  ),
  'cryo_save_rpc_present', to_regprocedure('public.save_cryo_specimen(text,text,int,int,date,uuid,text,text,text,text,text,text,text,text,text,uuid,uuid,text,uuid)') is not null,
  'both_lab_roles_can_document_cryo', position(
    $$'chief_embryologist', 'lab_tech'$$
    in pg_get_functiondef('public.save_cryo_specimen(text,text,int,int,date,uuid,text,text,text,text,text,text,text,text,text,uuid,uuid,text,uuid)'::regprocedure)
  ) > 0
)) as embryology_workspace_verification;
