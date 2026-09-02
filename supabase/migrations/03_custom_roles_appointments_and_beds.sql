-- Phenry Health migration 18 — part 3 of 5
-- RUN SEQUENTIALLY. Do not execute this file in parallel with another part.
-- If this part fails, correct the reported issue and rerun this same part before continuing.

begin;
-- ---------------------------------------------------------------------------
-- 5. Custom-role enforcement. Aggregate scope never exposes raw rows.
-- ---------------------------------------------------------------------------
create or replace function public.custom_role_scope_ok(
  p_resource text,
  p_patient_id text,
  p_owner_id uuid
)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare s text := public.custom_scope(p_resource);
begin
  if public.current_custom_role_key() is null or s is null or s = 'aggregate' then return false; end if;
  if s = 'all' then return true; end if;
  if s = 'own' then
    return p_owner_id = auth.uid() or (p_patient_id is not null and p_patient_id = public.current_patient_id());
  end if;
  if s = 'assigned' and p_patient_id is not null then
    return exists (select 1 from public.bio_details b where b.patient_id = p_patient_id and b.assigned_doctor_id = auth.uid());
  end if;
  return false;
end;
$$;

create or replace function public.custom_resource_aggregate_count(p_resource text)
returns bigint language plpgsql stable security definer set search_path = public as $$
declare result bigint;
begin
  if p_resource not in ('patient_names','bio_details','cycles','consultations','appointments','payment_plans','payment_milestones','prescriptions','lab_results','clinic_settings')
    or not public.has_custom_permission(p_resource,'view')
    or public.custom_scope(p_resource) <> 'aggregate' then
    raise exception 'aggregate access is not granted for this resource';
  end if;
  execute format('select count(*) from public.%I',p_resource) into result;
  return result;
end;
$$;

drop policy if exists "custom role reads patient_names" on public.patient_names;
create policy "custom role reads patient_names" on public.patient_names for select to authenticated
  using (public.has_custom_permission('patient_names','view') and public.custom_role_scope_ok('patient_names',patient_id,null::uuid));
drop policy if exists "custom role creates patient_names" on public.patient_names;
create policy "custom role creates patient_names" on public.patient_names for insert to authenticated
  with check (public.has_custom_permission('patient_names','create') and public.custom_scope('patient_names') = 'all');
drop policy if exists "custom role edits patient_names" on public.patient_names;
create policy "custom role edits patient_names" on public.patient_names for update to authenticated
  using (public.has_custom_permission('patient_names','edit') and public.custom_role_scope_ok('patient_names',patient_id,null::uuid))
  with check (public.has_custom_permission('patient_names','edit') and public.custom_role_scope_ok('patient_names',patient_id,null::uuid));

drop policy if exists "custom role reads bio_details" on public.bio_details;
create policy "custom role reads bio_details" on public.bio_details for select to authenticated
  using (public.has_custom_permission('bio_details','view') and public.custom_role_scope_ok('bio_details',patient_id,null::uuid));
drop policy if exists "custom role creates bio_details" on public.bio_details;
create policy "custom role creates bio_details" on public.bio_details for insert to authenticated
  with check (public.has_custom_permission('bio_details','create') and public.custom_role_scope_ok('bio_details',patient_id,null::uuid));
drop policy if exists "custom role edits bio_details" on public.bio_details;
create policy "custom role edits bio_details" on public.bio_details for update to authenticated
  using (public.has_custom_permission('bio_details','edit') and public.custom_role_scope_ok('bio_details',patient_id,null::uuid))
  with check (public.has_custom_permission('bio_details','edit') and public.custom_role_scope_ok('bio_details',patient_id,null::uuid));

drop policy if exists "custom role reads cycles" on public.cycles;
create policy "custom role reads cycles" on public.cycles for select to authenticated
  using (public.has_custom_permission('cycles','view') and public.custom_role_scope_ok('cycles',patient_id,null::uuid));
drop policy if exists "custom role creates cycles" on public.cycles;
create policy "custom role creates cycles" on public.cycles for insert to authenticated
  with check (public.has_custom_permission('cycles','create') and public.custom_role_scope_ok('cycles',patient_id,null::uuid));
drop policy if exists "custom role edits cycles" on public.cycles;
create policy "custom role edits cycles" on public.cycles for update to authenticated
  using (public.has_custom_permission('cycles','edit') and public.custom_role_scope_ok('cycles',patient_id,null::uuid))
  with check (public.has_custom_permission('cycles','edit') and public.custom_role_scope_ok('cycles',patient_id,null::uuid));

drop policy if exists "custom role reads consultations" on public.consultations;
create policy "custom role reads consultations" on public.consultations for select to authenticated
  using (public.has_custom_permission('consultations','view') and public.custom_role_scope_ok('consultations',patient_id,provider_profile_id));
