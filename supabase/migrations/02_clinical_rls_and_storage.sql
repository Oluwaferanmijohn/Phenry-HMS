-- Phenry Health migration 18 — part 2 of 5
-- RUN SEQUENTIALLY. Do not execute this file in parallel with another part.
-- If this part fails, correct the reported issue and rerun this same part before continuing.

begin;
-- ---------------------------------------------------------------------------
-- 3. Missing clinical RLS.
-- ---------------------------------------------------------------------------
drop policy if exists "doctor reads own patients' lab_results" on public.lab_results;
create policy "doctor reads own patients' lab_results" on public.lab_results
  for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));

drop policy if exists "doctor or matron creates lab test orders" on public.lab_test_orders;
create policy "doctor or matron creates lab test orders" on public.lab_test_orders
  for insert to authenticated with check (
    ordered_by_profile_id = auth.uid()
    and ordered_by_role = public.current_app_role()
    and (
      (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id))
      or public.current_app_role() = 'matron'
    )
  );
drop policy if exists "clinical roles read lab test orders" on public.lab_test_orders;
create policy "clinical roles read lab test orders" on public.lab_test_orders
  for select to authenticated using (
    public.current_app_role() in ('matron', 'chief_embryologist', 'lab_tech', 'admin_manager')
    or (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id))
  );
drop policy if exists "lab roles action lab test orders" on public.lab_test_orders;
create policy "lab roles action lab test orders" on public.lab_test_orders
  for update to authenticated
  using (public.current_app_role() in ('chief_embryologist', 'lab_tech'))
  with check (public.current_app_role() in ('chief_embryologist', 'lab_tech'));

drop policy if exists "chief embryologist reads cycles" on public.cycles;
create policy "chief embryologist reads cycles" on public.cycles for select to authenticated
  using (public.current_app_role() = 'chief_embryologist');
drop policy if exists "lab tech reads cycles" on public.cycles;
create policy "lab tech reads cycles" on public.cycles for select to authenticated
  using (public.current_app_role() = 'lab_tech');

do $$
declare t text;
begin
  foreach t in array array['cycle_daily_logs','cycle_investigations','cycle_ultrasounds'] loop
    execute format('drop policy if exists %I on public.%I', 'chief embryologist reads ' || t, t);
    execute format('create policy %I on public.%I for select to authenticated using (public.current_app_role() = ''chief_embryologist'')', 'chief embryologist reads ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'lab tech reads ' || t, t);
    execute format('create policy %I on public.%I for select to authenticated using (public.current_app_role() = ''lab_tech'')', 'lab tech reads ' || t, t);
  end loop;
end $$;

drop policy if exists "doctor reads procedures they scheduled or are assigned to" on public.surgery_schedule;
drop policy if exists "doctor reads all procedures" on public.surgery_schedule;
create policy "doctor reads all procedures" on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'doctor');
drop policy if exists "chief embryologist reads surgery_schedule" on public.surgery_schedule;
create policy "chief embryologist reads surgery_schedule" on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'chief_embryologist');
drop policy if exists "lab tech reads surgery_schedule" on public.surgery_schedule;
create policy "lab tech reads surgery_schedule" on public.surgery_schedule for select to authenticated
  using (public.current_app_role() = 'lab_tech');

drop policy if exists "doctor reads transfer cryo schedule" on public.transfer_cryo_schedule;
create policy "doctor reads transfer cryo schedule" on public.transfer_cryo_schedule for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));
drop policy if exists "matron reads transfer cryo schedule" on public.transfer_cryo_schedule;
create policy "matron reads transfer cryo schedule" on public.transfer_cryo_schedule for select to authenticated
  using (public.current_app_role() = 'matron');
drop policy if exists "nurse reads transfer cryo schedule" on public.transfer_cryo_schedule;
create policy "nurse reads transfer cryo schedule" on public.transfer_cryo_schedule for select to authenticated
  using (public.current_app_role() = 'nurse');

drop policy if exists "authenticated non-stakeholders read recovery_beds" on public.recovery_beds;
drop policy if exists "authenticated clinical roles read recovery_beds" on public.recovery_beds;
create policy "authenticated clinical roles read recovery_beds" on public.recovery_beds
  for select to authenticated using (public.current_app_role() in (
    'receptionist','admin_manager','doctor','matron','nurse','chief_embryologist','lab_tech','pharmacy'
  ));

