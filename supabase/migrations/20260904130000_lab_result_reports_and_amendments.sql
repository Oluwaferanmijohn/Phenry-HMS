-- Printable laboratory reports and audit-safe result amendments.
-- Safe to run more than once. Existing results are preserved unchanged.

begin;
set local lock_timeout = '5s';

alter table public.lab_results
  add column if not exists updated_at timestamptz;
alter table public.lab_results
  add column if not exists amended_at timestamptz;
alter table public.lab_results
  add column if not exists amended_by_profile_id uuid references public.profiles(id) on delete set null;
alter table public.lab_results
  add column if not exists amendment_reason text;

update public.lab_results
set updated_at = coalesce(updated_at, created_at, now())
where updated_at is null;

alter table public.lab_results
  alter column updated_at set default now(),
  alter column updated_at set not null;

drop trigger if exists lab_results_set_updated_at on public.lab_results;
create trigger lab_results_set_updated_at
before update on public.lab_results
for each row execute function public.set_updated_at();

create index if not exists lab_results_amended_by_profile_id_idx
  on public.lab_results(amended_by_profile_id);

-- One restricted function supplies the exact same printable context to lab
-- staff and to the patient who owns the result. It intentionally exposes only
-- the staff display names required on the report, never the staff directory.
create or replace function public.lab_result_report_context(p_result_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_role text := public.current_app_role();
  result_patient_id text;
  report_context jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select lr.patient_id
  into result_patient_id
  from public.lab_results lr
  where lr.id = p_result_id;

  if result_patient_id is null then
    raise exception 'laboratory result not found' using errcode = 'P0002';
  end if;

  if caller_role not in ('lab_tech', 'chief_embryologist', 'admin_manager')
     and not (caller_role = 'patient' and result_patient_id = public.current_patient_id()) then
    raise exception 'not authorized to view this laboratory report' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'clinic', jsonb_build_object(
      'clinic_name', cs.clinic_name,
      'company_name', cs.company_name,
      'company_address', cs.company_address,
      'company_phone', cs.company_phone,
      'logo_url', cs.logo_url
    ),
    'patient', jsonb_build_object(
      'patient_id', pn.patient_id,
      'full_name', pn.full_name,
      'dob', bd.dob,
      'sex', bd.sex
    ),
    'result', to_jsonb(lr) || jsonb_build_object(
      'template_name', lt.name,
      'entered_by_name', entered_by.full_name,
      'amended_by_name', amended_by.full_name
    )
  )
  into report_context
  from public.lab_results lr
  join public.patient_names pn on pn.patient_id = lr.patient_id
  left join public.bio_details bd on bd.patient_id = lr.patient_id
  left join public.lab_templates lt on lt.id = lr.template_id
  left join public.profiles entered_by on entered_by.id = lr.entered_by_profile_id
  left join public.profiles amended_by on amended_by.id = lr.amended_by_profile_id
  cross join public.clinic_settings cs
  where lr.id = p_result_id
    and cs.id = 1;

  return report_context;
end;
$$;

revoke all on function public.lab_result_report_context(uuid) from public, anon;
grant execute on function public.lab_result_report_context(uuid) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'lab_result_audit_columns_present', (
    select count(*) = 4
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'lab_results'
      and column_name in ('updated_at', 'amended_at', 'amended_by_profile_id', 'amendment_reason')
  ),
  'report_context_function_present', to_regprocedure('public.lab_result_report_context(uuid)') is not null,
  'all_results_have_updated_at', not exists (
    select 1 from public.lab_results where updated_at is null
  )
)) as lab_report_verification;
