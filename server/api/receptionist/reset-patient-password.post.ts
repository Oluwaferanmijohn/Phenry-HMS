import { createClient } from '@supabase/supabase-js'
import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import { generateTemporaryPassword } from '~/server/utils/temporaryPassword'

export default defineEventHandler(async (event) => {
  const body = await readBody<{ patientId: string }>(event)
  const patientId = body?.patientId?.trim()
  if (!patientId) throw createError({ statusCode: 400, statusMessage: 'patientId is required' })

  const userClient = await serverSupabaseClient(event)
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })

  const { data: callerProfile } = await userClient
    .from('profiles')
    .select('role, full_name, active')
    .eq('id', caller.id)
    .single()
  if (!callerProfile?.active || !['receptionist', 'admin_manager'].includes(callerProfile.role)) {
    throw createError({ statusCode: 403, statusMessage: 'Only Reception or Admin Manager can reset a patient password' })
  }

  const config = useRuntimeConfig()
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 500, statusMessage: 'Server account provisioning is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: patient } = await admin.from('patient_names').select('patient_id, full_name').eq('patient_id', patientId).maybeSingle()
  if (!patient) throw createError({ statusCode: 404, statusMessage: 'Patient not found' })

  const { data: portalProfile } = await admin
    .from('profiles')
    .select('id, active, force_password_reset')
    .eq('patient_id', patientId)
    .eq('role', 'patient')
    .maybeSingle()
  if (!portalProfile) throw createError({ statusCode: 404, statusMessage: 'This patient does not have a portal login yet' })
  if (!portalProfile.active) throw createError({ statusCode: 409, statusMessage: 'This patient portal account is inactive. Ask Admin Manager to reactivate it.' })

  const { data: authUser, error: authLookupError } = await admin.auth.admin.getUserById(portalProfile.id)
  if (authLookupError || !authUser.user) throw createError({ statusCode: 404, statusMessage: 'Patient authentication account was not found' })

  const temporaryPassword = generateTemporaryPassword()
  const { error: profileFlagError } = await admin.from('profiles').update({ force_password_reset: true }).eq('id', portalProfile.id)
  if (profileFlagError) throw createError({ statusCode: 500, statusMessage: 'Could not prepare the patient account for a mandatory password change' })

  const { error: updateError } = await admin.auth.admin.updateUserById(portalProfile.id, {
    password: temporaryPassword,
    user_metadata: {
      ...(authUser.user.user_metadata || {}),
      full_name: patient.full_name,
      role: 'patient',
      patient_id: patient.patient_id,
      force_password_reset: true,
    },
  })
  if (updateError) {
    await admin.from('profiles').update({ force_password_reset: portalProfile.force_password_reset }).eq('id', portalProfile.id)
    throw createError({ statusCode: 500, statusMessage: updateError.message || 'Could not reset the patient password' })
  }

  await admin.from('audit_log').insert({
    actor_id: caller.id,
    staff_name: callerProfile.full_name || caller.email || 'Reception',
    role: callerProfile.role,
    action_type: 'Reset Patient Portal Password',
    target: patient.patient_id,
  })

  return { patientId: patient.patient_id, patientName: patient.full_name, temporaryPassword }
})