drop policy if exists "custom role creates consultations" on public.consultations;
create policy "custom role creates consultations" on public.consultations for insert to authenticated
  with check (public.has_custom_permission('consultations','create') and public.custom_role_scope_ok('consultations',patient_id,provider_profile_id));
drop policy if exists "custom role edits consultations" on public.consultations;
create policy "custom role edits consultations" on public.consultations for update to authenticated
  using (public.has_custom_permission('consultations','edit') and public.custom_role_scope_ok('consultations',patient_id,provider_profile_id))
  with check (public.has_custom_permission('consultations','edit') and public.custom_role_scope_ok('consultations',patient_id,provider_profile_id));

drop policy if exists "custom role reads appointments" on public.appointments;
create policy "custom role reads appointments" on public.appointments for select to authenticated
  using (public.has_custom_permission('appointments','view') and public.custom_role_scope_ok('appointments',patient_id,provider_profile_id));
drop policy if exists "custom role creates appointments" on public.appointments;
create policy "custom role creates appointments" on public.appointments for insert to authenticated
  with check (public.has_custom_permission('appointments','create') and public.custom_role_scope_ok('appointments',patient_id,provider_profile_id));
drop policy if exists "custom role edits appointments" on public.appointments;
create policy "custom role edits appointments" on public.appointments for update to authenticated
  using (public.has_custom_permission('appointments','edit') and public.custom_role_scope_ok('appointments',patient_id,provider_profile_id))
  with check (public.has_custom_permission('appointments','edit') and public.custom_role_scope_ok('appointments',patient_id,provider_profile_id));

drop policy if exists "custom role reads payment_plans" on public.payment_plans;
create policy "custom role reads payment_plans" on public.payment_plans for select to authenticated
  using (public.has_custom_permission('payment_plans','view') and public.custom_role_scope_ok('payment_plans',patient_id,null::uuid));
drop policy if exists "custom role creates payment_plans" on public.payment_plans;
create policy "custom role creates payment_plans" on public.payment_plans for insert to authenticated
  with check (public.has_custom_permission('payment_plans','create') and public.custom_role_scope_ok('payment_plans',patient_id,null::uuid));
drop policy if exists "custom role edits payment_plans" on public.payment_plans;
create policy "custom role edits payment_plans" on public.payment_plans for update to authenticated
  using (public.has_custom_permission('payment_plans','edit') and public.custom_role_scope_ok('payment_plans',patient_id,null::uuid))
  with check (public.has_custom_permission('payment_plans','edit') and public.custom_role_scope_ok('payment_plans',patient_id,null::uuid));

drop policy if exists "custom role reads payment_milestones" on public.payment_milestones;
create policy "custom role reads payment_milestones" on public.payment_milestones for select to authenticated
  using (public.has_custom_permission('payment_milestones','view') and exists (
    select 1 from public.payment_plans p where p.id = plan_id and public.custom_role_scope_ok('payment_milestones',p.patient_id,null::uuid)
  ));
drop policy if exists "custom role creates payment_milestones" on public.payment_milestones;
create policy "custom role creates payment_milestones" on public.payment_milestones for insert to authenticated
  with check (public.has_custom_permission('payment_milestones','create') and exists (
    select 1 from public.payment_plans p where p.id = plan_id and public.custom_role_scope_ok('payment_milestones',p.patient_id,null::uuid)
  ));
drop policy if exists "custom role edits payment_milestones" on public.payment_milestones;
create policy "custom role edits payment_milestones" on public.payment_milestones for update to authenticated
  using (public.has_custom_permission('payment_milestones','edit') and exists (
    select 1 from public.payment_plans p where p.id = plan_id and public.custom_role_scope_ok('payment_milestones',p.patient_id,null::uuid)
  ))
  with check (public.has_custom_permission('payment_milestones','edit') and exists (
    select 1 from public.payment_plans p where p.id = plan_id and public.custom_role_scope_ok('payment_milestones',p.patient_id,null::uuid)
  ));

drop policy if exists "custom role reads prescriptions" on public.prescriptions;
create policy "custom role reads prescriptions" on public.prescriptions for select to authenticated
  using (public.has_custom_permission('prescriptions','view') and public.custom_role_scope_ok('prescriptions',patient_id,prescribed_by_profile_id));
drop policy if exists "custom role creates prescriptions" on public.prescriptions;
create policy "custom role creates prescriptions" on public.prescriptions for insert to authenticated
  with check (public.has_custom_permission('prescriptions','create') and public.custom_role_scope_ok('prescriptions',patient_id,prescribed_by_profile_id));
