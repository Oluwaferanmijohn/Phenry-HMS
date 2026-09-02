-- ============================================================================
-- Phenry Health — remove stale two-argument custom-role policies
--
-- A partially applied legacy migration left duplicate SELECT policies named
-- "custom role views ...". They call custom_role_scope_ok(text,text), while
-- the reconciled policies call the corrected three-argument function. The
-- legacy helper was intentionally denied to authenticated users, so PostgreSQL
-- could raise 42501 while evaluating the stale policy even when a fixed-role
-- policy (Doctor, Matron, Chief Embryologist, Admin, etc.) also allowed access.
-- ============================================================================

begin;

drop policy if exists "custom role views appointments" on public.appointments;
drop policy if exists "custom role views bio_details" on public.bio_details;
drop policy if exists "custom role views consultations" on public.consultations;
drop policy if exists "custom role views cycles" on public.cycles;
drop policy if exists "custom role views lab_results" on public.lab_results;
drop policy if exists "custom role views patient_names" on public.patient_names;
drop policy if exists "custom role views payment_milestones" on public.payment_milestones;
drop policy if exists "custom role views payment_plans" on public.payment_plans;
drop policy if exists "custom role views prescriptions" on public.prescriptions;

-- No CASCADE: if an unexpected object still depends on this obsolete overload,
-- PostgreSQL must stop and report it instead of deleting unrelated security
-- objects. The transaction then rolls back cleanly.
drop function if exists public.custom_role_scope_ok(text, text);

-- Keep only the corrected overload available to signed-in users.
revoke all on function public.custom_role_scope_ok(text, text, uuid) from public, anon;
grant execute on function public.custom_role_scope_ok(text, text, uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
