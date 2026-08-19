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

function generateTempPassword() {
  // 10 chars, alphanumeric, easy to read aloud/type — avoids ambiguous
  // characters (0/O, 1/l/I) since this gets communicated verbally or via
  // WhatsApp to a new hire.
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
  let out = ''
  for (let i = 0; i < 10; i++) out += chars[Math.floor(Math.random() * chars.length)]
  return out
}

export default defineEventHandler(async (event) => {
  const body = await readBody<{ fullName: string; email: string; role?: string; customRoleKey?: string }>(event)

  if (!body?.fullName || !body?.email || (!body.role && !body.customRoleKey)) {
    throw createError({ statusCode: 400, statusMessage: 'fullName, email, and role (or customRoleKey) are required' })
  }

  // Verify the caller is actually an authenticated Admin — server-side,
  // using their own session, before we touch the service-role client.
  const userClient = await serverSupabaseClient(event)
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })

  const { data: callerProfile } = await userClient.from('profiles').select('role, full_name').eq('id', caller.id).single()
  if (callerProfile?.role !== 'admin_manager') {
    throw createError({ statusCode: 403, statusMessage: 'Only Admin Manager can create staff accounts' })
  }

  const config = useRuntimeConfig()
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const tempPassword = generateTempPassword()

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email: body.email,
    password: tempPassword,
    email_confirm: true,
    user_metadata: {
      full_name: body.fullName,
      role: body.role ?? null,
      force_password_reset: true,
    },
  })

  if (createErr || !created?.user) {
    throw createError({ statusCode: 500, statusMessage: createErr?.message || 'Could not create the staff account' })
  }

  // handle_new_user() already created the profiles row from user_metadata;
  // if this is a custom role, patch it in (the trigger only knows `role`).
  if (body.customRoleKey) {
    await admin.from('profiles').update({ role: null, custom_role_key: body.customRoleKey }).eq('id', created.user.id)
  }

  await admin.from('audit_log').insert({
    actor_id: caller.id,
    staff_name: callerProfile?.full_name || caller.email || 'Admin',
    role: 'admin_manager',
    action_type: 'Created Staff Account',
    target: body.email,
  })

  return { userId: created.user.id, tempPassword }
})
