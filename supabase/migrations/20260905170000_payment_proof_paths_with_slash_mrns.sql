-- Patient IDs may contain slashes (for example TESTING/20260901/001).
-- Match the complete patient-ID path prefix instead of only folder one.
begin;
drop policy if exists "patient uploads own payment proofs" on storage.objects;
drop policy if exists "patient uploads proof into their own folder" on storage.objects;
create policy "patient uploads own payment proofs" on storage.objects for insert to authenticated
with check (
  bucket_id = 'payment-proofs'
  and public.current_app_role() = 'patient'
  and public.current_patient_id() is not null
  and left(name, length(public.current_patient_id()) + 1) = public.current_patient_id() || '/'
);
drop policy if exists "patient reads own payment proofs" on storage.objects;
drop policy if exists "patient reads their own uploaded proofs" on storage.objects;
create policy "patient reads own payment proofs" on storage.objects for select to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.current_app_role() = 'patient'
  and public.current_patient_id() is not null
  and left(name, length(public.current_patient_id()) + 1) = public.current_patient_id() || '/'
);
drop policy if exists "patient removes own failed payment proofs" on storage.objects;
create policy "patient removes own failed payment proofs" on storage.objects for delete to authenticated
using (
  bucket_id = 'payment-proofs'
  and public.current_app_role() = 'patient'
  and public.current_patient_id() is not null
  and left(name, length(public.current_patient_id()) + 1) = public.current_patient_id() || '/'
);
commit;
select jsonb_pretty(jsonb_build_object(
  'slash_safe_upload_policy', exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='patient uploads own payment proofs'),
  'slash_safe_read_policy', exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='patient reads own payment proofs'),
  'failed_upload_cleanup_policy', exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='patient removes own failed payment proofs')
)) as payment_proof_policy_verification;
