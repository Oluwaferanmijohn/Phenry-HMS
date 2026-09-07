-- Walk-ins, filtered patient directory, FET plans, shared nursing and patient reminders.
-- Run this in the Supabase SQL editor after the earlier 20260905 migrations.
begin;

alter table public.profiles drop constraint if exists profiles_role_fixed_chk;
alter table public.profiles add constraint profiles_role_fixed_chk check (role is null or role in ('patient','receptionist','admin_manager','doctor','visiting_doctor','matron','nurse','chief_embryologist','lab_tech','pharmacy','stakeholder'));
alter table public.consultations add column if not exists assigned_provider_profile_id uuid references public.profiles(id);
alter table public.consultations add column if not exists assigned_nurse_profile_id uuid references public.profiles(id);
alter table public.consultations add column if not exists status text not null default 'Completed';
alter table public.consultations drop constraint if exists consultations_provider_role_check;
alter table public.consultations add constraint consultations_provider_role_check check (provider_role in ('doctor','visiting_doctor','matron'));
alter table public.appointments drop constraint if exists appointments_provider_role_check;
alter table public.appointments add constraint appointments_provider_role_check check (provider_role in ('doctor','visiting_doctor','matron'));
create index if not exists consultations_date_status_idx on public.consultations(date,status);

-- External clinicians can only see a patient where an appointment, consultation
-- or operation has explicitly been assigned to their own account.
create policy "visiting doctor reads assigned patient names" on public.patient_names for select to authenticated using (public.current_app_role()='visiting_doctor' and exists(select 1 from public.appointments a where a.patient_id=patient_names.patient_id and a.provider_profile_id=auth.uid()));
create policy "visiting doctor reads assigned patient bio" on public.bio_details for select to authenticated using (public.current_app_role()='visiting_doctor' and exists(select 1 from public.appointments a where a.patient_id=bio_details.patient_id and a.provider_profile_id=auth.uid()));
create policy "visiting doctor reads assigned appointments" on public.appointments for select to authenticated using (public.current_app_role()='visiting_doctor' and provider_profile_id=auth.uid());
create policy "visiting doctor reads assigned consultations" on public.consultations for select to authenticated using (public.current_app_role()='visiting_doctor' and (provider_profile_id=auth.uid() or assigned_provider_profile_id=auth.uid() or exists(select 1 from public.appointments a where a.patient_id=consultations.patient_id and a.provider_profile_id=auth.uid())));
create policy "visiting doctor writes own consultations" on public.consultations for insert to authenticated with check (public.current_app_role()='visiting_doctor' and provider_profile_id=auth.uid() and provider_role='visiting_doctor' and exists(select 1 from public.appointments a where a.patient_id=consultations.patient_id and a.provider_profile_id=auth.uid()));
alter table public.prescriptions drop constraint if exists prescriptions_prescribed_by_role_check;
alter table public.prescriptions add constraint prescriptions_prescribed_by_role_check check (prescribed_by_role in ('doctor','visiting_doctor','nurse','matron'));
create policy "visiting doctor manages own assigned prescriptions" on public.prescriptions for all to authenticated using (public.current_app_role()='visiting_doctor' and prescribed_by_profile_id=auth.uid() and exists(select 1 from public.appointments a where a.patient_id=prescriptions.patient_id and a.provider_profile_id=auth.uid())) with check (public.current_app_role()='visiting_doctor' and prescribed_by_role='visiting_doctor' and prescribed_by_profile_id=auth.uid() and exists(select 1 from public.appointments a where a.patient_id=prescriptions.patient_id and a.provider_profile_id=auth.uid()));
create policy "visiting doctor reads assigned procedures" on public.surgery_schedule for select to authenticated using(public.current_app_role()='visiting_doctor' and assigned_provider_id=auth.uid());
create policy "visiting doctor writes reports for assigned procedures" on public.operative_reports for all to authenticated using(public.current_app_role()='visiting_doctor' and exists(select 1 from public.surgery_schedule s where s.id=operative_reports.surgery_id and s.assigned_provider_id=auth.uid())) with check(public.current_app_role()='visiting_doctor' and exists(select 1 from public.surgery_schedule s where s.id=operative_reports.surgery_id and s.assigned_provider_id=auth.uid()));

