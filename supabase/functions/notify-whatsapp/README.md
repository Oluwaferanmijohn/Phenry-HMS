# notify-whatsapp Edge Function — setup

This function is invoked by Postgres (via `pg_net`), not called directly by
the frontend. Two things need to be configured once per environment:

## 1. Edge Function secrets
```
supabase secrets set EVOLUTION_API_URL=https://your-evolution-instance.example.com
supabase secrets set EVOLUTION_API_KEY=your-instance-apikey
supabase secrets set EVOLUTION_API_INSTANCE=phenry-health
```
`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically to
every Edge Function — no need to set those.

## 2. Database-level settings for pg_net
The `notify_appointment_whatsapp()` trigger function (migration
`00000000000002_patient_role.sql`) needs to know this project's URL and
service-role key to call the Edge Function. Set these once via the SQL
editor or CLI (values are visible in Dashboard → Project Settings → API):
```sql
alter database postgres set app.settings.supabase_url = 'https://<project-ref>.supabase.co';
alter database postgres set app.settings.service_role_key = '<service-role-key>';
```
Until these are set, appointment inserts/reschedules still write to
`messages_log` (status stays `queued`) — the app doesn't fail, the WhatsApp
send just doesn't fire.
