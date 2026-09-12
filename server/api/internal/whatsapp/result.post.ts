import { createClient } from '@supabase/supabase-js'
import { assertWhatsappWorker } from '~/server/utils/whatsappWorkerAuth'

export default defineEventHandler(async (event) => {
  assertWhatsappWorker(event)
  const body = await readBody<{ id?: string; success?: boolean; providerMessageId?: string | null; error?: string | null }>(event)
  if (!body?.id || typeof body.success !== 'boolean') throw createError({ statusCode: 400, statusMessage: 'id and success are required' })
  const config = useRuntimeConfig(event)
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 503, statusMessage: 'Reminder queue is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, { auth: { persistSession: false, autoRefreshToken: false } })
  const patch = body.success
    ? { status: 'sent', sent_at: new Date().toISOString(), provider_message_id: body.providerMessageId || null, last_error: null }
    : { status: 'failed', last_error: String(body.error || 'WhatsApp send failed').slice(0, 500) }
  const { error } = await admin.from('messages_log').update(patch).eq('id', body.id).eq('trigger_type', 'cycle_reminder').eq('status', 'sending')
  if (error) throw createError({ statusCode: 500, statusMessage: 'Could not update reminder status' })
  return { ok: true }
})
