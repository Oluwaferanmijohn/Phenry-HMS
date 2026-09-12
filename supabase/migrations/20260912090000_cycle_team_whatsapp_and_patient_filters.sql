-- Multi-nurse cycle access, consented WhatsApp reminders, and consistent patient filters.
-- Safe to run in the Supabase SQL editor after the 20260907 migrations.
begin;

alter table public.bio_details add column if not exists whatsapp_phone text;
alter table public.bio_details add column if not exists whatsapp_opt_in boolean not null default false;
comment on column public.bio_details.whatsapp_opt_in is 'Explicit consent to receive operational care reminders through WhatsApp.';

create table if not exists public.cycle_nurse_assignments (
  cycle_id uuid not null references public.cycles(id) on delete cascade,
  nurse_profile_id uuid not null references public.profiles(id) on delete cascade,
  is_primary boolean not null default false,
  assigned_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(cycle_id,nurse_profile_id)
);
create unique index if not exists cycle_one_primary_nurse_idx on public.cycle_nurse_assignments(cycle_id) where is_primary;
alter table public.cycle_nurse_assignments enable row level security;
drop policy if exists "cycle team access" on public.cycle_nurse_assignments;
drop policy if exists "cycle staff read assigned nursing team" on public.cycle_nurse_assignments;
create policy "cycle staff read assigned nursing team" on public.cycle_nurse_assignments for select to authenticated using(
  public.current_app_role() in ('doctor','matron') or (
    public.current_app_role()='nurse' and exists(select 1 from public.cycles c where c.id=cycle_id and public.nurse_has_patient_access(c.patient_id))
  )
);

create or replace function public.nurse_has_patient_access(p_patient_id text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.bio_details bd where bd.patient_id=p_patient_id and bd.assigned_doctor_id is not null)
    or exists(select 1 from public.cycles c where c.patient_id=p_patient_id and c.cycle_manager_id=auth.uid())
    or exists(select 1 from public.cycles c join public.cycle_nurse_assignments cna on cna.cycle_id=c.id where c.patient_id=p_patient_id and cna.nurse_profile_id=auth.uid());
$$;

create or replace function public.set_cycle_nursing_team(p_cycle_id uuid,p_nurse_ids uuid[])
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare caller_role text:=public.current_app_role(); target_patient text; primary_nurse uuid;
begin
  if auth.uid() is null or caller_role not in ('doctor','matron','nurse') then raise exception 'not authorized' using errcode='42501'; end if;
  select patient_id into target_patient from public.cycles where id=p_cycle_id for update;
  if not found then raise exception 'cycle not found'; end if;
  if caller_role='doctor' and not public.doctor_has_patient_access(target_patient) then raise exception 'patient is not assigned to this doctor' using errcode='42501'; end if;
  if caller_role='nurse' and not public.nurse_has_patient_access(target_patient) then raise exception 'patient is not assigned to this nurse' using errcode='42501'; end if;
  if coalesce(array_length(p_nurse_ids,1),0)=0 then raise exception 'select at least one nurse'; end if;
  if exists(select 1 from unnest(p_nurse_ids) selected(id) where not exists(select 1 from public.profiles p where p.id=selected.id and p.role='nurse' and p.active)) then raise exception 'all selected people must be active nurses'; end if;
  delete from public.cycle_nurse_assignments where cycle_id=p_cycle_id;
  insert into public.cycle_nurse_assignments(cycle_id,nurse_profile_id,is_primary,assigned_by)
    select p_cycle_id,id,ordinality=1,auth.uid() from unnest(p_nurse_ids) with ordinality selected(id,ordinality) on conflict do nothing;
  primary_nurse:=p_nurse_ids[1];
  update public.cycles set cycle_manager_id=primary_nurse where id=p_cycle_id;
  perform public.log_audit_event('Cycle Nursing Team Updated',p_cycle_id::text||' · '||array_length(p_nurse_ids,1)||' nurse(s)');
end; $$;
revoke all on function public.set_cycle_nursing_team(uuid,uuid[]) from public,anon;
grant execute on function public.set_cycle_nursing_team(uuid,uuid[]) to authenticated;

alter table public.messages_log add column if not exists scheduled_for date;
alter table public.messages_log add column if not exists recipient_phone text;
alter table public.messages_log add column if not exists source_type text;
alter table public.messages_log add column if not exists source_id uuid;
alter table public.messages_log add column if not exists attempts int not null default 0;
alter table public.messages_log add column if not exists last_attempt_at timestamptz;
alter table public.messages_log add column if not exists last_error text;
alter table public.messages_log add column if not exists provider_message_id text;
alter table public.messages_log drop constraint if exists messages_log_trigger_type_check;
alter table public.messages_log add constraint messages_log_trigger_type_check check(trigger_type in ('new_appointment','rescheduled','cycle_reminder'));
alter table public.messages_log drop constraint if exists messages_log_status_check;
alter table public.messages_log add constraint messages_log_status_check check(status in ('queued','sending','sent','failed','cancelled'));
create unique index if not exists messages_log_cycle_source_unique on public.messages_log(source_type,source_id) where source_type is not null and source_id is not null;

