import { createClient } from '@supabase/supabase-js'
import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import QRCode from 'qrcode'

export default defineEventHandler(async (event) => {
  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Not authenticated' })
  const client = await serverSupabaseClient(event)
  const { data: profile } = await client.from('profiles').select('role,active').eq('id', caller.id).maybeSingle()
  if (profile?.role !== 'admin_manager' || !profile.active) throw createError({ statusCode: 403, statusMessage: 'Administrator access required' })

  const config = useRuntimeConfig(event)
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 503, statusMessage: 'WhatsApp gateway is not configured on the server' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await admin.from('whatsapp_gateway_status').select('*').eq('id', 1).maybeSingle()
  if (error) throw createError({ statusCode: 503, statusMessage: 'Run the latest database migration to enable WhatsApp setup' })
  const qrDataUrl = data?.qr_text ? await QRCode.toDataURL(data.qr_text, { width: 360, margin: 2, errorCorrectionLevel: 'M' }) : null
  return { status: data?.status || 'offline', accountLabel: data?.account_label || null, lastError: data?.last_error || null, updatedAt: data?.updated_at || null, qrDataUrl }
})
