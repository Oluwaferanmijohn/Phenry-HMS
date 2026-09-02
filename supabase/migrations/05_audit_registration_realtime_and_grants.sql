-- Phenry Health migration 18 — part 5 of 5
-- RUN SEQUENTIALLY. Do not execute this file in parallel with another part.
-- If this part fails, correct the reported issue and rerun this same part before continuing.

begin;
-- ---------------------------------------------------------------------------
-- 9. Audit integrity and broad mutation coverage.
-- ---------------------------------------------------------------------------
create or replace function public.log_audit_event(p_action_type text, p_target text default null)
returns void language plpgsql security definer set search_path = public as $$
declare actor_name text; actor_role text;
begin
  if auth.uid() is null or public.current_app_role() not in ('admin_manager','receptionist','matron','doctor','nurse','chief_embryologist','lab_tech','pharmacy') then
    raise exception 'not authorized to write audit events';
  end if;
  if nullif(trim(p_action_type),'') is null then raise exception 'audit action is required'; end if;
  select coalesce(full_name,'Unknown'),coalesce(role,custom_role_key,'unknown') into actor_name,actor_role
  from public.profiles where id=auth.uid() and active;
  insert into public.audit_log(actor_id,staff_name,role,action_type,target)
  values(auth.uid(),coalesce(actor_name,'Unknown'),coalesce(actor_role,'unknown'),'App: '||left(trim(p_action_type),115),left(p_target,500));
end;
$$;

create or replace function public.audit_sensitive_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare d jsonb; entity text; actor_name text; actor_role text;
begin
  if auth.uid() is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  d := case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  entity := coalesce(d->>'id',d->>'patient_id',d->>'surgery_id',d->>'profile_id',d->>'date','unknown');
  select coalesce(full_name,'Unknown'),coalesce(role,custom_role_key,'unknown') into actor_name,actor_role
  from public.profiles where id=auth.uid();
  insert into public.audit_log(actor_id,staff_name,role,action_type,target)
  values(auth.uid(),coalesce(actor_name,'Unknown'),coalesce(actor_role,'unknown'),tg_op||' '||tg_table_name,entity);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','bio_details','cycles','appointments','consultations','payment_plans','payment_milestones','prescriptions','lab_results','surgery_schedule','operative_reports','cryo_records','cryo_movements','requisitions','pharmacy_inventory','pharmacy_stock_movements','nurse_visits','nursing_tasks','medication_adherence','supplier_requests','staff_contacts'] loop
    execute format('drop trigger if exists %I on public.%I','audit_'||t,t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.audit_sensitive_change()','audit_'||t,t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 10. Least-loaded doctor assignment.
-- ---------------------------------------------------------------------------
create or replace function public.register_new_patient(
  p_first text,p_last text,p_dob date,p_sex text,p_phone text,p_email text,p_address text,
  p_ec_name text,p_ec_relationship text,p_ec_phone text,p_referral_source text
)
returns table(patient_id text,mrn text) language plpgsql security definer set search_path=public as $$
declare new_patient_id text; assigned_doctor uuid;
begin
  if public.current_app_role() not in ('receptionist','admin_manager') then raise exception 'not authorized to register patients'; end if;
  if nullif(trim(p_first),'') is null or nullif(trim(p_last),'') is null or length(trim(p_first))>80 or length(trim(p_last))>80 then raise exception 'valid patient names are required'; end if;
  if p_dob is null or p_dob > current_date or p_dob < current_date - interval '120 years' then raise exception 'valid date of birth is required'; end if;
  if p_sex not in ('F','M','Female','Male','Other','Intersex','Unknown') then raise exception 'invalid sex value'; end if;
  new_patient_id := public.generate_mrn(trim(p_last));
  select p.id into assigned_doctor from public.profiles p
  left join public.bio_details b on b.assigned_doctor_id=p.id
  where p.role='doctor' and p.active
  group by p.id,p.created_at order by count(b.patient_id),p.created_at limit 1;
  insert into public.patient_names(patient_id,first_name,surname,full_name)
  values(new_patient_id,trim(p_first),trim(p_last),trim(p_first)||' '||trim(p_last));
  insert into public.bio_details(patient_id,dob,sex,phone,email,address,emergency_contact,referral_source,registered_on,assigned_doctor_id,status)
  values(new_patient_id,p_dob,p_sex,p_phone,p_email,p_address,jsonb_build_object('name',p_ec_name,'relationship',p_ec_relationship,'phone',p_ec_phone),p_referral_source,current_date,assigned_doctor,'Scheduled');
  perform public.log_audit_event('Created Record',new_patient_id);
  return query select new_patient_id,new_patient_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Realtime publication. Each ALTER is guarded for hosted/local parity.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','patient_names','bio_details','cycles','cycle_daily_logs','cycle_investigations','cycle_ultrasounds',
    'consultations','appointments','payment_plans','payment_milestones','prescriptions','pharmacy_inventory','pharmacy_stock_movements',
    'requisitions','lab_results','lab_templates','lab_test_orders','recovery_beds','surgery_schedule','operative_reports','duty_roster',
    'embryo_batches','transfer_cryo_schedule','cryo_tanks','cryo_records','incubator_logs','lab_equipment','lab_store','messages_log',
    'audit_log','clinic_settings','custom_roles','role_permissions','nurse_visits','nursing_tasks','medication_adherence','supplier_requests','cryo_movements','emergency_broadcasts','emergency_broadcast_recipients'
  ] loop
    begin execute format('alter publication supabase_realtime add table public.%I',t);
    exception when duplicate_object then null; when undefined_object then null; end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 12. Function execution privileges. PostgreSQL grants EXECUTE to PUBLIC by
