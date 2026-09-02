-- Cycle logging and nursing record repair.

-- A blank protocol row is clinician-authored, but production requires a
-- non-null phase. Keep it blank rather than inventing a treatment phase.
update public.cycle_daily_logs set phase = '' where phase is null;
alter table public.cycle_daily_logs alter column phase set default '';
alter table public.cycle_daily_logs alter column phase set not null;

-- An explicitly assigned cycle manager must retain access even when the
-- patient's general doctor assignment has not been completed yet.
create or replace function public.nurse_has_patient_access(p_patient_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.bio_details bd
    where bd.patient_id = p_patient_id and bd.assigned_doctor_id is not null
  ) or exists (
    select 1 from public.cycles c
    where c.patient_id = p_patient_id and c.cycle_manager_id = auth.uid()
  );
$$;

-- Extend nurse visits into a complete observations + fertility intake record.
alter table public.nurse_visits add column if not exists respiratory_rate_bpm int;
alter table public.nurse_visits add column if not exists pain_score int;
alter table public.nurse_visits add column if not exists waist_cm numeric(5,1);
alter table public.nurse_visits add column if not exists blood_glucose_mmol_l numeric(5,1);
alter table public.nurse_visits add column if not exists visit_type text;
alter table public.nurse_visits add column if not exists chief_complaint text;
alter table public.nurse_visits add column if not exists reproductive_intake jsonb not null default '{}'::jsonb;
alter table public.nurse_visits add column if not exists medical_intake jsonb not null default '{}'::jsonb;
alter table public.bio_details add column if not exists registration_consent_at timestamptz;

alter table public.nurse_visits drop constraint if exists nurse_visits_pain_score_check;
alter table public.nurse_visits add constraint nurse_visits_pain_score_check check (pain_score is null or pain_score between 0 and 10);
alter table public.nurse_visits drop constraint if exists nurse_visits_respiratory_rate_check;
alter table public.nurse_visits add constraint nurse_visits_respiratory_rate_check check (respiratory_rate_bpm is null or respiratory_rate_bpm between 1 and 100);

comment on column public.nurse_visits.reproductive_intake is 'Sex-appropriate fertility context reported during nursing intake; not a diagnosis.';
comment on column public.nurse_visits.medical_intake is 'Current medications, reported allergies/conditions, lifestyle context, and triage observations.';

-- Return the complete front-desk registration record without widening direct
-- table access. The original table-returning RPC cannot gain a column through
-- CREATE OR REPLACE, so expose a JSON profile alongside it.
create or replace function public.patient_front_desk_profile_v2(p_patient_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare result jsonb;
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized';
  end if;
  select to_jsonb(pn) || to_jsonb(bd) into result
  from public.patient_names pn
  join public.bio_details bd on bd.patient_id = pn.patient_id
  where pn.patient_id = p_patient_id;
  return result;
end;
$$;
revoke all on function public.patient_front_desk_profile_v2(text) from public, anon;
grant execute on function public.patient_front_desk_profile_v2(text) to authenticated;

create or replace function public.record_registration_consent(p_patient_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.current_app_role() not in ('receptionist', 'admin_manager') then
    raise exception 'not authorized';
  end if;
  update public.bio_details set registration_consent_at = now() where patient_id = p_patient_id;
  if not found then raise exception 'patient not found'; end if;
end;
$$;
revoke all on function public.record_registration_consent(text) from public, anon;
grant execute on function public.record_registration_consent(text) to authenticated;