create or replace function public.queue_cycle_day_whatsapp()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare patient_row record; instruction text;
begin
  if new.medication_administered or new.action_status in ('Administered','Completed','Cancelled') then
    update public.messages_log set status='cancelled' where source_type='cycle_daily_log' and source_id=new.id and status in ('queued','failed');
    return new;
  end if;
  instruction:=concat_ws(' · ',nullif(btrim(coalesce(new.medication,'')),''),nullif(btrim(coalesce(new.milestone,'')),''));
  if instruction='' then return new; end if;
  select c.patient_id,pn.full_name,coalesce(nullif(btrim(bd.whatsapp_phone),''),nullif(btrim(bd.phone),'')) phone,bd.whatsapp_opt_in
    into patient_row from public.cycles c join public.patient_names pn on pn.patient_id=c.patient_id join public.bio_details bd on bd.patient_id=c.patient_id where c.id=new.cycle_id;
  if not coalesce(patient_row.whatsapp_opt_in,false) or patient_row.phone is null then return new; end if;
  insert into public.messages_log(patient_id,trigger_type,body,status,scheduled_for,recipient_phone,source_type,source_id)
  values(patient_row.patient_id,'cycle_reminder',format('Hello %s. Your fertility care plan for %s: %s. Follow the latest instruction from your clinical team. — Phenry Health',patient_row.full_name,to_char(new.date,'DD Mon YYYY'),instruction),'queued',new.date,patient_row.phone,'cycle_daily_log',new.id)
  on conflict(source_type,source_id) where source_type is not null and source_id is not null do update set body=excluded.body,scheduled_for=excluded.scheduled_for,recipient_phone=excluded.recipient_phone,status=case when public.messages_log.status='sent' then 'sent' else 'queued' end,last_error=null;
  return new;
end; $$;
drop trigger if exists cycle_daily_logs_queue_whatsapp on public.cycle_daily_logs;
create trigger cycle_daily_logs_queue_whatsapp after insert or update of date,medication,milestone,medication_administered,action_status on public.cycle_daily_logs for each row execute function public.queue_cycle_day_whatsapp();

create or replace function public.sync_patient_cycle_whatsapp_queue()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if not new.whatsapp_opt_in then
    update public.messages_log set status='cancelled' where patient_id=new.patient_id and trigger_type='cycle_reminder' and status in ('queued','failed');
    return new;
  end if;
  update public.messages_log set recipient_phone=coalesce(nullif(btrim(new.whatsapp_phone),''),nullif(btrim(new.phone),''))
    where patient_id=new.patient_id and trigger_type='cycle_reminder' and status in ('queued','failed');
  insert into public.messages_log(patient_id,trigger_type,body,status,scheduled_for,recipient_phone,source_type,source_id)
  select c.patient_id,'cycle_reminder',format('Hello %s. Your fertility care plan for %s: %s. Follow the latest instruction from your clinical team. — Phenry Health',pn.full_name,to_char(l.date,'DD Mon YYYY'),concat_ws(' · ',nullif(btrim(coalesce(l.medication,'')),''),nullif(btrim(coalesce(l.milestone,'')),''))),'queued',l.date,coalesce(nullif(btrim(new.whatsapp_phone),''),nullif(btrim(new.phone),'')),'cycle_daily_log',l.id
  from public.cycle_daily_logs l join public.cycles c on c.id=l.cycle_id join public.patient_names pn on pn.patient_id=c.patient_id
  where c.patient_id=new.patient_id and l.date>=current_date and coalesce(nullif(btrim(new.whatsapp_phone),''),nullif(btrim(new.phone),'')) is not null and not l.medication_administered and concat_ws('',l.medication,l.milestone)<>''
  on conflict(source_type,source_id) where source_type is not null and source_id is not null do update set recipient_phone=excluded.recipient_phone,body=excluded.body,scheduled_for=excluded.scheduled_for,status=case when public.messages_log.status='sent' then 'sent' else 'queued' end,last_error=null;
  return new;
end; $$;
drop trigger if exists bio_details_sync_cycle_whatsapp on public.bio_details;
create trigger bio_details_sync_cycle_whatsapp after update of whatsapp_phone,whatsapp_opt_in,phone on public.bio_details for each row execute function public.sync_patient_cycle_whatsapp_queue();

