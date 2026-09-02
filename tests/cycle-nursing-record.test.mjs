import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('blank cycle days satisfy the non-null phase contract without generating a protocol', async () => {
  const [protocol, chart, migration] = await Promise.all([
    read('composables/useIvfProtocol.ts'),
    read('components/shared/CycleDayChart.vue'),
    read('supabase/migrations/20260902070000_cycle_and_nursing_record.sql'),
  ])

  assert.match(protocol, /phase: ''/)
  assert.doesNotMatch(protocol, /phase: null/)
  assert.match(chart, /phase: String\(row\.phase \|\| ''\)\.trim\(\)/)
  assert.match(migration, /alter column phase set default ''/)
  assert.match(migration, /alter column phase set not null/)
  assert.match(migration, /c\.cycle_manager_id = auth\.uid\(\)/)
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
