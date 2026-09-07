-- Repair for deployments where a filtered finder overload made the older
-- zero-argument dashboard directory RPC ambiguous to PostgREST.
begin;
drop function if exists public.clinical_patient_directory(text,text,date,text,int);
create or replace function public.clinical_patient_search(p_query text default '',p_mode text default 'all',p_date date default null,p_status text default null,p_limit int default 50)
returns table(patient_id text,full_name text,phone text,registered_on date,status text,appointment_date date,is_walk_in boolean) language sql stable security definer set search_path=public,pg_temp as $$
 select pn.patient_id,pn.full_name,bd.phone,bd.registered_on,bd.status,ap.date,exists(select 1 from public.walk_in_encounters wi where wi.patient_id=pn.patient_id)
 from public.patient_names pn join public.bio_details bd on bd.patient_id=pn.patient_id
 left join lateral(select a.date from public.appointments a where a.patient_id=pn.patient_id order by a.date desc,a.time desc limit 1) ap on true
 where public.current_app_role() in ('receptionist','admin_manager','doctor','visiting_doctor','matron','nurse','lab_tech','chief_embryologist')
 and (coalesce(p_query,'')='' or (p_mode in ('all','name') and pn.full_name ilike '%'||p_query||'%') or (p_mode in ('all','mrn') and pn.patient_id ilike '%'||p_query||'%') or (p_mode in ('all','phone') and coalesce(bd.phone,'') ilike '%'||p_query||'%'))
 and (p_status is null or p_status='' or bd.status=p_status) and (p_date is null or bd.registered_on=p_date or exists(select 1 from public.appointments a where a.patient_id=pn.patient_id and a.date=p_date))
 and (public.current_app_role() not in ('doctor','visiting_doctor') or bd.assigned_doctor_id=auth.uid() or exists(select 1 from public.appointments a where a.patient_id=pn.patient_id and a.provider_profile_id=auth.uid()))
 order by coalesce(ap.date,bd.registered_on) desc,pn.full_name limit greatest(1,least(coalesce(p_limit,50),100));
$$;
revoke all on function public.clinical_patient_search(text,text,date,text,int) from public,anon;
grant execute on function public.clinical_patient_search(text,text,date,text,int) to authenticated;
commit;
