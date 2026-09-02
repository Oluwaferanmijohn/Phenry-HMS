# Appointment WhatsApp queue worker

This function drains up to 50 queued appointment messages. The database no longer stores a service-role key or calls the function itself.

Deploy it and configure Evolution API secrets:

```sh
supabase functions deploy notify-whatsapp
supabase secrets set EVOLUTION_API_URL=https://your-evolution.example.com
supabase secrets set EVOLUTION_API_KEY=replace-me
supabase secrets set EVOLUTION_API_INSTANCE=phenry-health
```

Configure a Supabase Cron job to POST `{}` to `/functions/v1/notify-whatsapp` every minute with `Authorization: Bearer <service-role-key>`. A receptionist or Admin Manager may also invoke one queued message with `{ "message_id": "..." }`; arbitrary batch processing is service-role only.
