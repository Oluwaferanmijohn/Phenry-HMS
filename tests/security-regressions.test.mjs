import assert from 'node:assert/strict'
import { readFile, access } from 'node:fs/promises'
import { test } from 'node:test'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('account provisioning does not use Math.random or surname passwords', async () => {
  const staff = await read('server/api/admin/create-staff.post.ts')
  const patient = await read('server/api/receptionist/create-patient-account.post.ts')
  assert.doesNotMatch(staff, /Math\.random/)
  assert.doesNotMatch(patient, /surname\s+exactly|password:\s*patientRow\.surname/)
  assert.match(staff, /generateTemporaryPassword/)
  assert.match(patient, /generateTemporaryPassword/)
})

test('reconciliation migration removes profile escalation and adds guarded paths', async () => {
  const sql = await read('supabase/migrations/00000000000018_reconciliation_security.sql')
  assert.match(sql, /drop policy if exists "users can update their own force_password_reset \+ name fields"/)
  assert.match(sql, /admin_manage_staff/)
  assert.match(sql, /complete_password_reset/)
  assert.match(sql, /prevent_appointment_overlap/)
  assert.match(sql, /custom_role_scope_ok\('patient_names',patient_id,null::uuid\)/)
  assert.doesNotMatch(sql, /p_patient_id text default null/)
  assert.match(sql, /use_cryo_record\(p_record_id uuid, p_straws_used int default 1\)/)
  assert.doesNotMatch(sql, /app\.settings\.service_role_key/)
})

test('offline persistence is encrypted and required workflow files exist', async () => {
  const offline = await read('composables/useOfflineDb.ts')
  assert.match(offline, /AES-GCM/)
  assert.match(offline, /ownerUserId/)
  assert.match(offline, /Version 2 intentionally destroys the old plaintext stores/)
  await access(new URL('../components/shared/CycleDayChart.vue', import.meta.url))
  await access(new URL('../plugins/session-guard.client.ts', import.meta.url))
  await access(new URL('../supabase/functions/notify-emergency-broadcast/index.ts', import.meta.url))
})

test('unused sync/mobile packages are not shipped', async () => {
  const pkg = JSON.parse(await read('package.json'))
  assert.equal(pkg.dependencies['@powersync/web'], undefined)
  assert.equal(pkg.devDependencies['@capacitor/core'], undefined)
})

test('financial, pharmacy, and nurse dashboard regressions stay closed', async () => {
  const sql = await read('supabase/migrations/00000000000018_reconciliation_security.sql')
  const nurse = await read('pages/nurse/overview.vue')
  const settings = await read('pages/admin_manager/settings.vue')
  assert.match(sql, /set status = 'Denied \/ Out of Stock'/)
  assert.match(sql, /submitted or approved payments cannot be replaced/)
  assert.match(sql, /create table if not exists public\.nursing_tasks/)
  assert.match(nurse, /table: 'nurse_visits'/)
  assert.match(nurse, /table: 'nursing_tasks'/)
  assert.match(settings, /storage\.from\('clinic-assets'\)\.upload/)
})

