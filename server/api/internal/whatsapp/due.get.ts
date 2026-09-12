import { createClient } from '@supabase/supabase-js'
import { assertWhatsappWorker } from '~/server/utils/whatsappWorkerAuth'

export default defineEventHandler(async (event) => {
  assertWhatsappWorker(event)
  const config = useRuntimeConfig(event)
  if (!config.supabaseServiceRoleKey) throw createError({ statusCode: 503, statusMessage: 'Reminder queue is not configured' })
  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, { auth: { persistSession: false, autoRefreshToken: false } })
  const today = new Date().toISOString().slice(0, 10)
  const staleClaim = new Date(Date.now() - 10 * 60_000).toISOString()
  await admin.from('messages_log').update({ status: 'failed', last_error: 'Recovered after an interrupted worker attempt' }).eq('trigger_type', 'cycle_reminder').eq('status', 'sending').lt('last_attempt_at', staleClaim)
  const { data, error } = await admin.from('messages_log').select('id,recipient_phone,body,attempts').eq('trigger_type', 'cycle_reminder').in('status', ['queued', 'failed']).lte('scheduled_for', today).lt('attempts', 5).order('created_at').limit(20)
  if (error) throw createError({ statusCode: 500, statusMessage: 'Could not read reminder queue' })
  const claimed: any[] = []
  for (const message of data || []) {
    const { data: row } = await admin.from('messages_log').update({ status: 'sending', attempts: Number(message.attempts || 0) + 1, last_attempt_at: new Date().toISOString(), last_error: null }).eq('id', message.id).eq('trigger_type', 'cycle_reminder').in('status', ['queued', 'failed']).select('id').maybeSingle()
    if (row) claimed.push({ id: message.id, phone: message.recipient_phone, body: message.body })
  }
  return { reminders: claimed }
})
