# Baileys WhatsApp care reminders

This worker sends only due `cycle_reminder` messages created for patients who explicitly opted in. It never receives the Supabase service-role key or arbitrary message-log records.

1. Run the `20260912090000_cycle_team_whatsapp_and_patient_filters.sql` and `20260912100000_admin_whatsapp_gateway.sql` migrations in Supabase.
2. Run `npm install`.
3. Add `WHATSAPP_WORKER_SECRET` to the project `.env` file. The Nuxt server and worker both load that file, so they will use the same long random value. Restart Nuxt after adding it.
4. Locally, the worker automatically checks the project URL `http://localhost:3027` (with IPv4/IPv6 fallbacks). In production set `APP_BASE_URL`, for example `https://your-clinic-app.example`.
5. Set `BAILEYS_AUTH_DIR` to a private persistent directory outside the repository. Optional: `WHATSAPP_DEFAULT_COUNTRY_CODE=234`.
6. Start Nuxt with `npm run dev` and leave it running. In a second terminal, run `npm run whatsapp:worker`. If Nuxt is unavailable, the worker waits instead of producing an unusable QR.
7. Sign in as Admin Manager and open **WhatsApp Setup**. On the official hospital phone, open WhatsApp → **Linked devices** → **Link a device**, then scan the QR shown on the admin dashboard.

Keep exactly one worker running. The QR is intentionally visible only to an active administrator. The auth directory contains long-lived WhatsApp encryption keys and must never be committed, shared, or stored on an ephemeral public filesystem. Baileys is unofficial; use a dedicated clinic number, patient consent, low-volume care messages, and comply with WhatsApp’s terms.