-- Queue existing future/today instructions for patients who have opted in.
insert into public.messages_log(patient_id,trigger_type,body,status,scheduled_for,recipient_phone,source_type,source_id)
select c.patient_id,'cycle_reminder',format('Hello %s. Your fertility care plan for %s: %s. Follow the latest instruction from your clinical team. — Phenry Health',pn.full_name,to_char(l.date,'DD Mon YYYY'),concat_ws(' · ',nullif(btrim(coalesce(l.medication,'')),''),nullif(btrim(coalesce(l.milestone,'')),''))),'queued',l.date,coalesce(nullif(btrim(bd.whatsapp_phone),''),nullif(btrim(bd.phone),'')),'cycle_daily_log',l.id
from public.cycle_daily_logs l join public.cycles c on c.id=l.cycle_id join public.patient_names pn on pn.patient_id=c.patient_id join public.bio_details bd on bd.patient_id=c.patient_id
where l.date>=current_date and bd.whatsapp_opt_in and coalesce(nullif(btrim(bd.whatsapp_phone),''),nullif(btrim(bd.phone),'')) is not null and not l.medication_administered and concat_ws('',l.medication,l.milestone)<>''
on conflict(source_type,source_id) where source_type is not null and source_id is not null do nothing;

create or replace function public.clinical_patient_search_v2(p_query text default '',p_period text default 'all',p_custom_date date default null,p_patient_type text default 'all',p_limit int default 50)
returns table(patient_id text,full_name text,dob date,sex text,phone text,registered_on date,status text,referral_source text,event_date date,patient_type text)
language sql stable security definer set search_path=public,pg_temp as $$
with directory as (
 select pn.patient_id,pn.full_name,bd.dob,bd.sex,bd.phone,bd.registered_on,bd.status,bd.referral_source,
   coalesce(ap.date,wi.arrived_at::date,bd.registered_on) event_date,
   case when wi.patient_id is not null or lower(coalesce(bd.referral_source,'')) like '%walk-in%' then 'walk_in' when ap.date is not null then 'appointment' else 'registered' end patient_type
 from public.patient_names pn join public.bio_details bd on bd.patient_id=pn.patient_id
 left join lateral(select a.date from public.appointments a where a.patient_id=pn.patient_id order by a.date desc,a.time desc limit 1) ap on true
 left join lateral(select w.patient_id,w.arrived_at from public.walk_in_encounters w where w.patient_id=pn.patient_id order by w.arrived_at desc limit 1) wi on true
 where public.current_app_role() in ('receptionist','admin_manager','doctor','visiting_doctor','matron','nurse','chief_embryologist','lab_tech')
 and (public.current_app_role() not in ('doctor','visiting_doctor') or bd.assigned_doctor_id=auth.uid() or exists(select 1 from public.appointments x where x.patient_id=pn.patient_id and x.provider_profile_id=auth.uid()))
) select * from directory d where (coalesce(p_query,'')='' or (d.full_name||' '||d.patient_id||' '||coalesce(d.phone,'')) ilike '%'||p_query||'%')
 and (p_patient_type='all' or d.patient_type=p_patient_type)
 and (p_period='all' or (p_period='today' and d.event_date=current_date) or (p_period='yesterday' and d.event_date=current_date-1) or (p_period='last_week' and d.event_date between current_date-7 and current_date) or (p_period='date' and d.event_date=p_custom_date))
 order by d.event_date desc,d.full_name limit greatest(1,least(coalesce(p_limit,50),100)); $$;
revoke all on function public.clinical_patient_search_v2(text,text,date,text,int) from public,anon;
grant execute on function public.clinical_patient_search_v2(text,text,date,text,int) to authenticated;

create or replace function public.global_patient_search_v2(p_search text default '',p_period text default 'all',p_custom_date date default null,p_patient_type text default 'all')
returns table(patient_id text,full_name text,event_date date,patient_type text) language sql stable security definer set search_path=public,pg_temp as $$
 select s.patient_id,s.full_name,s.event_date,s.patient_type from public.clinical_patient_search_v2(p_search,p_period,p_custom_date,p_patient_type,12) s;
$$;
revoke all on function public.global_patient_search_v2(text,text,date,text) from public,anon;
grant execute on function public.global_patient_search_v2(text,text,date,text) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
 'cycle_team_rpc',to_regprocedure('public.set_cycle_nursing_team(uuid,uuid[])') is not null,
 'whatsapp_queue_trigger',exists(select 1 from pg_trigger where tgname='cycle_daily_logs_queue_whatsapp'),
 'filtered_patient_search',to_regprocedure('public.clinical_patient_search_v2(text,text,date,text,integer)') is not null
)) as workflow_verification;