alter table public.cycles add column if not exists planned_end_date date;
alter table public.cycles add column if not exists completed_on date;
create table if not exists public.cycle_nurse_assignments (
 cycle_id uuid not null references public.cycles(id) on delete cascade, nurse_profile_id uuid not null references public.profiles(id) on delete cascade,
 is_primary boolean not null default false, assigned_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now(), primary key(cycle_id,nurse_profile_id));
create unique index if not exists cycle_one_primary_nurse_idx on public.cycle_nurse_assignments(cycle_id) where is_primary;
insert into public.cycle_nurse_assignments(cycle_id,nurse_profile_id,is_primary) select id,cycle_manager_id,true from public.cycles where cycle_manager_id is not null on conflict do nothing;
alter table public.cycle_nurse_assignments enable row level security;
drop policy if exists "cycle team access" on public.cycle_nurse_assignments;
create policy "cycle team access" on public.cycle_nurse_assignments for all to authenticated using (public.current_app_role() in ('doctor','matron') or nurse_profile_id=auth.uid()) with check (public.current_app_role() in ('doctor','matron') or nurse_profile_id=auth.uid());

create table if not exists public.walk_in_encounters (
 id uuid primary key default gen_random_uuid(), patient_id text not null references public.patient_names(patient_id) on delete cascade,
 registered_by uuid references public.profiles(id) on delete set null, assigned_provider_profile_id uuid references public.profiles(id) on delete set null,
 clinical_reason text, arrived_at timestamptz not null default now(), status text not null default 'Awaiting triage', created_at timestamptz not null default now());
alter table public.walk_in_encounters enable row level security;
drop policy if exists "staff manage walk ins" on public.walk_in_encounters;
create policy "staff manage walk ins" on public.walk_in_encounters for all to authenticated using (public.current_app_role() in ('receptionist','admin_manager','matron','nurse')) with check (public.current_app_role() in ('receptionist','admin_manager','matron','nurse'));

