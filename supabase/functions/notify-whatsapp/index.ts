// supabase/functions/notify-whatsapp/index.ts
//
// Invoked by the `appointments_notify_whatsapp` Postgres trigger (see
// migration 00000000000002_patient_role.sql) via pg_net whenever an
// appointment is created or rescheduled — the exactly-two triggers allowed
// by spec §4.3. Reads the queued messages_log row, sends it through a
// self-hosted Evolution API (Baileys) instance, and flips status to
// sent/failed.
//
// Required secrets (set via `supabase secrets set` or the Dashboard):
//   EVOLUTION_API_URL       e.g. https://evolution.yourdomain.com
//   EVOLUTION_API_KEY       the instance's apikey
//   EVOLUTION_API_INSTANCE  the Evolution instance name to send from
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  (auto-provided by Supabase)
//
// NOTE: Evolution API's exact request/response shape can differ slightly
// between self-hosted versions. The payload below matches the commonly
// documented `POST /message/sendText/{instance}` endpoint — verify this
// against your instance's own `/docs` before relying on it in production.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'

Deno.serve(async (req) => {
  try {
    const { message_id } = await req.json()
    if (!message_id) {
      return new Response(JSON.stringify({ error: 'message_id is required' }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: msg, error: fetchErr } = await supabase
      .from('messages_log')
      .select('id, patient_id, body')
      .eq('id', message_id)
      .single()

    if (fetchErr || !msg) {
      return new Response(JSON.stringify({ error: 'message not found', details: fetchErr }), { status: 404 })
    }

    const { data: bio, error: bioErr } = await supabase
      .from('bio_details')
      .select('phone')
      .eq('patient_id', msg.patient_id)
      .single()

    if (bioErr || !bio?.phone) {
      await supabase.from('messages_log').update({ status: 'failed' }).eq('id', message_id)
      return new Response(JSON.stringify({ error: 'no phone number on file for patient' }), { status: 422 })
    }

    const evoUrl = Deno.env.get('EVOLUTION_API_URL')
    const evoKey = Deno.env.get('EVOLUTION_API_KEY')
    const evoInstance = Deno.env.get('EVOLUTION_API_INSTANCE')

    const number = bio.phone.replace(/[^\d]/g, '') // Evolution/Baileys wants digits only, country code included

    const res = await fetch(`${evoUrl}/message/sendText/${evoInstance}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: evoKey ?? '' },
      body: JSON.stringify({ number, text: msg.body }),
    })

    const sent = res.ok
    await supabase
      .from('messages_log')
      .update({ status: sent ? 'sent' : 'failed', sent_at: sent ? new Date().toISOString() : null })
      .eq('id', message_id)

    return new Response(JSON.stringify({ sent }), { status: sent ? 200 : 502 })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
