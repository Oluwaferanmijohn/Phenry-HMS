-- Lab-result sparsity and role-specific patient-directory alignment.
-- Safe to run more than once. No completed result value is removed.

begin;
set local lock_timeout = '5s';

-- Earlier UI versions saved every unfilled template field as an em dash.
-- Remove only blank placeholders; preserve every actual entered value in order.
update public.lab_results lr
set values = coalesce((
  select jsonb_agg(row_value order by position)
  from jsonb_array_elements(lr.values) with ordinality as rows(row_value, position)
  where nullif(btrim(coalesce(row_value ->> 'value', '')), '') is not null
    and btrim(row_value ->> 'value') <> '—'
), '[]'::jsonb)
where jsonb_typeof(lr.values) = 'array'
  and exists (
    select 1
    from jsonb_array_elements(lr.values) as row_value
    where nullif(btrim(coalesce(row_value ->> 'value', '')), '') is null
       or btrim(row_value ->> 'value') = '—'
  );

-- Keep the nurse patient list consistent with nurse_has_patient_access().
-- This includes a nurse explicitly assigned as cycle manager even before a
-- general doctor assignment exists.
create or replace function public.clinical_patient_directory()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_role text := public.current_app_role();
begin
  if auth.uid() is null
     or caller_role not in ('admin_manager', 'doctor', 'matron', 'nurse', 'chief_embryologist') then
    raise exception 'not authorized to read the clinical patient directory'
      using errcode = '42501';
  end if;

  return (
    with allowed_patients as materialized (
      select bd.*, pn.full_name
      from public.bio_details bd
      join public.patient_names pn on pn.patient_id = bd.patient_id
      where
        caller_role in ('admin_manager', 'matron', 'chief_embryologist')
        or (
          caller_role = 'doctor'
          and (
            bd.assigned_doctor_id = auth.uid()
            or exists (
              select 1
              from public.appointments a
              where a.patient_id = bd.patient_id
                and a.provider_profile_id = auth.uid()
                and a.provider_role = 'doctor'
                and a.date = current_date
                and a.status <> 'Cancelled'
            )
          )
        )
        or (
          caller_role = 'nurse'
          and public.nurse_has_patient_access(bd.patient_id)
        )
    ),
    patient_rows as (
      select coalesce(
        jsonb_agg(to_jsonb(ap) order by ap.full_name, ap.patient_id),
        '[]'::jsonb
      ) as value
      from allowed_patients ap
    ),
    cycle_rows as (
      select coalesce(
        jsonb_agg(to_jsonb(c) order by c.start_date desc, c.created_at desc),
        '[]'::jsonb
      ) as value
      from public.cycles c
      join allowed_patients ap on ap.patient_id = c.patient_id
      where c.status <> 'Closed'
    )
    select jsonb_build_object(
      'patients', patient_rows.value,
      'activeCycles', cycle_rows.value
    )
    from patient_rows cross join cycle_rows
  );
end;
$$;

revoke all on function public.clinical_patient_directory() from public, anon;
grant execute on function public.clinical_patient_directory() to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'placeholder_result_rows_remaining', (
    select count(*)
    from public.lab_results lr,
         lateral jsonb_array_elements(lr.values) as row_value
    where nullif(btrim(coalesce(row_value ->> 'value', '')), '') is null
       or btrim(row_value ->> 'value') = '—'
  ),
  'nurse_directory_uses_access_function', position(
    'nurse_has_patient_access' in pg_get_functiondef('public.clinical_patient_directory()'::regprocedure)
  ) > 0
)) as role_view_verification;