-- Initial clerking is deliberately separate from repeat vital-sign observations.
create table if not exists public.patient_initial_assessments (
 id uuid primary key default gen_random_uuid(), patient_id text not null references public.patient_names(patient_id) on delete cascade,
 assessed_by uuid references public.profiles(id) on delete set null, assessed_on date not null default current_date,
 medical_history jsonb not null default '{}'::jsonb, fertility_history jsonb not null default '{}'::jsonb, notes text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index if not exists patient_initial_assessments_patient_idx on public.patient_initial_assessments(patient_id,assessed_on desc);
alter table public.patient_initial_assessments enable row level security;
drop policy if exists "clinical staff manage initial assessments" on public.patient_initial_assessments;
create policy "clinical staff manage initial assessments" on public.patient_initial_assessments for all to authenticated using(public.current_app_role() in ('doctor','matron','nurse')) with check(public.current_app_role() in ('doctor','matron','nurse'));

-- Inpatient board: restricted visiting doctors can see only admissions assigned to them.
create table if not exists public.inpatient_admissions (
 id uuid primary key default gen_random_uuid(), patient_id text not null references public.patient_names(patient_id) on delete cascade,
 admitted_by uuid references public.profiles(id) on delete set null, attending_provider_id uuid references public.profiles(id) on delete set null,
 reason text not null, ward text, bed_label text, status text not null default 'Admitted' check(status in ('Admitted','Discharged','Transferred')),
 admitted_at timestamptz not null default now(), discharged_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.ward_rounds (
 id uuid primary key default gen_random_uuid(), admission_id uuid not null references public.inpatient_admissions(id) on delete cascade,
 documented_by uuid references public.profiles(id) on delete set null, round_date date not null default current_date,
 subjective text, objective text, assessment text, plan text, created_at timestamptz not null default now());
alter table public.inpatient_admissions enable row level security; alter table public.ward_rounds enable row level security;
drop policy if exists "clinical staff manage admissions" on public.inpatient_admissions;
create policy "clinical staff manage admissions" on public.inpatient_admissions for all to authenticated using(public.current_app_role() in ('doctor','matron','nurse') or (public.current_app_role()='visiting_doctor' and attending_provider_id=auth.uid())) with check(public.current_app_role() in ('doctor','matron','nurse') or (public.current_app_role()='visiting_doctor' and attending_provider_id=auth.uid()));
drop policy if exists "clinical staff manage ward rounds" on public.ward_rounds;
create policy "clinical staff manage ward rounds" on public.ward_rounds for all to authenticated using(public.current_app_role() in ('doctor','matron','nurse') or exists(select 1 from public.inpatient_admissions a where a.id=admission_id and a.attending_provider_id=auth.uid() and public.current_app_role()='visiting_doctor')) with check(public.current_app_role() in ('doctor','matron','nurse') or exists(select 1 from public.inpatient_admissions a where a.id=admission_id and a.attending_provider_id=auth.uid() and public.current_app_role()='visiting_doctor'));

create or replace function public.register_walk_in_patient(p_first_name text,p_surname text,p_dob date,p_sex text,p_phone text default null,p_reason text default null,p_provider_id uuid default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id text; v_name text;
begin
 if auth.uid() is null or public.current_app_role() not in ('receptionist','admin_manager','matron','nurse') then raise exception 'not authorized' using errcode='42501'; end if;
 if nullif(btrim(p_first_name),'') is null or nullif(btrim(p_surname),'') is null or p_dob is null or nullif(btrim(p_sex),'') is null then raise exception 'first name, surname, date of birth and sex are required'; end if;
 if p_provider_id is not null and not exists(select 1 from public.profiles where id=p_provider_id and active and role in ('doctor','visiting_doctor','matron')) then raise exception 'assigned clinician is unavailable'; end if;
 v_id:=public.generate_mrn(btrim(p_surname)); v_name:=initcap(btrim(p_first_name))||' '||initcap(btrim(p_surname));
 insert into public.patient_names(patient_id,first_name,surname,full_name) values(v_id,initcap(btrim(p_first_name)),initcap(btrim(p_surname)),v_name);
 insert into public.bio_details(patient_id,dob,sex,phone,referral_source,status,assigned_doctor_id) values(v_id,p_dob,btrim(p_sex),nullif(btrim(coalesce(p_phone,'')),''),'Walk-in registration','Awaiting triage',case when exists(select 1 from public.profiles where id=p_provider_id and role='doctor') then p_provider_id else null end);
 insert into public.walk_in_encounters(patient_id,registered_by,assigned_provider_profile_id,clinical_reason) values(v_id,auth.uid(),p_provider_id,nullif(btrim(coalesce(p_reason,'')),''));
 return jsonb_build_object('patient_id',v_id,'full_name',v_name,'status','Awaiting triage');
end; $$;
revoke all on function public.register_walk_in_patient(text,text,date,text,text,text,uuid) from public,anon;
grant execute on function public.register_walk_in_patient(text,text,date,text,text,text,uuid) to authenticated;

create or replace function public.clinical_patient_search(p_query text default '',p_mode text default 'all',p_date date default null,p_status text default null,p_limit int default 50)
returns table(patient_id text,full_name text,phone text,registered_on date,status text,appointment_date date,is_walk_in boolean) language sql stable security definer set search_path=public,pg_temp as $$
 select pn.patient_id,pn.full_name,bd.phone,bd.registered_on,bd.status,ap.date,exists(select 1 from public.walk_in_encounters wi where wi.patient_id=pn.patient_id) from public.patient_names pn join public.bio_details bd on bd.patient_id=pn.patient_id left join lateral(select a.date from public.appointments a where a.patient_id=pn.patient_id order by a.date desc,a.time desc limit 1) ap on true where public.current_app_role() in ('receptionist','admin_manager','doctor','visiting_doctor','matron','nurse','lab_tech','chief_embryologist') and (coalesce(p_query,'')='' or (p_mode in ('all','name') and pn.full_name ilike '%'||p_query||'%') or (p_mode in ('all','mrn') and pn.patient_id ilike '%'||p_query||'%') or (p_mode in ('all','phone') and coalesce(bd.phone,'') ilike '%'||p_query||'%')) and (p_status is null or p_status='' or bd.status=p_status) and (p_date is null or bd.registered_on=p_date or exists(select 1 from public.appointments a where a.patient_id=pn.patient_id and a.date=p_date)) and (public.current_app_role() not in ('doctor','visiting_doctor') or bd.assigned_doctor_id=auth.uid() or exists(select 1 from public.appointments a where a.patient_id=pn.patient_id and a.provider_profile_id=auth.uid())) order by coalesce(ap.date,bd.registered_on) desc,pn.full_name limit greatest(1,least(coalesce(p_limit,50),100));
$$;
revoke all on function public.clinical_patient_search(text,text,date,text,int) from public,anon;
grant execute on function public.clinical_patient_search(text,text,date,text,int) to authenticated;

create table if not exists public.patient_reminders (
 id uuid primary key default gen_random_uuid(), patient_id text not null references public.patient_names(patient_id) on delete cascade, cycle_id uuid references public.cycles(id) on delete cascade, reminder_type text not null, title text not null, body text, due_on date not null, status text not null default 'Due' check(status in ('Due','Completed','Dismissed')), visible_to_patient boolean not null default true, created_by uuid references public.profiles(id) on delete set null, created_at timestamptz not null default now());
create index if not exists patient_reminders_patient_due_idx on public.patient_reminders(patient_id,due_on);
alter table public.patient_reminders enable row level security;
drop policy if exists "patient reads own reminders" on public.patient_reminders;
create policy "patient reads own reminders" on public.patient_reminders for select to authenticated using(patient_id=public.current_patient_id() and visible_to_patient);
drop policy if exists "cycle team manage reminders" on public.patient_reminders;
create policy "cycle team manage reminders" on public.patient_reminders for all to authenticated using(public.current_app_role() in ('doctor','matron','nurse')) with check(public.current_app_role() in ('doctor','matron','nurse'));
create or replace function public.create_transfer_reminders() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$ begin if new.transfer_date is not null and (tg_op='INSERT' or new.transfer_date is distinct from old.transfer_date) then insert into public.patient_reminders(patient_id,cycle_id,reminder_type,title,body,due_on,created_by) select new.patient_id,new.id,'pregnancy_test','Pregnancy test due','Please complete your pregnancy test and contact the clinic with the result.',new.transfer_date+14,auth.uid() where not exists(select 1 from public.patient_reminders r where r.cycle_id=new.id and r.reminder_type='pregnancy_test' and r.status='Due'); end if; return new; end; $$;
drop trigger if exists cycles_create_transfer_reminders on public.cycles; create trigger cycles_create_transfer_reminders after insert or update of transfer_date on public.cycles for each row execute function public.create_transfer_reminders();
create or replace function public.patient_storage_summary() returns table(asset_type text,records bigint,total_straws bigint) language sql stable security definer set search_path=public,pg_temp as $$ select asset_type,count(*),coalesce(sum(straws),0) from public.cryo_records where patient_id=public.current_patient_id() group by asset_type order by asset_type; $$;
revoke all on function public.patient_storage_summary() from public,anon; grant execute on function public.patient_storage_summary() to authenticated;
insert into public.cycle_templates(name,description,cycle_type,protocol,days,is_system) values ('FET — Natural Cycle (Clinical Review)','Frozen embryo transfer pathway. Confirm monitoring, trigger and transfer timing for this patient before use.','FET','Natural FET — clinician review','[{"sequence_day":1,"offset_days":0,"phase":"FET Planning","phase_key":"procedure","phase_day":1,"medication":null,"milestone":"Baseline scan and clinician-approved natural FET plan"}]'::jsonb,true),('FET — Medicated Cycle (Clinical Review)','Frozen embryo transfer pathway. Confirm medicine, monitoring and transfer timing for this patient before use.','FET','Medicated FET — clinician review','[{"sequence_day":1,"offset_days":0,"phase":"FET Planning","phase_key":"procedure","phase_day":1,"medication":null,"milestone":"Baseline scan and clinician-approved medicated FET plan"}]'::jsonb,true) on conflict(name) do nothing;
commit;
