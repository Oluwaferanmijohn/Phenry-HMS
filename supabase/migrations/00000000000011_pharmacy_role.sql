-- ============================================================================
-- Phenry Health — Pharmacy & Inventory role migration
-- ============================================================================

-- requisitions status text was 'Denied' — the prototype's exact string is
-- "Denied / Out of Stock" (denyRequisition). Aligning now that Pharmacy is
-- the role that actually sets it.
alter table public.requisitions drop constraint requisitions_status_check;
alter table public.requisitions add constraint requisitions_status_check check (status in ('Pending', 'Approved & Dispensed', 'Denied / Out of Stock'));

-- ----------------------------------------------------------------------------
-- pharmacy_inventory (§1 schema) — deliberately separate from lab_store,
-- per spec's explicit note matching the prototype's own design choice.
-- ----------------------------------------------------------------------------
create table public.pharmacy_inventory (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  current_qty int not null default 0,
  unit text not null default 'units',
  min_threshold int not null default 20,
  location text,
  expiry date
);
insert into public.pharmacy_inventory (name, category, current_qty, unit, min_threshold, location, expiry) values
  ('Gonal-F 450 IU', 'Gonadotropins', 45, 'pens', 20, 'Cold Storage A', current_date + 180),
  ('Cetrotide 0.25mg', 'GnRH Antagonists', 12, 'vials', 20, 'Cold Storage A', current_date + 120),
  ('Ovidrel 250mcg', 'Trigger Shots', 30, 'pens', 15, 'Cold Storage A', current_date + 200),
  ('Progesterone in Oil 50mg/mL', 'Luteal Support', 8, 'vials', 20, 'Room Temp Shelf B', current_date + 90);

alter table public.pharmacy_inventory enable row level security;
create policy "pharmacy full access to pharmacy_inventory"
  on public.pharmacy_inventory for all to authenticated
  using (public.current_app_role() = 'pharmacy') with check (public.current_app_role() = 'pharmacy');
create policy "admin reads pharmacy_inventory"
  on public.pharmacy_inventory for select to authenticated
  using (public.is_admin());

-- ----------------------------------------------------------------------------
-- prescriptions: "read (dispense)" — read all, and the one specific write
-- (flip status to Dispensed) needed to act on that read. A trigger keeps
-- Pharmacy from touching medication/dosage/patient while dispensing.
-- ----------------------------------------------------------------------------
create policy "pharmacy reads all prescriptions"
  on public.prescriptions for select to authenticated
  using (public.current_app_role() = 'pharmacy');
create policy "pharmacy dispenses prescriptions"
  on public.prescriptions for update to authenticated
  using (public.current_app_role() = 'pharmacy')
  with check (public.current_app_role() = 'pharmacy' and status = 'Dispensed');

create or replace function public.enforce_pharmacy_prescription_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() = 'pharmacy' then
    if new.patient_id is distinct from old.patient_id
      or new.medication is distinct from old.medication
      or new.sig is distinct from old.sig
      or new.prescribed_by_profile_id is distinct from old.prescribed_by_profile_id
      or new.prescribed_by_role is distinct from old.prescribed_by_role
    then
      raise exception 'Pharmacy may only dispense (change status), not edit the prescription itself';
    end if;
  end if;
  return new;
end;
$$;
create trigger prescriptions_enforce_pharmacy_update
  before update on public.prescriptions
  for each row execute function public.enforce_pharmacy_prescription_update();

-- ----------------------------------------------------------------------------
-- requisitions: "approve/deny, dispatch" — same reasoning, status-only write.
-- ----------------------------------------------------------------------------
create policy "pharmacy reads all requisitions"
  on public.requisitions for select to authenticated
  using (public.current_app_role() = 'pharmacy');
create policy "pharmacy approves/denies requisitions"
  on public.requisitions for update to authenticated
  using (public.current_app_role() = 'pharmacy')
  with check (public.current_app_role() = 'pharmacy');

create or replace function public.enforce_pharmacy_requisition_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() = 'pharmacy' then
    if new.requested_by_profile_id is distinct from old.requested_by_profile_id
      or new.ward is distinct from old.ward
      or new.items is distinct from old.items
      or new.urgency is distinct from old.urgency
    then
      raise exception 'Pharmacy may only approve/deny a requisition, not edit what was requested';
    end if;
  end if;
  return new;
end;
$$;
create trigger requisitions_enforce_pharmacy_update
  before update on public.requisitions
  for each row execute function public.enforce_pharmacy_requisition_update();
