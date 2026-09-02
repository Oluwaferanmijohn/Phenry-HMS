// POST /api/receptionist/create-patient-account
// Creates the patient-portal Auth account register_new_patient() never did
// — patients had no way to log in at all until this exists. Called right
// after registration succeeds (see pages/receptionist/register.vue).
//
// Supabase Auth's password-based sign-in is fundamentally email-shaped —
// there's no "arbitrary username" mode — so "log in with Patient ID +
// surname" is implemented as a synthetic, non-deliverable email
// (`{patient_id}@patient.phenryhealth.internal`) built server-side and
// never shown to the patient; the login form (pages/patient-login.vue)
// only ever asks for Patient ID + password and translates to this email
// before calling signInWithPassword. A cryptographically random temporary
// password is returned once; force_password_reset makes them change it.
//
// Server route, not a client RPC, for the same reason create-staff.post.ts
// is: creating an Auth user requires the service-role key, which must
// never reach the browser.

import { createClient } from '@supabase/supabase-js'
import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import { generateTemporaryPassword } from '~/server/utils/temporaryPassword'

// Duplicated (not imported) from composables/usePatientAuth.ts on purpose —
// that file is written for the client bundle, and importing a composables/
// path into a Nitro server route isn't a pattern used anywhere else in this
// codebase, so this avoids relying on unverified cross-context resolution
// for something as consequential as account creation. If the login-email
// scheme ever changes, update both.
function patientLoginEmail(patientId: string): string {
  return `${patientId.trim().toLowerCase()}@patient.phenryhealth.internal`
}

export default defineEventHandler(async (event) => {
  const body = await readBody<{ patientId: string }>(event)
  if (!body?.patientId) {
    throw createError({ statusCode: 400, statusMessage: 'patientId is required' })
  }

  const userClient = await serverSupabaseClient(event)
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })

  const { data: callerProfile } = await userClient.from('profiles').select('role, active').eq('id', caller.id).single()
  if (!callerProfile?.active || !['receptionist', 'admin_manager'].includes(callerProfile.role)) {
    throw createError({ statusCode: 403, statusMessage: 'Only Reception or Admin Manager can create a patient portal login' })
  }

  const config = useRuntimeConfig()
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 500, statusMessage: 'Server account provisioning is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: patientRow, error: lookupErr } = await admin
    .from('patient_names')
    .select('patient_id, full_name, surname')
    .eq('patient_id', body.patientId)
    .single()
  if (lookupErr || !patientRow) {
    throw createError({ statusCode: 404, statusMessage: 'Patient not found' })
  }

  // Idempotent: registration and account creation are two calls (see
  // register.vue) — if this ever gets retried for the same patient, don't
  // create a duplicate account or hand back a second, different password.
  const { data: existing } = await admin.from('profiles').select('id').eq('patient_id', patientRow.patient_id).eq('role', 'patient').maybeSingle()
  if (existing) {
    return { alreadyExists: true, loginId: patientRow.patient_id }
  }

  const initialPassword = generateTemporaryPassword()

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email: patientLoginEmail(patientRow.patient_id),
    password: initialPassword,
    email_confirm: true,
    user_metadata: {
      full_name: patientRow.full_name,
      role: 'patient',
      patient_id: patientRow.patient_id,
      force_password_reset: true,
    },
  })

  if (createErr || !created?.user) {
    throw createError({ statusCode: 500, statusMessage: createErr?.message || 'Could not create the patient portal login' })
  }

  return { userId: created.user.id, loginId: patientRow.patient_id, tempPassword: initialPassword }
})