drop policy if exists "custom role edits prescriptions" on public.prescriptions;
create policy "custom role edits prescriptions" on public.prescriptions for update to authenticated
  using (public.has_custom_permission('prescriptions','edit') and public.custom_role_scope_ok('prescriptions',patient_id,prescribed_by_profile_id))
  with check (public.has_custom_permission('prescriptions','edit') and public.custom_role_scope_ok('prescriptions',patient_id,prescribed_by_profile_id));

drop policy if exists "custom role reads lab_results" on public.lab_results;
create policy "custom role reads lab_results" on public.lab_results for select to authenticated
  using (public.has_custom_permission('lab_results','view') and public.custom_role_scope_ok('lab_results',patient_id,entered_by_profile_id));
drop policy if exists "custom role creates lab_results" on public.lab_results;
create policy "custom role creates lab_results" on public.lab_results for insert to authenticated
  with check (public.has_custom_permission('lab_results','create') and public.custom_role_scope_ok('lab_results',patient_id,entered_by_profile_id));
drop policy if exists "custom role edits lab_results" on public.lab_results;
create policy "custom role edits lab_results" on public.lab_results for update to authenticated
  using (public.has_custom_permission('lab_results','edit') and public.custom_role_scope_ok('lab_results',patient_id,entered_by_profile_id))
  with check (public.has_custom_permission('lab_results','edit') and public.custom_role_scope_ok('lab_results',patient_id,entered_by_profile_id));

drop policy if exists "custom role reads clinic_settings" on public.clinic_settings;
create policy "custom role reads clinic_settings" on public.clinic_settings for select to authenticated
  using (public.has_custom_permission('clinic_settings','view') and public.custom_scope('clinic_settings') = 'all');
drop policy if exists "custom role edits clinic_settings" on public.clinic_settings;
create policy "custom role edits clinic_settings" on public.clinic_settings for update to authenticated
  using (public.has_custom_permission('clinic_settings','edit') and public.custom_scope('clinic_settings') = 'all')
  with check (public.has_custom_permission('clinic_settings','edit') and public.custom_scope('clinic_settings') = 'all');

-- ---------------------------------------------------------------------------
-- 6. Appointment overlap protection includes duration, not just start time.
-- ---------------------------------------------------------------------------
update public.appointments set duration=30 where duration < 5 or duration > 480;
alter table public.appointments drop constraint if exists appointments_duration_check;
alter table public.appointments add constraint appointments_duration_check
  check (duration between 5 and 480) not valid;
alter table public.appointments validate constraint appointments_duration_check;

create or replace function public.prevent_appointment_overlap()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.duration < 5 or new.duration > 480 then raise exception 'appointment duration must be between 5 and 480 minutes'; end if;
  if new.status <> 'Cancelled' and not exists (
    select 1 from public.profiles p
    where p.id=new.provider_profile_id and p.active and p.role=new.provider_role
  ) then raise exception 'appointment provider must be active and match the selected role'; end if;
  if new.status <> 'Cancelled' and exists (
    select 1 from public.appointments a
    where a.provider_profile_id = new.provider_profile_id
      and a.status <> 'Cancelled'
      and a.id <> coalesce(new.id, gen_random_uuid())
      and tsrange(a.date + a.time, a.date + a.time + make_interval(mins => a.duration), '[)')
          && tsrange(new.date + new.time, new.date + new.time + make_interval(mins => new.duration), '[)')
  ) then
    raise exception 'appointment overlaps an existing booking for this provider';
  end if;
  return new;
end;
$$;
drop trigger if exists appointments_prevent_overlap on public.appointments;
create trigger appointments_prevent_overlap before insert or update of provider_profile_id,date,time,duration,status
  on public.appointments for each row execute function public.prevent_appointment_overlap();

create or replace function public.available_appointment_slots(p_date date, p_provider_profile_id uuid)
returns table(slot_time time)
language plpgsql stable security definer set search_path = public as $$
declare
  dow text := to_char(p_date, 'Dy'); day_cfg jsonb; interval_min int;
  open_t time; close_t time; cur time;
begin
  select schedule -> dow, appointment_interval into day_cfg, interval_min
  from public.clinic_settings where id = 1;
  if not exists(select 1 from public.profiles where id=p_provider_profile_id and role='doctor' and active) then return; end if;
  if day_cfg is null or coalesce((day_cfg ->> 'consultation')::boolean,false)=false
    or day_cfg ->> 'open' is null or day_cfg ->> 'open' = '--' then return; end if;
  open_t := (day_cfg ->> 'open')::time; close_t := (day_cfg ->> 'close')::time; cur := open_t;
  while cur + make_interval(mins => coalesce(interval_min,30)) <= close_t loop
    if not exists (
      select 1 from public.appointments a
      where a.provider_profile_id = p_provider_profile_id and a.status <> 'Cancelled'
        and tsrange(a.date + a.time, a.date + a.time + make_interval(mins => a.duration), '[)')
            && tsrange(p_date + cur, p_date + cur + make_interval(mins => coalesce(interval_min,30)), '[)')
    ) then slot_time := cur; return next; end if;
    cur := cur + make_interval(mins => coalesce(interval_min,30));
  end loop;
