import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'

const FIXED_STAFF_ROLES = new Set(['receptionist', 'admin_manager', 'doctor', 'visiting_doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech', 'pharmacy', 'stakeholder'])

export default defineEventHandler(async (event) => {
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })

  const body = await readBody<{
    profileId: string
    fullName: string
    phone?: string | null
    role?: string | null
    customRoleKey?: string | null
    active: boolean
  }>(event)
  const fullName = body?.fullName?.trim()
  if (!body?.profileId || !fullName || typeof body.active !== 'boolean') {
    throw createError({ statusCode: 400, statusMessage: 'profileId, fullName, and active are required' })
  }
  if ((body.role ? 1 : 0) + (body.customRoleKey ? 1 : 0) !== 1) {
    throw createError({ statusCode: 400, statusMessage: 'Choose exactly one fixed or custom role' })
  }
  if (body.role && !FIXED_STAFF_ROLES.has(body.role)) {
    throw createError({ statusCode: 400, statusMessage: 'Invalid staff role' })
  }

  const client = await serverSupabaseClient(event)
  const { data, error } = await client.rpc('admin_manage_staff', {
    p_profile_id: body.profileId,
    p_full_name: fullName,
    p_role: body.role || null,
    p_custom_role_key: body.customRoleKey || null,
    p_active: body.active,
    p_phone: body.phone?.trim() || null,
  })
  if (error) {
    const forbidden = error.message.includes('not authorized')
    throw createError({ statusCode: forbidden ? 403 : 400, statusMessage: error.message })
  }
  return { profile: data }
})
