-- ============================================================================
-- Phenry Health — Stakeholder role migration
--
-- Stakeholder needs no new grants: the four exec_overview/exec_financials/
-- exec_operations/exec_growth() functions (built during Admin, per spec
-- §0.3) already allow 'stakeholder' in their role check, and none of them
-- ever touch patient_names/bio_details or any patient-identifying column —
-- that's the actual "architecturally impossible" guarantee, not just an RLS
-- policy that happens to be absent.
--
-- What this migration DOES do is close two pre-existing blanket
-- `to authenticated using (true)` policies that would otherwise have handed
-- Stakeholder more than spec §2.2 allows, if they queried the tables
-- directly instead of going through the app's UI:
--   - clinic_settings: spec's matrix gives Stakeholder "none" (every other
--     role gets at least "read") — the blanket policy from the Patient
--     migration didn't carve that out because Stakeholder didn't exist yet.
--   - recovery_beds: not patient identity itself, but
--     occupied_by_patient_id is a real patient_id FK — direct access to
--     that column is exactly the kind of thing "architecturally
--     impossible to see patient PII" is supposed to rule out, even though
--     no current Stakeholder screen queries this table.
-- Audited every other blanket policy in the schema (custom_roles,
-- lab_templates, the auth-hook's profiles policy) — none expose anything
-- patient-identifying, so those are left as-is.
-- ============================================================================

drop policy "any authenticated user reads clinic_settings" on public.clinic_settings;
create policy "authenticated non-stakeholders read clinic_settings"
  on public.clinic_settings for select to authenticated
  using (public.current_app_role() <> 'stakeholder');

drop policy "any authenticated user reads recovery_beds" on public.recovery_beds;
create policy "authenticated non-stakeholders read recovery_beds"
  on public.recovery_beds for select to authenticated
  using (public.current_app_role() <> 'stakeholder');
