# Phenry Health — Production App

Nuxt 3 + Tailwind + Supabase (Postgres + Auth + RLS + Storage), being built
role-by-role from `phenry-health-spec.md` against the `phenry-health/`
prototype. Progress is tracked in `PROGRESS.md`.

## Setup

1. `cp .env.example .env` and fill in your Supabase project's URL/keys.
2. Push the schema: `supabase link --project-ref <ref>` then
   `supabase db push` (applies everything in `supabase/migrations/` in order).
3. In the Supabase Dashboard → Authentication → Hooks, enable **Custom
   Access Token** and point it at `public.custom_access_token_hook`
   (`supabase/config.toml` does this automatically for local dev via the CLI).
4. Set the two `app.settings.*` database settings and the `notify-whatsapp`
   Edge Function secrets — see `supabase/functions/notify-whatsapp/README.md`.
5. `npm install`
6. `npm run dev`

## Creating the first account

There's no public sign-up screen — every account (patient or staff) is
provisioned by a staff member (Receptionist registers patients; Admin adds
staff). Until the Receptionist role is built, create a test patient manually:

```sql
-- 1. Create the auth user (Dashboard → Authentication → Users → Add User,
--    or supabase.auth.admin.createUser via the SQL editor isn't possible —
--    use the Dashboard or a one-off script with the service role key).
--    Set user_metadata: {"role": "patient", "full_name": "Sarah Jenkins"}

-- 2. Once the trigger creates their profiles row, link + seed clinical data:
insert into patient_names (patient_id, first_name, surname, full_name)
values ('JENKINS/20260115/001', 'Sarah', 'Jenkins', 'Sarah Jenkins');

update profiles set patient_id = 'JENKINS/20260115/001' where id = '<the auth user id>';

insert into bio_details (patient_id, dob, sex, phone, email, status)
values ('JENKINS/20260115/001', '1987-03-12', 'F', '+234 803 555 0142', 'sarah.jenkins@example.com', 'Waiting');
```

## Project structure

See `PROGRESS.md` for the full page-by-page build checklist, and
`phenry-health-spec.md` for the schema/RLS source of truth.
