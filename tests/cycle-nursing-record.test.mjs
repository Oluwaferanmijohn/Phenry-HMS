import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('standard cycle chart uses two understandable phases and the hospital Buserelin schedule', async () => {
  const [protocol, chart, migration, startCycle] = await Promise.all([
    read('composables/useIvfProtocol.ts'),
    read('components/shared/CycleDayChart.vue'),
    read('supabase/migrations/20260905200000_standard_buserelin_cycle_chart.sql'),
    read('components/shared/StartCycleModal.vue'),
  ])

  assert.match(protocol, /phase_key: 'other'/)
  assert.doesNotMatch(protocol, /phase: null/)
  assert.match(chart, /Down-Regulation Phase/)
  assert.match(chart, /Stimulation Phase/)
  assert.match(chart, /Day numbers restart when Stimulation begins/)
  assert.match(chart, /Print \/ Save PDF/)
  assert.doesNotMatch(chart, /Initialize Blank 14-Day Log/)
  assert.match(startCycle, /Standard Buserelin Protocol/)
  assert.match(migration, /for sequence_day in 1\.\.32 loop/)
  assert.match(migration, /when sequence_day between 1 and 14 then 'OCP'/)
  assert.match(migration, /when 20 then 'Scan 1'/)
  assert.match(migration, /when 32 then 'Egg Collection'/)
})

test('Doctor, Matron, and Nurse share cycle management while Patient remains read-only', async () => {
  const [migration, nursePage, macro, consultation, patient, detail] = await Promise.all([
    read('supabase/migrations/20260905200000_standard_buserelin_cycle_chart.sql'),
    read('pages/nurse/cycles.vue'),
    read('components/shared/MacroCycleView.vue'),
    read('components/shared/ConsultationPage.vue'),
    read('pages/patient/treatment.vue'),
    read('components/shared/CycleDetailModal.vue'),
  ])
  assert.match(migration, /nurse manages accessible cycles/)
  assert.match(migration, /caller_role not in \('doctor', 'matron', 'nurse'\)/)
  assert.match(nursePage, /:allow-create="true"/)
  assert.match(macro, /\['matron', 'nurse', 'doctor'\]\.includes\(role\)/)
  assert.match(consultation, /:can-edit="true"/)
  assert.match(patient, /:can-edit="false"/)
  assert.match(detail, /\['doctor', 'matron', 'nurse'\]\.includes/)
})

test('cycle changes are attributed, audited, and printable with hospital identity', async () => {
  const [migration, chart] = await Promise.all([
    read('supabase/migrations/20260905200000_standard_buserelin_cycle_chart.sql'),
    read('components/shared/CycleDayChart.vue'),
  ])
  for (const column of ['action_status', 'actual_medication', 'administered_by', 'administered_at', 'updated_by', 'change_reason']) assert.match(migration, new RegExp(column))
  assert.match(migration, /cycle_daily_log_audit/)
  assert.match(chart, /clinic_settings/)
  assert.match(chart, /cycle-chart-printing/)
  assert.match(chart, /Reason for changing the plan \(required\)/)
  assert.match(chart, /Mark Given/)
})

test('cycle plans can be saved once and safely reused for another patient', async () => {
  const [migration, chart, startCycle, modal, css] = await Promise.all([
    read('supabase/migrations/20260905210000_reusable_cycle_templates.sql'),
    read('components/shared/CycleDayChart.vue'),
    read('components/shared/StartCycleModal.vue'),
    read('components/ui/Modal.vue'),
    read('assets/css/main.css'),
  ])

  assert.match(migration, /create table if not exists public\.cycle_templates/)
  assert.match(migration, /save_cycle_as_template/)
  assert.match(migration, /apply_cycle_template/)
  assert.match(migration, /start_fertility_cycle\(\s*p_patient_id text,[\s\S]*p_template_id uuid/)
  assert.match(migration, /'medication', medication/)
  assert.doesNotMatch(migration, /'actual_medication', actual_medication/)
  assert.doesNotMatch(migration, /'note', note/)
  assert.match(chart, /Save as Template/)
  assert.match(chart, /administration records, signatures and clinical notes are excluded/)
  assert.match(startCycle, /Reusable Cycle Template/)
  assert.match(startCycle, /p_template_id: templateId\.value \|\| null/)
  assert.match(modal, /workspace\?: boolean/)
  assert.match(css, /\.modal\.workspace/)
  assert.match(chart, /data-label="Administration & Signature"/)
})

test('queued writes do not assume every table has an id column', async () => {
  const queue = await read('composables/useSyncQueue.ts')

  assert.match(queue, /const returnColumn = Object\.keys\(op\.match\)\[0\] \|\| '\*'/)
  assert.doesNotMatch(queue, /query\.select\('id'\)/)
})

test('nurse vitals and visit documentation remain visible and patient-linked', async () => {
  const [vitals, visit, modal, migration, nav] = await Promise.all([
    read('pages/nurse/vitals.vue'),
    read('pages/nurse/visit.vue'),
    read('components/shared/PatientDetailModal.vue'),
    read('supabase/migrations/20260902070000_cycle_and_nursing_record.sql'),
    read('composables/useRoleMeta.ts'),
  ])

  assert.match(vitals, /Respiratory rate/)
  assert.match(vitals, /Pain score/)
  assert.match(vitals, /Reproductive intake/)
  assert.match(vitals, /maleFertilityHistory/)
  assert.match(visit, /No accessible patient selected/)
  assert.match(visit, /nurse-visit-init-\$\{profile\.value\?\.id/)
  assert.match(modal, /Nursing Vitals &amp; Intake/)
  assert.match(modal, /registration-strip/)
  assert.match(migration, /reproductive_intake jsonb/)
  assert.match(migration, /medical_intake jsonb/)
  assert.match(nav, /id: 'vitals', label: 'Patient Vitals'/)
})

test('front desk patient popup can read the complete registration profile', async () => {
  const [page, migration] = await Promise.all([
    read('pages/receptionist/patients.vue'),
    read('supabase/migrations/20260902070000_cycle_and_nursing_record.sql'),
  ])

  assert.match(page, /patient_front_desk_profile_v2/)
  assert.match(page, /REFERRAL SOURCE/)
  assert.match(migration, /patient_front_desk_profile_v2/)
  assert.match(migration, /record_registration_consent/)
})

test('live alignment contains every column and RPC required by the new nursing UI', async () => {
  const repair = await read('supabase/migrations/20260902080000_live_schema_alignment.sql')

  for (const column of ['respiratory_rate_bpm', 'pain_score', 'waist_cm', 'blood_glucose_mmol_l', 'visit_type', 'chief_complaint', 'reproductive_intake', 'medical_intake', 'registration_consent_at']) {
    assert.match(repair, new RegExp(`add column if not exists ${column}`))
  }
  assert.match(repair, /patient_front_desk_profile_v2/)
  assert.match(repair, /record_registration_consent/)
  assert.match(repair, /alignment_verification/)
})
