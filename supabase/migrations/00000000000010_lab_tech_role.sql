-- ============================================================================
-- Phenry Health — Lab Technician role migration
--
-- Same column-level enforcement pattern as Receptionist: "limited
-- (lab-relevant fields only)" on bio_details can't be done with a plain RLS
-- policy (row-level, not column-level, and everyone hits Postgres as the
-- same `authenticated` role). Lab Tech gets NO raw SELECT on bio_details —
-- only two RPCs below returning a hardcoded lab-relevant column list
-- (identity + spouse/SFA per §3.8, no contact info/allergies/emergency
-- contact). patient_names is name-only and safe to grant directly, same
-- reasoning as Receptionist.
-- ============================================================================

create or replace function public.patients_lab_directory(p_search text default '')
returns table (
  patient_id text, first_name text, surname text, full_name text,
  dob date, sex text, blood_group text, spouse jsonb, status text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.current_app_role() not in ('lab_tech', 'chief_embryologist', 'admin_manager') then
    raise exception 'not authorized';
  end if;

  return query
  select pn.patient_id, pn.first_name, pn.surname, pn.full_name,
         bd.dob, bd.sex, bd.blood_group, bd.spouse, bd.status
  from public.patient_names pn
  join public.bio_details bd on bd.patient_id = pn.patient_id
  where p_search = '' or (pn.full_name || ' ' || pn.patient_id) ilike '%' || p_search || '%'
  order by pn.full_name asc;
end;
$$;
grant execute on function public.patients_lab_directory(text) to authenticated;

create or replace function public.patient_lab_profile(p_patient_id text)
returns table (
  patient_id text, first_name text, surname text, full_name text,
  dob date, sex text, blood_group text, spouse jsonb, status text
)
language sql
stable
security definer
set search_path = public
as $$
  select * from public.patients_lab_directory('') where patient_id = p_patient_id;
$$;
grant execute on function public.patient_lab_profile(text) to authenticated;

create policy "lab tech reads patient_names"
  on public.patient_names for select to authenticated
  using (public.current_app_role() = 'lab_tech');

-- lab_results/lab_templates/embryo_batches: full, same as Chief Embryologist
create policy "lab tech full access to lab_results"
  on public.lab_results for all to authenticated
  using (public.current_app_role() = 'lab_tech') with check (public.current_app_role() = 'lab_tech');
create policy "lab tech manages lab_templates"
  on public.lab_templates for all to authenticated
  using (public.current_app_role() = 'lab_tech') with check (public.current_app_role() = 'lab_tech');
create policy "lab tech full access to embryo_batches"
  on public.embryo_batches for all to authenticated
  using (public.current_app_role() = 'lab_tech') with check (public.current_app_role() = 'lab_tech');

-- transfer_cryo_schedule: shared page has no role-conditional actions, so
-- parity with Chief Embryologist (not an explicit matrix row).
create policy "lab tech full access to transfer_cryo_schedule"
  on public.transfer_cryo_schedule for all to authenticated
  using (public.current_app_role() = 'lab_tech') with check (public.current_app_role() = 'lab_tech');

-- cryo_records: read/write. cryo_tanks: read-only, no tank admin.
create policy "lab tech full access to cryo_records"
  on public.cryo_records for all to authenticated
  using (public.current_app_role() = 'lab_tech') with check (public.current_app_role() = 'lab_tech');
create policy "lab tech reads cryo_tanks"
  on public.cryo_tanks for select to authenticated
  using (public.current_app_role() = 'lab_tech');
-- Needed so logging a cryo_record can still increment the tank's `used`
-- count (the shared CryoLogModal does this) without granting general tank
-- administration. A self-referential WITH CHECK can't reliably diff NEW
-- against OLD, so this is enforced with a trigger — same reasoning as the
-- payment_milestones trigger in the Patient migration.
create policy "lab tech updates cryo_tanks usage"
  on public.cryo_tanks for update to authenticated
  using (public.current_app_role() = 'lab_tech')
  with check (public.current_app_role() = 'lab_tech');

create or replace function public.enforce_lab_tech_tank_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() = 'lab_tech' then
    if new.name is distinct from old.name or new.phase is distinct from old.phase or new.capacity is distinct from old.capacity then
      raise exception 'Lab Tech may only update a tank''s usage count, not its identity/capacity';
    end if;
  end if;
  return new;
end;
$$;
create trigger cryo_tanks_enforce_lab_tech_update
  before update on public.cryo_tanks
  for each row execute function public.enforce_lab_tech_tank_update();

-- incubator_logs: daily QC entry (read + update, no create/delete of units).
-- lab_equipment/lab_store: read-only (servicing/stock management stays with
-- the Chief Embryologist).
create policy "lab tech reads/updates incubator_logs"
  on public.incubator_logs for select to authenticated
  using (public.current_app_role() = 'lab_tech');
create policy "lab tech logs daily incubator QC"
  on public.incubator_logs for update to authenticated
  using (public.current_app_role() = 'lab_tech')
  with check (public.current_app_role() = 'lab_tech');

create or replace function public.enforce_lab_tech_incubator_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() = 'lab_tech' then
    if new.name is distinct from old.name or new.location is distinct from old.location then
      raise exception 'Lab Tech may only log QC readings, not rename or relocate a unit';
    end if;
  end if;
  return new;
end;
$$;
create trigger incubator_logs_enforce_lab_tech_update
  before update on public.incubator_logs
  for each row execute function public.enforce_lab_tech_incubator_update();

create policy "lab tech reads lab_equipment"
  on public.lab_equipment for select to authenticated
  using (public.current_app_role() = 'lab_tech');
create policy "lab tech reads lab_store"
  on public.lab_store for select to authenticated
  using (public.current_app_role() = 'lab_tech');

create policy "lab tech creates requisitions"
  on public.requisitions for insert to authenticated
  with check (public.current_app_role() = 'lab_tech' and requested_by_profile_id = auth.uid());
create policy "lab tech reads own requisitions"
  on public.requisitions for select to authenticated
  using (public.current_app_role() = 'lab_tech' and requested_by_profile_id = auth.uid());
