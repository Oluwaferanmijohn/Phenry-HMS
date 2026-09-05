import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = path => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('global dashboard search uses one role-aware and patient-scoped RPC', async () => {
  const [topbar, migration] = await Promise.all([
    read('components/layout/Topbar.vue'),
    read('supabase/migrations/20260905180000_role_aware_global_patient_search.sql'),
  ])
  assert.match(topbar, /global_patient_search/)
  assert.match(topbar, /searchError/)
  assert.match(migration, /security definer/)
  assert.match(migration, /doctor_has_patient_access/)
  assert.match(migration, /nurse_has_patient_access/)
  assert.match(migration, /limit 12/)
})

test('payment proof upload policies support patient IDs containing slashes', async () => {
  const [payments, migration] = await Promise.all([
    read('pages/patient/payments.vue'),
    read('supabase/migrations/20260905170000_payment_proof_paths_with_slash_mrns.sql'),
  ])
  assert.match(payments, /contentType: chosenFile\.value\.type/)
  assert.match(payments, /slash-safe policy migration/)
  assert.match(migration, /left\(name, length\(public\.current_patient_id\(\)\) \+ 1\)/)
  assert.match(migration, /public\.current_patient_id\(\) \|\| '\/'/)
  assert.match(migration, /patient uploads proof into their own folder/)
  assert.match(migration, /patient reads their own uploaded proofs/)
})