-- default; every exposed SECURITY DEFINER RPC is explicitly narrowed here.
-- ---------------------------------------------------------------------------
revoke all on function public.current_app_role() from public, anon;
grant execute on function public.current_app_role() to authenticated;
revoke all on function public.current_custom_role_key() from public, anon;
grant execute on function public.current_custom_role_key() to authenticated;
revoke all on function public.complete_password_reset() from public, anon;
grant execute on function public.complete_password_reset() to authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.enforce_patient_milestone_update() from public, anon, authenticated;
revoke all on function public.enforce_cycle_manager_is_nurse() from public, anon, authenticated;
revoke all on function public.sync_cycle_day_from_log() from public, anon, authenticated;
revoke all on function public.notify_appointment_whatsapp() from public, anon, authenticated;
revoke all on function public.audit_sensitive_change() from public, anon, authenticated;
revoke all on function public.generate_mrn(text) from public, anon, authenticated;
revoke all on function public.log_audit_event(text,text) from public, anon;
grant execute on function public.log_audit_event(text,text) to authenticated;
revoke all on function public.available_appointment_slots(date,uuid) from public, anon;
grant execute on function public.available_appointment_slots(date,uuid) to authenticated;
revoke all on function public.schedule_procedure_with_bed(uuid,text,text,date,text,text,uuid,text,text) from public, anon;
grant execute on function public.schedule_procedure_with_bed(uuid,text,text,date,text,text,uuid,text,text) to authenticated;
revoke all on function public.set_recovery_bed_state(text,text) from public, anon;
grant execute on function public.set_recovery_bed_state(text,text) to authenticated;
revoke all on function public.register_new_patient(text,text,date,text,text,text,text,text,text,text,text) from public, anon;
grant execute on function public.register_new_patient(text,text,date,text,text,text,text,text,text,text,text) to authenticated;
revoke all on function public.log_cryo_record(text,text,int,date,uuid,text,text,text) from public, anon;
grant execute on function public.log_cryo_record(text,text,int,date,uuid,text,text,text) to authenticated;
revoke all on function public.use_cryo_record(uuid,int) from public, anon;
grant execute on function public.use_cryo_record(uuid,int) to authenticated;
revoke all on function public.document_transfer_cryo_event(uuid,text,text,date,int,boolean) from public, anon;
grant execute on function public.document_transfer_cryo_event(uuid,text,text,date,int,boolean) to authenticated;
revoke all on function public.dispense_prescription(uuid,uuid,int) from public, anon;
grant execute on function public.dispense_prescription(uuid,uuid,int) to authenticated;
revoke all on function public.receive_pharmacy_stock(uuid,int,text,date) from public, anon;
grant execute on function public.receive_pharmacy_stock(uuid,int,text,date) to authenticated;
revoke all on function public.approve_requisition(uuid) from public, anon;
grant execute on function public.approve_requisition(uuid) to authenticated;
revoke all on function public.deny_requisition(uuid,text) from public, anon;
grant execute on function public.deny_requisition(uuid,text) to authenticated;
revoke all on function public.save_payment_plan(text,text,numeric,jsonb) from public, anon;
grant execute on function public.save_payment_plan(text,text,numeric,jsonb) to authenticated;
revoke all on function public.admin_manage_staff(uuid,text,text,text,boolean,text) from public, anon;
grant execute on function public.admin_manage_staff(uuid,text,text,text,boolean,text) to authenticated;
revoke all on function public.trigger_emergency_broadcast(text) from public, anon;
grant execute on function public.trigger_emergency_broadcast(text) to authenticated;
do $$
declare legacy_function regprocedure;
begin
  for legacy_function in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname='custom_role_scope_ok'
      and pg_catalog.oidvectortypes(p.proargtypes) <> 'text, text, uuid'
  loop
    execute format('revoke all on function %s from public, anon, authenticated',legacy_function);
  end loop;
end $$;
revoke all on function public.custom_role_scope_ok(text,text,uuid) from public, anon;
grant execute on function public.custom_role_scope_ok(text,text,uuid) to authenticated;
revoke all on function public.custom_resource_aggregate_count(text) from public, anon;
grant execute on function public.custom_resource_aggregate_count(text) to authenticated;

do $$
declare f regprocedure;
begin
  foreach f in array array[
    'public.approve_milestone(uuid)'::regprocedure,'public.reject_milestone(uuid)'::regprocedure,
    'public.exec_overview()'::regprocedure,'public.exec_financials()'::regprocedure,
    'public.exec_operations()'::regprocedure,'public.exec_growth()'::regprocedure,
    'public.patients_front_desk_directory(text)'::regprocedure,'public.patient_front_desk_profile(text)'::regprocedure,
    'public.patients_lab_directory(text)'::regprocedure,'public.patient_lab_profile(text)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon',f);
    execute format('grant execute on function %s to authenticated',f);
  end loop;
end $$;

notify pgrst, 'reload schema';

commit;
