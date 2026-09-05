-- One stable, role-aware source for the global dashboard patient search.
begin;

create or replace function public.global_patient_search(p_search text default '')
returns table(patient_id text, full_name text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_role text := public.current_app_role();
  term text := left(btrim(coalesce(p_search, '')), 80);
begin
  if auth.uid() is null then raise exception 'authentication required' using errcode = '42501'; end if;
  if caller_role not in ('receptionist','admin_manager','doctor','matron','nurse','chief_embryologist','lab_tech') then
    raise exception 'global patient search is not available for this role' using errcode = '42501';
  end if;
  if length(term) < 2 then return; end if;

  return query
  select pn.patient_id, pn.full_name
  from public.patient_names pn
  where (pn.full_name || ' ' || pn.patient_id) ilike '%' || term || '%'
    and (
      caller_role in ('receptionist','admin_manager','matron','chief_embryologist','lab_tech')
      or (caller_role = 'doctor' and public.doctor_has_patient_access(pn.patient_id))
      or (caller_role = 'nurse' and public.nurse_has_patient_access(pn.patient_id))
    )
  order by
    case when lower(pn.patient_id) = lower(term) then 0 when lower(pn.full_name) like lower(term) || '%' then 1 else 2 end,
    pn.full_name
  limit 12;
end;
$$;

revoke all on function public.global_patient_search(text) from public, anon;
grant execute on function public.global_patient_search(text) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'global_patient_search_present', to_regprocedure('public.global_patient_search(text)') is not null,
  'doctor_search_is_scoped', position('doctor_has_patient_access' in pg_get_functiondef('public.global_patient_search(text)'::regprocedure)) > 0,
  'nurse_search_is_scoped', position('nurse_has_patient_access' in pg_get_functiondef('public.global_patient_search(text)'::regprocedure)) > 0
)) as global_search_verification;
