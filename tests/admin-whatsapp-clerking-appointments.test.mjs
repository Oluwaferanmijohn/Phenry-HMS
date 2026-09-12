import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(path, 'utf8')

test('WhatsApp pairing is administrator-only and published by the worker', async () => {
  const [card, page, endpoint, workerEndpoint, worker, migration, nav] = await Promise.all([
    read('components/admin/WhatsAppGatewayCard.vue'),
    read('pages/admin_manager/whatsapp.vue'),
    read('server/api/admin/whatsapp-status.get.ts'),
    read('server/api/internal/whatsapp/status.post.ts'),
    read('scripts/whatsapp-baileys-worker.mjs'),
    read('supabase/migrations/20260912100000_admin_whatsapp_gateway.sql'),
    read('composables/useRoleMeta.ts'),
  ])
  assert.match(card, /qrDataUrl/)
  assert.match(page, /WhatsAppGatewayCard/)
  assert.match(endpoint, /profile\?\.role !== 'admin_manager'/)
  assert.match(workerEndpoint, /assertWhatsappWorker/)
  assert.match(worker, /publishStatus\('pairing', qr\)/)
  assert.match(worker, /loadEnvFile\(\)/)
  assert.match(worker, /waitForApp\(\)/)
  assert.match(worker, /http:\/\/localhost:3027/)
  assert.match(worker, /http:\/\/\[::1\]:3027/)
  assert.doesNotMatch(worker, /qrcode-terminal/)
  assert.match(migration, /enable row level security/)
  assert.match(migration, /public\.is_admin\(\)/)
  assert.match(migration, /public\.appointments a where a\.patient_id=p_patient_id/)
  assert.match(migration, /public\.walk_in_encounters wi where wi\.patient_id=p_patient_id/)
  assert.match(nav, /WhatsApp Setup/)
})

test('shared patient details include initial clerking without blank answers', async () => {
  const modal = await read('components/shared/PatientDetailModal.vue')
  assert.match(modal, /patient_initial_assessments/)
  assert.match(modal, /Initial Clerking/)
  assert.match(modal, /historyItems/)
  assert.match(modal, /assessment\.assessed_by/)
  assert.match(modal, /String\(value\)\.trim\(\) !== ''/)
})

test('nurse and matron landing pages show appointments and nurse exposes walk-in registration', async () => {
  const [queue, nurse, matron, finder, clerking] = await Promise.all([
    read('components/shared/TodayAppointmentsCard.vue'),
    read('pages/nurse/overview.vue'),
    read('pages/matron/overview.vue'),
    read('components/shared/ClinicalPatientFinder.vue'),
    read('components/shared/InitialClerkingPage.vue'),
  ])
  assert.match(queue, /from\('appointments'\)/)
  assert.match(queue, /eq\('date', today\)/)
  assert.match(nurse, /TodayAppointmentsCard role="nurse"/)
  assert.match(matron, /TodayAppointmentsCard role="matron"/)
  assert.match(nurse, /Register walk-in/)
  assert.match(finder, /initialWalkInOpen/)
  assert.match(clerking, /route\.query\.walkIn === '1'/)
})
