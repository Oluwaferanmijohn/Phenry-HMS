import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'

const origin = Deno.env.get('APP_ORIGIN') || '*'
const corsHeaders = {
  'Access-Control-Allow-Origin': origin,
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders })
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const authorization = request.headers.get('Authorization')
    if (!authorization) return json({ error: 'Not authenticated' }, 401)

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const callerClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } })
    const service = createClient(url, serviceKey, { auth: { persistSession: false } })
    const { data: { user }, error: userError } = await callerClient.auth.getUser()
    if (userError || !user) return json({ error: 'Invalid session' }, 401)

    const { data: profile } = await service.from('profiles').select('role, active').eq('id', user.id).single()
    if (!profile?.active || !['admin_manager', 'matron'].includes(profile.role)) return json({ error: 'Not authorized' }, 403)

    const { broadcast_id } = await request.json()
    if (!broadcast_id) return json({ error: 'broadcast_id is required' }, 400)
    const { data: broadcast } = await service.from('emergency_broadcasts').select('id, message, created_by').eq('id', broadcast_id).single()
    if (!broadcast || broadcast.created_by !== user.id) return json({ error: 'Broadcast not found' }, 404)

    const evoUrl = Deno.env.get('EVOLUTION_API_URL')
    const evoKey = Deno.env.get('EVOLUTION_API_KEY')
    const evoInstance = Deno.env.get('EVOLUTION_API_INSTANCE')
    if (!evoUrl || !evoKey || !evoInstance) return json({ error: 'Emergency messaging provider is not configured' }, 503)

    const { data: recipients, error: recipientError } = await service
      .from('emergency_broadcast_recipients')
      .select('id, phone')
      .eq('broadcast_id', broadcast_id)
      .in('status', ['queued', 'failed'])
      .limit(200)
    if (recipientError) return json({ error: recipientError.message }, 500)

    let sent = 0
    let failed = 0
    for (const recipient of recipients || []) {
      const number = recipient.phone.replace(/[^\d]/g, '')
      try {
        if (number.length < 10) throw new Error('Invalid phone number')
        const response = await fetch(`${evoUrl.replace(/\/$/, '')}/message/sendText/${encodeURIComponent(evoInstance)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', apikey: evoKey },
          body: JSON.stringify({ number, text: `EMERGENCY — ${broadcast.message}` }),
        })
        if (!response.ok) throw new Error(`Provider returned ${response.status}`)
        await service.from('emergency_broadcast_recipients').update({ status: 'sent', sent_at: new Date().toISOString(), error_message: null }).eq('id', recipient.id)
        sent++
      } catch (error) {
        await service.from('emergency_broadcast_recipients').update({ status: 'failed', error_message: String(error).slice(0, 500) }).eq('id', recipient.id)
        failed++
      }
    }
    return json({ sent, failed })
  } catch (error) {
    return json({ error: String(error) }, 500)
  }
})
