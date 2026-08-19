-- ============================================================================
-- Storage: proof-of-payment uploads (Patient Payments page → openUploadProof
-- / submitProof in the prototype). Private bucket, path convention
-- {patient_id}/{milestone_id}/{filename} — patients can only read/write
-- inside their own patient_id folder. Admin's Financial Approvals page
-- (built later) gets read access added in that role's migration.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('payment-proofs', 'payment-proofs', false)
on conflict (id) do nothing;

create policy "patient uploads proof into their own folder"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = public.current_patient_id());

create policy "patient reads their own uploaded proofs"
  on storage.objects for select to authenticated
  using (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = public.current_patient_id());
