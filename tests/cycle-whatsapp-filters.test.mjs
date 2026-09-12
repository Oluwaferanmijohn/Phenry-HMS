import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(path, 'utf8')

test('patient fertility chart is collapsed until explicitly opened', async () => {
  const modal = await read('components/shared/PatientDetailModal.vue')
  assert.match(modal, /<details v-if="cycle" class="cycle-disclosure">/)
  assert.doesNotMatch(modal, /<details[^>]+\sopen(?:\s|>)/)
})

test('a cycle supports multiple assigned nurses and preserves administration signatures', async () => {
  const [modal, chart, migration] = await Promise.all([
    read('components/shared/CycleDetailModal.vue'),
    read('components/shared/CycleDayChart.vue'),
    read('supabase/migrations/20260912090000_cycle_team_whatsapp_and_patient_filters.sql'),
  ])
  assert.match(modal, /v-model="selectedNurseIds"/)
  assert.match(modal, /set_cycle_nursing_team/)
  assert.match(chart, /administered_by/)
  assert.match(chart, /administered_at/)
  assert.match(migration, /cycle_nurse_assignments/)
  assert.match(migration, /nurse_has_patient_access/)
})

test('WhatsApp reminders require opt-in and the Baileys worker has no database admin key', async () => {
  const [migration, worker, dueApi, registration] = await Promise.all([
    read('supabase/migrations/20260912090000_cycle_team_whatsapp_and_patient_filters.sql'),
    read('scripts/whatsapp-baileys-worker.mjs'),
    read('server/api/internal/whatsapp/due.get.ts'),
    read('pages/receptionist/register.vue'),
  ])
  assert.match(migration, /whatsapp_opt_in/)
  assert.match(migration, /cycle_daily_logs_queue_whatsapp/)
  assert.match(worker, /@whiskeysockets\/baileys/)
  assert.doesNotMatch(worker, /SUPABASE_SERVICE_ROLE_KEY/)
  assert.match(dueApi, /eq\('trigger_type', 'cycle_reminder'\)/)
  assert.match(registration, /whatsappOptIn/)
})

test('patient pages and global search share relative-date and patient-type filters', async () => {
  const [page, topbar, finder, migration] = await Promise.all([
    read('components/shared/PatientsSearchPage.vue'),
    read('components/layout/Topbar.vue'),
    read('components/shared/ClinicalPatientFinder.vue'),
    read('supabase/migrations/20260912090000_cycle_team_whatsapp_and_patient_filters.sql'),
  ])
  for (const source of [page, topbar, finder]) {
    assert.match(source, /yesterday/)
    assert.match(source, /last_week/)
    assert.match(source, /walk_in/)
    assert.match(source, /appointment/)
  }
  assert.match(migration, /clinical_patient_search_v2/)
  assert.match(migration, /global_patient_search_v2/)
})
