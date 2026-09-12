import { createClient } from '@supabase/supabase-js'
import { assertWhatsappWorker } from '~/server/utils/whatsappWorkerAuth'

const ALLOWED_STATUSES = new Set(['offline', 'pairing', 'connected', 'disconnected', 'logged_out', 'error'])

export default defineEventHandler(async (event) => {
  assertWhatsappWorker(event)
  const body = await readBody<{ status?: string; qr?: string | null; accountLabel?: string | null; error?: string | null }>(event)
  if (!body?.status || !ALLOWED_STATUSES.has(body.status)) throw createError({ statusCode: 400, statusMessage: 'Invalid gateway status' })
  const config = useRuntimeConfig(event)
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 503, statusMessage: 'WhatsApp gateway is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, { auth: { persistSession: false, autoRefreshToken: false } })
  const { error } = await admin.from('whatsapp_gateway_status').upsert({
    id: 1,
    status: body.status,
    qr_text: body.qr ? String(body.qr).slice(0, 12000) : null,
    account_label: body.accountLabel ? String(body.accountLabel).slice(0, 120) : null,
    last_error: body.error ? String(body.error).slice(0, 500) : null,
    updated_at: new Date().toISOString(),
  })
  if (error) throw createError({ statusCode: 500, statusMessage: 'Could not publish WhatsApp gateway status' })
  return { ok: true }
})
