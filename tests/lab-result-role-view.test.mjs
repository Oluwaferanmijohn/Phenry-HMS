import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('lab result entry stores only parameters with entered values', async () => {
  const page = await read('components/shared/LabResultsEntryPage.vue')

  assert.match(page, /template\.value\.variables\.flatMap/)
  assert.match(page, /if \(!enteredValue\) return \[\]/)
  assert.match(page, /Enter at least one result value before saving/)
  assert.doesNotMatch(page, /values\.value\[i\] \|\| '—'/)
})

test('patient result history hides legacy blank placeholder rows', async () => {
  const modal = await read('components/shared/PatientDetailModal.vue')

  assert.match(modal, /recordedResultRows\(r\)/)
  assert.match(modal, /normalized !== '' && normalized !== '—'/)
  assert.match(modal, /recordedResultRows\(result\)\.filter/)
})

test('nurse and lab technician share patient details with role-specific actions', async () => {
  const [patientsPage, labPatients, migration] = await Promise.all([
    read('components/shared/PatientsSearchPage.vue'),
    read('pages/lab_tech/patients.vue'),
    read('supabase/migrations/20260904100000_lab_results_and_role_patient_views.sql'),
  ])

  assert.match(labPatients, /<PatientsSearchPage/)
  assert.match(patientsPage, /nurse: \{ allowVitals: true, allowVisitDoc: true \}/)
  assert.match(patientsPage, /lab_tech: \{ allowLabEntry: true, allowExternalUpload: true \}/)
  assert.match(patientsPage, /patients_lab_directory/)
  assert.match(patientsPage, /external=1/)
  assert.match(migration, /jsonb_array_elements\(lr\.values\)/)
  assert.match(migration, /nurse_has_patient_access\(bd\.patient_id\)/)
})

test('staff and patients share one branded printable result with audited amendments', async () => {
  const [entryPage, patientPage, report, migration] = await Promise.all([
    read('components/shared/LabResultsEntryPage.vue'),
    read('pages/patient/results.vue'),
    read('components/shared/LabResultReportModal.vue'),
    read('supabase/migrations/20260904130000_lab_result_reports_and_amendments.sql'),
  ])

  assert.match(entryPage, /LabResultReportModal/)
  assert.match(entryPage, /Reason for Amendment/)
  assert.match(entryPage, /amended_by_profile_id/)
  assert.match(entryPage, /expectedUpdatedAt/)
  assert.match(patientPage, /LabResultReportModal/)
  assert.match(patientPage, /View \/ Print/)
  assert.match(report, /clinicAddress/)
  assert.match(report, /result\.entered_by_name/)
  assert.match(report, /Print \/ Save PDF/)
  assert.match(report, /body\.lab-result-printing/)
  assert.match(migration, /lab_result_report_context/)
  assert.match(migration, /caller_role = 'patient'/)
  assert.match(migration, /amendment_reason/)
})
