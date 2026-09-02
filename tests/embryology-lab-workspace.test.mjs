import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('embryo grading begins at Day 0 and uses a focused culture-day workspace', async () => {
  const component = await read('components/shared/EmbryoGradingPage.vue')

  assert.match(component, /key: 'day0'/)
  assert.match(component, /MII \(Mature\)/)
  assert.match(component, /activeDayKey/)
  assert.match(component, /classified count must equal the cohort total/)
  assert.match(component, /Day 0 grading needs the latest database migration/)
  assert.doesNotMatch(component, /v-for="d in DAY_DEFS" :key="d\.key" class="card card-pad"/)
})

test('fertility laboratory starter templates are seeded and recoverable from the UI', async () => {
  const [migration, manager, starterLibrary] = await Promise.all([
    read('supabase/migrations/20260902060000_embryology_lab_workspace.sql'),
    read('components/shared/LabTemplateManager.vue'),
    read('utils/labStarterTemplates.ts'),
  ])

  assert.match(migration, /'day0', 'day1', 'day2', 'day3', 'day5'/)
  assert.match(migration, /SFA \(Semen Fluid Analysis\)/)
  assert.match(migration, /Hormonal Panel \(FSH, LH, E2\)/)
  assert.match(migration, /IVF Cycle Monitoring Panel/)
  assert.match(migration, /Pregnancy Test \(Quantitative β-hCG\)/)
  assert.match(migration, /Pre-IVF Infectious Disease Screening/)
  assert.match(migration, /Ovarian Reserve Screening/)
  assert.match(migration, /locally validated reference intervals/i)
  assert.match(manager, /Restore Starter Templates/)
  assert.match(manager, /installStarterTemplates\(true\)/)
  assert.match(starterLibrary, /SFA \(Semen Fluid Analysis\)/)
  assert.match(starterLibrary, /Blood Group & Full Blood Count/)
})

test('lab staff can document equipment, supplies, and kits outside pharmacy', async () => {
  const [component, migration, roleMeta, labPage] = await Promise.all([
    read('components/shared/LabOperationsPage.vue'),
    read('supabase/migrations/20260902060000_embryology_lab_workspace.sql'),
    read('composables/useRoleMeta.ts'),
    read('pages/lab_tech/qc.vue'),
  ])

  assert.match(component, /Add equipment/)
  assert.match(component, /Add store item/)
  assert.match(component, /Lot \/ batch number/)
  assert.match(component, /Culture Media/)
  assert.match(migration, /lab tech manages lab_equipment/)
  assert.match(migration, /lab tech manages lab_store/)
  assert.match(roleMeta, /id: 'qc', label: 'Equipment, QC & Supplies'/)
  assert.match(labPage, /LabOperationsPage role="lab_tech"/)
})

test('live schema alignment activates embryo RLS and preserves role-scoped access', async () => {
  const repair = await read('supabase/migrations/20260902080000_live_schema_alignment.sql')

  assert.match(repair, /embryo_batches enable row level security/)
  assert.match(repair, /revoke all privileges on table public\.embryo_batches from anon/)
  assert.match(repair, /doctor_has_patient_access\(patient_id\)/)
  assert.match(repair, /nurse_has_patient_access\(patient_id\)/)
  assert.match(repair, /mrn_sequences enable row level security/)
  assert.match(repair, /drop trigger if exists cycles_enforce_cycle_manager/)
})