end;
$$;

-- Queue appointment messages without storing a service-role secret in a
-- database setting. A scheduled/authorized Edge Function drains this queue.
create or replace function public.notify_appointment_whatsapp()
returns trigger language plpgsql security definer set search_path = public as $$
declare patient_full_name text; msg_body text; trigger_kind text;
begin
  if tg_op='INSERT' then trigger_kind := 'new_appointment';
  elsif tg_op='UPDATE' and (new.date is distinct from old.date or new.time is distinct from old.time) then trigger_kind := 'rescheduled';
  else return new;
  end if;
  select full_name into patient_full_name from public.patient_names where patient_id=new.patient_id;
  msg_body := format('%s your appointment for %s has been %s for %s at %s. — Phenry Health',
    coalesce(patient_full_name,'Hi,'),new.type,
    case when trigger_kind='rescheduled' then 'moved' else 'confirmed' end,
    to_char(new.date,'Mon DD, YYYY'),to_char(new.time,'HH12:MI AM'));
  insert into public.messages_log(patient_id,trigger_type,body,status)
  values(new.patient_id,trigger_kind,msg_body,'queued');
  return new;
end;
$$;

create or replace function public.schedule_procedure_with_bed(
  p_surgery_id uuid,
  p_patient_id text,
  p_procedure text,
  p_date date,
  p_time text,
  p_location text,
  p_provider_id uuid,
  p_bed_id text,
  p_notes text
)
returns public.surgery_schedule language plpgsql security definer set search_path = public as $$
declare result public.surgery_schedule; bed public.recovery_beds;
begin
  if public.current_app_role() not in ('doctor','matron') then raise exception 'not authorized'; end if;
  if public.current_app_role()='doctor' and not public.doctor_has_patient_access(p_patient_id) then raise exception 'patient is not assigned to this doctor'; end if;
  if nullif(trim(p_procedure),'') is null or p_date is null then raise exception 'procedure and date are required'; end if;
  if p_date < current_date then raise exception 'a procedure cannot be scheduled in the past'; end if;
  if not exists(select 1 from public.profiles where id=p_provider_id and active and role in ('doctor','matron')) then
    raise exception 'assigned provider must be an active doctor or matron';
  end if;
  select * into result from public.surgery_schedule where id=p_surgery_id;
  if found then
    if result.patient_id <> p_patient_id then raise exception 'idempotency key belongs to another procedure'; end if;
    return result;
  end if;
  if p_bed_id is not null then
    select * into bed from public.recovery_beds where id=p_bed_id for update;
    if not found or bed.status <> 'Free' then raise exception 'recovery bed is no longer available'; end if;
  end if;
  insert into public.surgery_schedule(id,patient_id,procedure,date,time,location,assigned_provider_id,recovery_bed_id,status,notes)
  values(p_surgery_id,p_patient_id,trim(p_procedure),p_date,p_time,p_location,p_provider_id,p_bed_id,'Scheduled',p_notes)
  returning * into result;
  if p_bed_id is not null then
    update public.recovery_beds set status='Reserved',occupied_by_patient_id=p_patient_id,occupied_since=null,reserved_for_date=p_date where id=p_bed_id;
  end if;
  perform public.log_audit_event('Procedure scheduled',p_surgery_id::text);
  return result;
end;
$$;

create or replace function public.set_recovery_bed_state(p_bed_id text, p_action text)
returns public.recovery_beds language plpgsql security definer set search_path = public as $$
declare bed public.recovery_beds;
begin
  if public.current_app_role() not in ('matron','nurse') then raise exception 'not authorized'; end if;
  select * into bed from public.recovery_beds where id=p_bed_id for update;
  if not found then raise exception 'recovery bed not found'; end if;
  if p_action='admit' then
    if bed.status <> 'Reserved' then raise exception 'only a reserved bed can be admitted'; end if;
    update public.recovery_beds set status='Occupied',occupied_since=now(),reserved_for_date=null where id=p_bed_id returning * into bed;
  elsif p_action='clear' then
    if bed.status='Free' then raise exception 'bed is already free'; end if;
    update public.recovery_beds set status='Free',occupied_by_patient_id=null,occupied_since=null,reserved_for_date=null where id=p_bed_id returning * into bed;
  else raise exception 'invalid bed action';
  end if;
  perform public.log_audit_event('Recovery bed '||p_action,p_bed_id);
  return bed;
end;
$$;


commit;