-- nurse_visits policies are repeated idempotently for partial migration 17.
drop policy if exists "nurse manages nurse_visits" on public.nurse_visits;
create policy "nurse manages nurse_visits" on public.nurse_visits for all to authenticated
  using (public.current_app_role() = 'nurse') with check (public.current_app_role() = 'nurse');
drop policy if exists "doctor reads own patients' nurse_visits" on public.nurse_visits;
create policy "doctor reads own patients' nurse_visits" on public.nurse_visits for select to authenticated
  using (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id));
drop policy if exists "matron reads nurse_visits" on public.nurse_visits;
create policy "matron reads nurse_visits" on public.nurse_visits for select to authenticated
  using (public.current_app_role() = 'matron');
drop policy if exists "admin reads nurse_visits" on public.nurse_visits;
create policy "admin reads nurse_visits" on public.nurse_visits for select to authenticated
  using (public.is_admin());
drop policy if exists "patient reads own nurse_visits" on public.nurse_visits;
create policy "patient reads own nurse_visits" on public.nurse_visits for select to authenticated
  using (patient_id = public.current_patient_id());

drop policy if exists "patient records own medication adherence" on public.medication_adherence;
create policy "patient records own medication adherence" on public.medication_adherence
  for insert to authenticated
  with check (
    public.current_app_role() = 'patient'
    and patient_id = public.current_patient_id()
    and recorded_by = auth.uid()
    and exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id and p.patient_id = public.current_patient_id()
    )
  );
drop policy if exists "patient reads own medication adherence" on public.medication_adherence;
create policy "patient reads own medication adherence" on public.medication_adherence
  for select to authenticated using (patient_id = public.current_patient_id());
drop policy if exists "clinical staff read medication adherence" on public.medication_adherence;
create policy "clinical staff read medication adherence" on public.medication_adherence
  for select to authenticated using (
    public.current_app_role() in ('admin_manager','matron','nurse')
    or (public.current_app_role() = 'doctor' and public.doctor_has_patient_access(patient_id))
  );

drop policy if exists "pharmacy manages supplier requests" on public.supplier_requests;
create policy "pharmacy manages supplier requests" on public.supplier_requests
  for all to authenticated
  using (public.current_app_role() = 'pharmacy' or public.is_admin())
  with check (
    (public.current_app_role() = 'pharmacy' and requested_by = auth.uid())
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- 4. Private storage access paths.
-- ---------------------------------------------------------------------------
insert into storage.buckets(id, name, public) values
  ('lab-external-results', 'lab-external-results', false),
  ('consent-forms', 'consent-forms', false),
  ('clinic-assets', 'clinic-assets', true)
on conflict (id) do nothing;
update storage.buckets
set file_size_limit=10485760,
    allowed_mime_types=array['application/pdf','image/jpeg','image/png','image/webp']
where id in ('lab-external-results','payment-proofs','consent-forms');

update storage.buckets
set file_size_limit=2097152,
    allowed_mime_types=array['image/jpeg','image/png','image/webp']
where id = 'clinic-assets';

drop policy if exists "admin manages clinic assets" on storage.objects;
create policy "admin manages clinic assets" on storage.objects for all to authenticated
  using (bucket_id = 'clinic-assets' and public.is_admin())
  with check (bucket_id = 'clinic-assets' and public.is_admin());

drop policy if exists "chief embryologist manages lab result uploads" on storage.objects;
drop policy if exists "lab staff manage lab result uploads" on storage.objects;
create policy "lab staff manage lab result uploads" on storage.objects for all to authenticated
  using (bucket_id = 'lab-external-results' and public.current_app_role() in ('chief_embryologist','lab_tech'))
  with check (bucket_id = 'lab-external-results' and public.current_app_role() in ('chief_embryologist','lab_tech'));
drop policy if exists "patient reads own external lab results" on storage.objects;
create policy "patient reads own external lab results" on storage.objects for select to authenticated
  using (bucket_id = 'lab-external-results' and (storage.foldername(name))[1] = public.current_patient_id());
drop policy if exists "doctor reads assigned external lab results" on storage.objects;
create policy "doctor reads assigned external lab results" on storage.objects for select to authenticated
  using (bucket_id = 'lab-external-results' and public.current_app_role() = 'doctor' and public.doctor_has_patient_access((storage.foldername(name))[1]));
drop policy if exists "matron reads external lab results" on storage.objects;
create policy "matron reads external lab results" on storage.objects for select to authenticated
  using (bucket_id = 'lab-external-results' and public.current_app_role() = 'matron');


commit;
