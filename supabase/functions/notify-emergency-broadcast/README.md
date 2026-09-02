# Emergency broadcast Edge Function

Deploy with JWT verification enabled, then configure the same Evolution API instance used for appointment messages:

```sh
supabase functions deploy notify-emergency-broadcast
supabase secrets set EVOLUTION_API_URL=https://your-evolution.example.com
supabase secrets set EVOLUTION_API_KEY=replace-me
supabase secrets set EVOLUTION_API_INSTANCE=phenry-health
supabase secrets set APP_ORIGIN=https://your-emr.example.com
```

The function independently verifies that the caller is an active Admin Manager or Matron. It reads only the queued recipients for a broadcast created by that caller and records each delivery result.
