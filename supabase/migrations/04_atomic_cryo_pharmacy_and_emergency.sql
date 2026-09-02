-- Phenry Health migration 18 — part 4 of 5
-- RUN SEQUENTIALLY. Do not execute this file in parallel with another part.
-- If this part fails, correct the reported issue and rerun this same part before continuing.

begin;
-- ---------------------------------------------------------------------------
-- 7. Atomic cryo and pharmacy operations.
-- ---------------------------------------------------------------------------
create table if not exists public.cryo_movements (
  id uuid primary key default gen_random_uuid(),
  cryo_record_id uuid not null references public.cryo_records(id),
  quantity_delta int not null check (quantity_delta <> 0),
  reason text not null,
  actor_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.cryo_movements enable row level security;
drop policy if exists "embryology reads cryo movements" on public.cryo_movements;
create policy "embryology reads cryo movements" on public.cryo_movements for select to authenticated
  using (public.current_app_role() = 'chief_embryologist' or public.is_admin());

create or replace function public.log_cryo_record(
  p_patient_id text, p_asset_type text, p_straws int, p_freezing_date date,
  p_tank_id uuid, p_canister text, p_position text, p_notes text
)
returns public.cryo_records language plpgsql security definer set search_path = public as $$
declare t public.cryo_tanks; r public.cryo_records;
begin
  if public.current_app_role() <> 'chief_embryologist' then raise exception 'not authorized'; end if;
  if p_straws <= 0 then raise exception 'straw count must be positive'; end if;
  if p_tank_id is not null then
    select * into t from public.cryo_tanks where id = p_tank_id for update;
    if not found then raise exception 'tank not found'; end if;
    if t.used + p_straws > t.capacity then raise exception 'tank does not have enough capacity'; end if;
  end if;
  insert into public.cryo_records(patient_id,asset_type,straws,freezing_date,tank_id,canister,position,notes,logged_by,status)
  values(p_patient_id,p_asset_type,p_straws,coalesce(p_freezing_date,current_date),p_tank_id,p_canister,p_position,p_notes,auth.uid(),'Stored')
  returning * into r;
  if p_tank_id is not null then update public.cryo_tanks set used = used + p_straws where id = p_tank_id; end if;
  insert into public.cryo_movements(cryo_record_id,quantity_delta,reason,actor_id)
  values(r.id,p_straws,'Added to cryogenic storage',auth.uid());
  return r;
end;
$$;

-- Keep the quantity default for compatibility with the pre-existing RPC.
-- PostgreSQL rejects CREATE OR REPLACE when it would remove an existing
-- argument default, even though the identity signature itself is unchanged.
create or replace function public.use_cryo_record(p_record_id uuid, p_straws_used int default 1)
returns public.cryo_records language plpgsql security definer set search_path = public as $$
declare r public.cryo_records; remaining int;
begin
  if public.current_app_role() <> 'chief_embryologist' then raise exception 'not authorized'; end if;
  select * into r from public.cryo_records where id = p_record_id for update;
  if not found then raise exception 'cryo record not found'; end if;
  if r.status <> 'Stored' then raise exception 'cryo record is no longer in storage'; end if;
  if p_straws_used <= 0 or p_straws_used > r.straws then raise exception 'invalid straw quantity'; end if;
  remaining := r.straws - p_straws_used;
  update public.cryo_records set
    straws = greatest(remaining,0),
    status = case when remaining = 0 then 'Used' else 'Stored' end,
    used_date = case when remaining = 0 then current_date else null end,
    used_by = case when remaining = 0 then auth.uid() else null end
  where id = p_record_id returning * into r;
  if r.tank_id is not null then
    update public.cryo_tanks set used = greatest(0, used - p_straws_used) where id = r.tank_id;
  end if;
  insert into public.cryo_movements(cryo_record_id,quantity_delta,reason,actor_id)
  values(p_record_id,-p_straws_used,'Removed from cryogenic storage',auth.uid());
  return r;
end;
$$;

create or replace function public.document_transfer_cryo_event(
  p_event_id uuid,
  p_action text,
  p_notes text,
  p_new_date date default null,
  p_embryos_used int default null,
  p_deduct_cryo boolean default false
)
returns public.transfer_cryo_schedule language plpgsql security definer set search_path = public as $$
declare event_row public.transfer_cryo_schedule; record_row public.cryo_records; remaining int; take_qty int;
begin
  if public.current_app_role() not in ('chief_embryologist','lab_tech') then raise exception 'not authorized'; end if;
  if p_action not in ('Done','Postponed','Cancelled') then raise exception 'invalid action'; end if;
  if nullif(trim(p_notes),'') is null then raise exception 'clinical documentation is required'; end if;
  select * into event_row from public.transfer_cryo_schedule where id=p_event_id for update;
  if not found then raise exception 'schedule event not found'; end if;
  if event_row.status=p_action and event_row.embryos_used is not distinct from p_embryos_used and event_row.used_from_cryo=p_deduct_cryo then return event_row; end if;
  if event_row.status in ('Done','Cancelled') then raise exception 'completed events cannot be changed'; end if;
  if p_action='Postponed' and p_new_date is null then raise exception 'a new date is required'; end if;
  if p_action='Done' and lower(event_row.type) like '%transfer%' and (p_embryos_used is null or p_embryos_used < 1) then
    raise exception 'embryos transferred must be recorded';
  end if;
  if p_deduct_cryo and (p_action <> 'Done' or lower(event_row.type) not like '%transfer%') then raise exception 'cryo deduction only applies to a completed transfer'; end if;

  if p_deduct_cryo then
    remaining := p_embryos_used;
    for record_row in
      select * from public.cryo_records
      where patient_id=event_row.patient_id and asset_type='Embryo' and status='Stored' and straws>0
      order by freezing_date,id for update
    loop
      exit when remaining=0;
      take_qty := least(remaining,record_row.straws);
      update public.cryo_records set
        straws=straws-take_qty,
        status=case when straws-take_qty=0 then 'Used' else 'Stored' end,
        used_date=case when straws-take_qty=0 then current_date else null end,
        used_by=case when straws-take_qty=0 then auth.uid() else null end
      where id=record_row.id;
      if record_row.tank_id is not null then update public.cryo_tanks set used=greatest(0,used-take_qty) where id=record_row.tank_id; end if;
      insert into public.cryo_movements(cryo_record_id,quantity_delta,reason,actor_id)
      values(record_row.id,-take_qty,'Used for transfer '||p_event_id::text,auth.uid());
      remaining := remaining-take_qty;
    end loop;
    if remaining > 0 then raise exception 'not enough embryos are recorded in cryo storage'; end if;
  end if;

  update public.transfer_cryo_schedule set
    status=p_action,notes=trim(p_notes),documented_by=auth.uid(),documented_on=current_date,
    scheduled_date=case when p_action='Postponed' then p_new_date else scheduled_date end,
    embryos_used=case when p_action='Done' and lower(type) like '%transfer%' then p_embryos_used else null end,
    used_from_cryo=case when p_action='Done' then p_deduct_cryo else false end
  where id=p_event_id returning * into event_row;
  perform public.log_audit_event('Transfer/cryo event documented',p_event_id::text);
  return event_row;
end;
$$;

create table if not exists public.pharmacy_stock_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_id uuid not null references public.pharmacy_inventory(id),
  quantity_delta int not null,
  reason text not null,
  reference_id uuid,
  actor_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
alter table public.pharmacy_stock_movements enable row level security;
drop policy if exists "pharmacy reads stock movements" on public.pharmacy_stock_movements;
create policy "pharmacy reads stock movements" on public.pharmacy_stock_movements for select to authenticated
  using (public.current_app_role() = 'pharmacy' or public.is_admin());

create or replace function public.receive_pharmacy_stock(
  p_inventory_id uuid,
  p_quantity int,
  p_batch_number text default null,
  p_expiry date default null
)
returns public.pharmacy_inventory language plpgsql security definer set search_path = public as $$
declare inv public.pharmacy_inventory;
begin
  if public.current_app_role() <> 'pharmacy' then raise exception 'not authorized'; end if;
  if p_quantity <= 0 then raise exception 'quantity must be positive'; end if;
  select * into inv from public.pharmacy_inventory where id=p_inventory_id for update;
  if not found then raise exception 'inventory item not found'; end if;
  update public.pharmacy_inventory set
    current_qty=current_qty+p_quantity,
    batch_number=coalesce(nullif(trim(p_batch_number),''),batch_number),
    expiry=coalesce(p_expiry,expiry)
  where id=p_inventory_id returning * into inv;
  insert into public.pharmacy_stock_movements(inventory_id,quantity_delta,reason,actor_id)
  values(p_inventory_id,p_quantity,'Shipment received',auth.uid());
  return inv;
end;
$$;

create or replace function public.dispense_prescription(p_prescription_id uuid, p_inventory_id uuid, p_quantity int default 1)
returns public.prescriptions language plpgsql security definer set search_path = public as $$
declare rx public.prescriptions; inv public.pharmacy_inventory;
begin
  if public.current_app_role() <> 'pharmacy' then raise exception 'not authorized'; end if;
  if p_quantity <= 0 then raise exception 'quantity must be positive'; end if;
  select * into rx from public.prescriptions where id = p_prescription_id for update;
  if not found or rx.status <> 'Pending' then raise exception 'prescription is not pending'; end if;
  select * into inv from public.pharmacy_inventory where id = p_inventory_id for update;
  if not found then raise exception 'inventory item not found'; end if;
  if inv.current_qty < p_quantity then raise exception 'insufficient stock'; end if;
  update public.pharmacy_inventory set current_qty = current_qty - p_quantity where id = p_inventory_id;
  update public.prescriptions set status = 'Dispensed' where id = p_prescription_id returning * into rx;
  insert into public.pharmacy_stock_movements(inventory_id,quantity_delta,reason,reference_id,actor_id)
  values(p_inventory_id,-p_quantity,'Prescription dispensed',p_prescription_id,auth.uid());
  return rx;
end;
$$;

create or replace function public.approve_requisition(p_requisition_id uuid)
returns public.requisitions language plpgsql security definer set search_path = public as $$
declare req public.requisitions; item jsonb; inv public.pharmacy_inventory; qty int;
begin
  if public.current_app_role() <> 'pharmacy' then raise exception 'not authorized'; end if;
  select * into req from public.requisitions where id = p_requisition_id for update;
  if not found or req.status <> 'Pending' then raise exception 'requisition is not pending'; end if;
  for item in select * from jsonb_array_elements(req.items) loop
    qty := coalesce((item->>'qty')::int,0);
    if nullif(trim(item->>'name'),'') is null or qty < 1 then raise exception 'requisition contains an invalid item'; end if;
    select * into inv from public.pharmacy_inventory
      where lower(trim(name)) = lower(trim(item->>'name'))
         or lower(item->>'name') like lower(trim(name)) || '%'
      order by case when lower(trim(name)) = lower(trim(item->>'name')) then 0 else 1 end
      limit 1 for update;
    if not found then raise exception 'no inventory match for %', item->>'name'; end if;
    if inv.current_qty < qty then raise exception 'insufficient stock for %', inv.name; end if;
    update public.pharmacy_inventory set current_qty = current_qty - qty where id = inv.id;
    insert into public.pharmacy_stock_movements(inventory_id,quantity_delta,reason,reference_id,actor_id)
    values(inv.id,-qty,'Ward requisition dispensed',p_requisition_id,auth.uid());
  end loop;
  update public.requisitions set status = 'Approved & Dispensed' where id = p_requisition_id returning * into req;
  return req;
end;
$$;

create or replace function public.deny_requisition(p_requisition_id uuid, p_reason text default null)
returns public.requisitions language plpgsql security definer set search_path = public as $$
declare req public.requisitions;
begin
  if public.current_app_role() <> 'pharmacy' then raise exception 'not authorized'; end if;
  update public.requisitions
  set status = 'Denied / Out of Stock'
  where id = p_requisition_id and status = 'Pending'
  returning * into req;
  if not found then raise exception 'requisition is not pending'; end if;
  perform public.log_audit_event('Requisition denied',p_requisition_id::text || coalesce(': ' || left(trim(p_reason),200),''));
  return req;
end;
$$;

create or replace function public.admin_manage_staff(
  p_profile_id uuid,
  p_full_name text,
  p_role text default null,
  p_custom_role_key text default null,
  p_active boolean default true,
  p_phone text default null
)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare target public.profiles; updated public.profiles; active_admins int;
begin
  if public.current_app_role() <> 'admin_manager' then raise exception 'not authorized'; end if;
  if p_profile_id = auth.uid() and not p_active then raise exception 'you cannot revoke your own account'; end if;
  if nullif(trim(p_full_name),'') is null or length(trim(p_full_name)) > 120 then raise exception 'invalid staff name'; end if;
  if (p_role is null) = (p_custom_role_key is null) then raise exception 'choose exactly one fixed or custom role'; end if;
  if p_role is not null and p_role not in ('receptionist','admin_manager','doctor','matron','nurse','chief_embryologist','lab_tech','pharmacy','stakeholder') then
    raise exception 'invalid staff role';
  end if;
  if p_custom_role_key is not null and not exists(select 1 from public.custom_roles where role_key=p_custom_role_key) then
    raise exception 'custom role does not exist';
  end if;

  perform pg_advisory_xact_lock(hashtext('phenry-active-admin-change'));
  select * into target from public.profiles where id=p_profile_id for update;
  if not found or target.role='patient' then raise exception 'staff account not found'; end if;
  if target.role='admin_manager' and (p_role is distinct from 'admin_manager' or not p_active) then
    select count(*) into active_admins from public.profiles where role='admin_manager' and active;
    if active_admins <= 1 then raise exception 'the last active Admin Manager cannot be demoted or revoked'; end if;
  end if;
  update public.profiles set
    full_name=trim(p_full_name), role=p_role, custom_role_key=p_custom_role_key, active=p_active
  where id=p_profile_id returning * into updated;
  insert into public.staff_contacts(profile_id,phone) values(p_profile_id,nullif(trim(p_phone),''))
  on conflict(profile_id) do update set phone=excluded.phone;
  perform public.log_audit_event('Staff access updated',p_profile_id::text);
  return updated;
end;
$$;

create or replace function public.save_payment_plan(
  p_patient_id text,
  p_package text,
  p_total numeric,
  p_milestones jsonb
)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_plan_id uuid; item jsonb; milestone_total numeric := 0;
begin
  if public.current_app_role() <> 'doctor' or not public.doctor_has_patient_access(p_patient_id) then
    raise exception 'not authorized';
  end if;
  if nullif(trim(p_package),'') is null or p_total is null or p_total < 0 or jsonb_typeof(p_milestones) <> 'array' then
    raise exception 'invalid payment plan';
  end if;
  for item in select * from jsonb_array_elements(p_milestones) loop
    if nullif(trim(item->>'label'),'') is null or coalesce((item->>'amount')::numeric,-1) < 0 then
      raise exception 'invalid payment milestone';
    end if;
    milestone_total := milestone_total + (item->>'amount')::numeric;
  end loop;
  if milestone_total <> p_total then raise exception 'milestones must add up to the plan total'; end if;

  select id into v_plan_id from public.payment_plans where patient_id = p_patient_id limit 1 for update;
  if v_plan_id is null then
    insert into public.payment_plans(patient_id,package,total_cost)
    values(p_patient_id,trim(p_package),p_total) returning id into v_plan_id;
  else
    if exists (
      select 1 from public.payment_milestones
      where plan_id=v_plan_id and (status <> 'Upcoming' or proof_url is not null)
    ) then raise exception 'a payment plan with submitted or approved payments cannot be replaced'; end if;
    update public.payment_plans set package=trim(p_package),total_cost=p_total where id=v_plan_id;
    delete from public.payment_milestones where plan_id=v_plan_id;
  end if;
  insert into public.payment_milestones(plan_id,label,amount,status,due_context)
  select v_plan_id,trim(value->>'label'),(value->>'amount')::numeric,'Upcoming','Scheduled'
  from jsonb_array_elements(p_milestones);
  perform public.log_audit_event('Payment plan saved',p_patient_id);
  return v_plan_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Emergency broadcast with an auditable delivery queue.
-- ---------------------------------------------------------------------------
create table if not exists public.emergency_broadcasts (
  id uuid primary key default gen_random_uuid(),
  message text not null check (length(trim(message)) between 5 and 1000),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create table if not exists public.emergency_broadcast_recipients (
  id uuid primary key default gen_random_uuid(),
  broadcast_id uuid not null references public.emergency_broadcasts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id),
  phone text not null,
  status text not null default 'queued' check (status in ('queued','sent','failed')),
  sent_at timestamptz,
  error_message text,
  unique(broadcast_id,profile_id)
);
alter table public.emergency_broadcasts enable row level security;
alter table public.emergency_broadcast_recipients enable row level security;
drop policy if exists "leaders read emergency broadcasts" on public.emergency_broadcasts;
create policy "leaders read emergency broadcasts" on public.emergency_broadcasts for select to authenticated
  using (public.current_app_role() in ('admin_manager','matron'));
drop policy if exists "leaders read emergency recipients" on public.emergency_broadcast_recipients;
create policy "leaders read emergency recipients" on public.emergency_broadcast_recipients for select to authenticated
  using (public.current_app_role() in ('admin_manager','matron'));

create or replace function public.trigger_emergency_broadcast(p_message text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare b_id uuid; queued_count int; missing_count int;
begin
  if public.current_app_role() not in ('admin_manager','matron') then raise exception 'not authorized'; end if;
  if length(trim(coalesce(p_message,''))) < 5 then raise exception 'message is too short'; end if;
  insert into public.emergency_broadcasts(message,created_by) values(trim(p_message),auth.uid()) returning id into b_id;
  insert into public.emergency_broadcast_recipients(broadcast_id,profile_id,phone)
  select b_id,p.id,c.phone from public.profiles p join public.staff_contacts c on c.profile_id=p.id
  where p.active and p.role in ('doctor','matron','nurse','chief_embryologist','lab_tech') and nullif(trim(c.phone),'') is not null;
  get diagnostics queued_count = row_count;
  select count(*) into missing_count from public.profiles p left join public.staff_contacts c on c.profile_id=p.id
  where p.active and p.role in ('doctor','matron','nurse','chief_embryologist','lab_tech') and nullif(trim(c.phone),'') is null;
  perform public.log_audit_event('Emergency Broadcast', b_id::text);
  return jsonb_build_object('broadcast_id',b_id,'queued',queued_count,'missing_phone',missing_count);
end;
$$;


commit;
