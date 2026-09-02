// POST /api/admin/create-staff
// Creates a real Supabase Auth user for a new staff member with a temporary
// password they must change on first login (same force_password_reset gate
// already built for patients) — per explicit direction in chat: "admin can
// create user... they get a temporary password that they change immediately
// on their first login."
//
// This has to be a server route, not a client-side Supabase call: creating
// an auth user with a set password requires the service-role key, which
// must never reach the browser. The caller's identity is re-verified here
// server-side (never trust a client-sent "I am an admin" claim).

import { createClient } from '@supabase/supabase-js'
import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import { generateTemporaryPassword } from '~/server/utils/temporaryPassword'

const FIXED_STAFF_ROLES = new Set(['receptionist', 'admin_manager', 'doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech', 'pharmacy', 'stakeholder'])

export default defineEventHandler(async (event) => {
  const body = await readBody<{ fullName: string; email: string; phone?: string; role?: string; customRoleKey?: string }>(event)
  const fullName = body?.fullName?.trim()
  const email = body?.email?.trim().toLowerCase()
  const phone = body?.phone?.trim() || null

  if (!fullName || fullName.length > 120 || !email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || (!body.role && !body.customRoleKey)) {
    throw createError({ statusCode: 400, statusMessage: 'fullName, email, and role (or customRoleKey) are required' })
  }
  if (body.role && !FIXED_STAFF_ROLES.has(body.role)) throw createError({ statusCode: 400, statusMessage: 'Invalid staff role' })

  // Verify the caller is actually an authenticated Admin — server-side,
  // using their own session, before we touch the service-role client.
  const userClient = await serverSupabaseClient(event)
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })

  const { data: callerProfile } = await userClient.from('profiles').select('role, full_name, active').eq('id', caller.id).single()
  if (callerProfile?.role !== 'admin_manager' || !callerProfile.active) {
    throw createError({ statusCode: 403, statusMessage: 'Only Admin Manager can create staff accounts' })
  }

  const config = useRuntimeConfig()
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 500, statusMessage: 'Server account provisioning is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  if (body.customRoleKey) {
    const { data: customRole } = await admin.from('custom_roles').select('role_key').eq('role_key', body.customRoleKey).maybeSingle()
    if (!customRole) throw createError({ statusCode: 400, statusMessage: 'Custom role does not exist' })
  }

  const tempPassword = generateTemporaryPassword()

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password: tempPassword,
    email_confirm: true,
    user_metadata: {
      full_name: fullName,
      role: body.role ?? null,
      custom_role_key: body.customRoleKey ?? null,
      force_password_reset: true,
    },
  })

  if (createErr || !created?.user) {
    const duplicate = createErr?.message?.toLowerCase().includes('already')
    throw createError({ statusCode: duplicate ? 409 : 500, statusMessage: createErr?.message || 'Could not create the staff account' })
  }

  const { error: profileError } = await admin.from('profiles').update({
    full_name: fullName,
    role: body.customRoleKey ? null : body.role,
    custom_role_key: body.customRoleKey || null,
    force_password_reset: true,
    active: true,
  }).eq('id', created.user.id)
  const { error: contactError } = await admin.from('staff_contacts').upsert({ profile_id: created.user.id, email, phone })
  if (profileError || contactError) {
    await admin.auth.admin.deleteUser(created.user.id)
    throw createError({ statusCode: 500, statusMessage: 'Account setup failed and was rolled back' })
  }

  await admin.from('audit_log').insert({
    actor_id: caller.id,
    staff_name: callerProfile?.full_name || caller.email || 'Admin',
    role: 'admin_manager',
    action_type: 'Created Staff Account',
    target: email,
  })

  return { userId: created.user.id, tempPassword }
})
