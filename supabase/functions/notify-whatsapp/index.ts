import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'

const headers = { 'Content-Type': 'application/json' }
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers })

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)
  try {
    const url = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authorization = request.headers.get('Authorization') || ''
    const token = authorization.replace(/^Bearer\s+/i, '')
    if (!token) return json({ error: 'Not authenticated' }, 401)

    const service = createClient(url, serviceKey, { auth: { persistSession: false } })
    const isService = token === serviceKey
    if (!isService) {
      const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } })
      const { data: { user } } = await caller.auth.getUser()
      if (!user) return json({ error: 'Invalid session' }, 401)
      const { data: profile } = await service.from('profiles').select('role, active').eq('id', user.id).single()
      if (!profile?.active || !['admin_manager', 'receptionist'].includes(profile.role)) return json({ error: 'Not authorized' }, 403)
    }

    const body = await request.json().catch(() => ({}))
    let query = service.from('messages_log').select('id, patient_id, body').order('created_at').limit(50)
    if (body.message_id) query = query.eq('id', body.message_id).in('status', ['queued', 'failed'])
    else {
      if (!isService) return json({ error: 'Batch processing requires the service role' }, 403)
      query = query.eq('status', 'queued')
    }
    const { data: messages, error: messageError } = await query
    if (messageError) return json({ error: messageError.message }, 500)

    const evoUrl = Deno.env.get('EVOLUTION_API_URL')
    const evoKey = Deno.env.get('EVOLUTION_API_KEY')
    const evoInstance = Deno.env.get('EVOLUTION_API_INSTANCE')
    if (!evoUrl || !evoKey || !evoInstance) return json({ error: 'Messaging provider is not configured' }, 503)

    let sent = 0
    let failed = 0
    for (const message of messages || []) {
      try {
        const { data: bio } = await service.from('bio_details').select('phone').eq('patient_id', message.patient_id).single()
        const number = bio?.phone?.replace(/[^\d]/g, '')
        if (!number || number.length < 10) throw new Error('No valid phone number on file')
        const response = await fetch(`${evoUrl.replace(/\/$/, '')}/message/sendText/${encodeURIComponent(evoInstance)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', apikey: evoKey },
          body: JSON.stringify({ number, text: message.body }),
        })
        if (!response.ok) throw new Error(`Provider returned ${response.status}`)
        await service.from('messages_log').update({ status: 'sent', sent_at: new Date().toISOString() }).eq('id', message.id)
        sent++
      } catch {
        await service.from('messages_log').update({ status: 'failed' }).eq('id', message.id)
        failed++
      }
    }
    return json({ processed: (messages || []).length, sent, failed })
  } catch (error) {
    return json({ error: String(error) }, 500)
  }
})
