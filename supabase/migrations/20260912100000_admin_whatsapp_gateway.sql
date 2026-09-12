begin;

-- A booked or walk-in patient must be immediately available to nursing,
-- even before reception/matron assigns a doctor or creates a cycle.
create or replace function public.nurse_has_patient_access(p_patient_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists(select 1 from public.bio_details bd where bd.patient_id=p_patient_id and bd.assigned_doctor_id is not null)
    or exists(select 1 from public.appointments a where a.patient_id=p_patient_id)
    or exists(select 1 from public.walk_in_encounters wi where wi.patient_id=p_patient_id)
    or exists(select 1 from public.cycles c where c.patient_id=p_patient_id and c.cycle_manager_id=auth.uid())
    or exists(select 1 from public.cycles c join public.cycle_nurse_assignments cna on cna.cycle_id=c.id where c.patient_id=p_patient_id and cna.nurse_profile_id=auth.uid());
$$;

create table if not exists public.whatsapp_gateway_status (
  id smallint primary key default 1 check (id = 1),
  status text not null default 'offline' check (status in ('offline','pairing','connected','disconnected','logged_out','error')),
  qr_text text,
  account_label text,
  last_error text,
  updated_at timestamptz not null default now()
);

insert into public.whatsapp_gateway_status (id, status)
values (1, 'offline')
on conflict (id) do nothing;

alter table public.whatsapp_gateway_status enable row level security;

drop policy if exists "admin can view whatsapp gateway status" on public.whatsapp_gateway_status;
create policy "admin can view whatsapp gateway status"
on public.whatsapp_gateway_status for select
to authenticated
using (public.is_admin());

commit;
