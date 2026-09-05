import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = path => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('embryology procedure queue reads doctor and matron schedules and preserves legacy events', async () => {
  const [workspace, classifier, worklist, scheduleModal, surgery] = await Promise.all([
    read('components/shared/EmbryologyProcedureWorkspacePage.vue'),
    read('composables/useFertilityProcedures.ts'),
    read('components/shared/LabWorklistPage.vue'),
    read('components/shared/ScheduleProcedureModal.vue'),
    read('components/shared/SurgeryPage.vue'),
  ])
  assert.match(workspace, /from\('surgery_schedule'\)/)
  assert.match(workspace, /from\('transfer_cryo_schedule'\)/)
  assert.match(workspace, /Doctor and Matron procedure schedule/)
  assert.match(classifier, /isFertilityLabProcedure/)
  assert.match(classifier, /intrauterine insemination/i)
  assert.match(worklist, /clinicalScheduleRes/)
  for (const procedure of ['OPU / Oocyte Retrieval', 'IUI', 'Embryo Transfer', 'Oocyte Freezing', 'Sperm Freezing']) assert.match(scheduleModal, new RegExp(procedure.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  assert.match(surgery, /excludeFertilityProcedures/)
})

test('fertility reports and frozen specimen locations are structured and role secured', async () => {
  const [migration, report, cryo, grading, roleMeta] = await Promise.all([
    read('supabase/migrations/20260905160000_embryology_procedure_and_cryo_workspace.sql'),
    read('components/shared/FertilityProcedureReportModal.vue'),
    read('components/chief/CryoLogModal.vue'),
    read('components/shared/EmbryoGradingPage.vue'),
    read('composables/useRoleMeta.ts'),
  ])
  assert.match(migration, /fertility_procedure_reports/)
  assert.match(migration, /save_fertility_procedure_report/)
  assert.match(migration, /save_cryo_specimen/)
  assert.match(migration, /chief_embryologist', 'lab_tech/)
  for (const column of ['canister', 'rack', 'cane', 'goblet', 'position', 'container_label', 'source_procedure_id']) assert.match(migration, new RegExp(column))
  assert.match(report, /Oocyte retrieval record/)
  assert.match(report, /Embryo transfer record/)
  assert.match(report, /IUI preparation & insemination record/)
  assert.match(report, /Complete &amp; Sign/)
  assert.match(cryo, /Goblet \/ Jar/)
  assert.match(cryo, /Container \/ Specimen Label/)
  assert.match(grading, /Store Embryos/)
  assert.match(roleMeta, /Fertility Procedures & Cryostorage/)
  assert.match(roleMeta, /Other Surgery/)
})