test('clinical patient loaders return user-scoped fresh data instead of cached side effects', async () => {
  const patients = await read('components/shared/PatientsSearchPage.vue')
  const consultation = await read('components/shared/ConsultationPage.vue')
  const investigations = await read('pages/doctor/investigations.vue')
  const billing = await read('pages/doctor/billing.vue')
  const access = await read('composables/useClinicalPatientAccess.ts')

  assert.doesNotMatch(patients, /useAsyncData\('shared-patients-list'/)
  assert.doesNotMatch(investigations, /useAsyncData\('doctor-investigations-init'/)
  assert.doesNotMatch(billing, /useAsyncData\('doctor-billing-init'/)
  for (const source of [patients, consultation, investigations, billing]) {
    assert.match(source, /profile\.value\?\.id/)
    assert.match(source, /getCachedData:\s*\(key, nuxtApp\)\s*=>\s*nuxtApp\.isHydrating/)
    assert.match(source, /fetchClinicalPatientDirectory/)
  }
  assert.match(consultation, /fetchClinicalPatientContext/)
  assert.match(investigations, /fetchClinicalPatientContext/)
  assert.match(patients, /fetchClinicalPatientContext/)
  assert.match(access, /rpc\('clinical_patient_directory'\)/)
  assert.match(access, /rpc\('clinical_patient_context'/)
  assert.match(access, /if \(error\) throw error/g)
  assert.match(consultation, /No accessible patients/)
  assert.match(investigations, /Investigation data could not be loaded/)
  assert.match(billing, /Payment-plan data could not be loaded/)
  assert.match(billing, /Installments must add up exactly/)
})

test('clinical REST repair keeps RLS as the boundary and restores Doctor helpers', async () => {
  const sql = await read('supabase/migrations/00000000000019_clinical_rest_access_repair.sql')
  assert.match(sql, /Refusing clinical grant: public\.% is missing or RLS is disabled/)
  assert.match(sql, /grant select on table[\s\S]*public\.cycles[\s\S]*to authenticated;/)
  assert.match(sql, /doctor_has_assigned_patient_access/)
  assert.match(sql, /doctor_has_assigned_cycle_access/)
  assert.match(sql, /public\.current_app_role\(\) = 'doctor'/)
  assert.match(sql, /revoke all on function public\.doctor_has_patient_access\(text\) from public, anon/)
  assert.doesNotMatch(sql, /grant all on/)
})

test('legacy two-argument custom-role policies cannot break fixed-role reads', async () => {
  const sql = await read('supabase/migrations/00000000000020_remove_legacy_custom_role_policies.sql')
  const syncPill = await read('components/layout/SyncPill.vue')
  const affectedTables = [
    'appointments',
    'bio_details',
    'consultations',
    'cycles',
    'lab_results',
    'patient_names',
    'payment_milestones',
    'payment_plans',
    'prescriptions',
  ]

  for (const table of affectedTables) {
    assert.match(sql, new RegExp(`drop policy if exists "custom role views ${table}" on public\\.${table}`))
  }
  assert.match(sql, /drop function if exists public\.custom_role_scope_ok\(text, text\);/)
  assert.doesNotMatch(sql, /drop function[^;]*cascade/i)
  assert.match(sql, /grant execute on function public\.custom_role_scope_ok\(text, text, uuid\) to authenticated/)
  assert.match(syncPill, /mounted\.value && online\.value/)
  assert.match(syncPill, /onMounted\(\(\) => \{ mounted\.value = true \}\)/)
})

test('clinical patient read API is explicit, scoped, and not a table-RLS bypass', async () => {
  const sql = await read('supabase/migrations/00000000000021_clinical_patient_access_api.sql')

  assert.match(sql, /create or replace function public\.clinical_patient_directory\(\)/)
  assert.match(sql, /create or replace function public\.clinical_patient_context\(p_patient_id text\)/)
  assert.match(sql, /security definer[\s\S]*set search_path = public, pg_temp/g)
  assert.match(sql, /caller_role in \('admin_manager', 'matron', 'chief_embryologist'\)/)
  assert.match(sql, /caller_role = 'doctor'[\s\S]*bd\.assigned_doctor_id = auth\.uid\(\)/)
  assert.match(sql, /a\.provider_profile_id = auth\.uid\(\)[\s\S]*a\.date = current_date[\s\S]*a\.status <> 'Cancelled'/)
  assert.match(sql, /caller_role = 'nurse' and bd\.assigned_doctor_id is not null/)
  assert.match(sql, /revoke all on function public\.clinical_patient_directory\(\) from public, anon/)
  assert.match(sql, /revoke all on function public\.clinical_patient_context\(text\) from public, anon/)
  assert.doesNotMatch(sql, /disable row level security/i)
  assert.doesNotMatch(sql, /grant all on/i)
})

test('women imaging workspace keeps templates structural and patient reports role-scoped', async () => {
  const sql = await read('supabase/migrations/00000000000022_womens_imaging_workspace.sql')
  const imaging = await read('pages/doctor/investigations.vue')
  const patientDetail = await read('components/shared/PatientDetailModal.vue')
  const access = await read('composables/useImagingWorkspace.ts')

  assert.match(sql, /create table public\.imaging_templates/)
  assert.match(sql, /create table public\.imaging_studies/)
  assert.match(sql, /create table public\.imaging_study_revisions/)
  assert.match(sql, /alter table public\.imaging_templates enable row level security/)
  assert.match(sql, /alter table public\.imaging_studies enable row level security/)
  assert.match(sql, /revoke all on table public\.imaging_studies from public, anon, authenticated/)
  assert.match(sql, /create or replace function public\.imaging_patient_access\(p_patient_id text, p_write boolean\)/)
  assert.match(sql, /public\.doctor_has_patient_access\(p_patient_id\)/)
  assert.match(sql, /status in \('Final', 'Amended'\)/)
  assert.match(sql, /an impression is required before a report can be finalized/)
  assert.match(sql, /an amendment reason is required/)
  assert.match(sql, /to_jsonb\(existing\), auth\.uid\(\), trim\(p_amendment_reason\)/)
  assert.match(sql, /field_row - array\['key', 'label', 'section', 'type', 'unit', 'options', 'required'\]/)
  assert.match(sql, /a template already used by a report cannot be edited/)
  assert.match(sql, /The clinician records the interpretation; the system does not infer viability/)
  assert.doesNotMatch(sql, /disable row level security/i)
  assert.doesNotMatch(sql, /grant all on/i)

  assert.match(imaging, /Women’s Imaging &amp; Ultrasound/)
  assert.match(imaging, /fetchClinicalPatientContext/)
  assert.match(imaging, /fetchImagingWorkspace/)
  assert.match(imaging, /saveImagingTemplate/)
  assert.match(imaging, /Save Draft/)
  assert.match(imaging, /Finalize Report/)
  assert.match(imaging, /does not calculate viability or O-RADS classification/)
  assert.match(patientDetail, /Imaging &amp; Ultrasound/)
  assert.match(patientDetail, /fetchImagingHistory/)
  assert.match(access, /rpc\('imaging_patient_history'/)
  assert.match(access, /rpc\('save_imaging_study'/)
})
