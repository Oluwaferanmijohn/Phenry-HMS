-- Private patient photographs and receptionist-only spouse management.
-- Safe to paste into the Supabase SQL editor more than once.

begin;
set local lock_timeout = '5s';

alter table public.bio_details add column if not exists photo_path text;

-- Some clinical roles can update other bio_details fields. Guard the two
-- spouse columns at row level so those broader policies cannot be used to
-- create or replace a spouse link outside Reception.
create or replace function public.guard_reception_spouse_columns()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if (old.spouse_patient_id is distinct from new.spouse_patient_id
      or old.spouse is distinct from new.spouse)
     and public.current_app_role() <> 'receptionist'
     and coalesce(auth.role(), '') <> 'service_role'
     and session_user not in ('postgres', 'supabase_admin') then
    raise exception 'only reception can change a patient spouse link' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists bio_details_guard_reception_spouse_columns on public.bio_details;
create trigger bio_details_guard_reception_spouse_columns
before update of spouse_patient_id, spouse on public.bio_details
for each row execute function public.guard_reception_spouse_columns();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'patient-photos',
  'patient-photos',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- The first path segment is always the patient ID. Reception owns uploads;
-- every other role gets read access only when it can access that patient.
drop policy if exists "reception manages patient photos" on storage.objects;
create policy "reception manages patient photos"
on storage.objects for all to authenticated
using (
  bucket_id = 'patient-photos'
  and public.current_app_role() = 'receptionist'
)
with check (
  bucket_id = 'patient-photos'
  and public.current_app_role() = 'receptionist'
  and exists (
    select 1 from public.bio_details bd
    where bd.patient_id = (storage.foldername(name))[1]
  )
);

drop policy if exists "authorized staff read patient photos" on storage.objects;
create policy "authorized staff read patient photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'patient-photos'
  and (
    public.current_app_role() in ('receptionist', 'admin_manager', 'matron', 'chief_embryologist', 'lab_tech')
    or (
      public.current_app_role() = 'doctor'
      and (
        public.doctor_has_patient_access((storage.foldername(name))[1])
        or exists (
          select 1 from public.bio_details source
          where source.spouse_patient_id = (storage.foldername(name))[1]
            and public.doctor_has_patient_access(source.patient_id)
        )
      )
    )
    or (
      public.current_app_role() = 'nurse'
      and (
        public.nurse_has_patient_access((storage.foldername(name))[1])
        or exists (
          select 1 from public.bio_details source
          where source.spouse_patient_id = (storage.foldername(name))[1]
            and public.nurse_has_patient_access(source.patient_id)
        )
      )
    )
    or (
      public.current_app_role() = 'patient'
      and (
        public.current_patient_id() = (storage.foldername(name))[1]
        or exists (
          select 1 from public.bio_details source
          where source.patient_id = public.current_patient_id()
            and source.spouse_patient_id = (storage.foldername(name))[1]
        )
      )
    )
    or (
      public.current_app_role() = ''
      and public.has_custom_permission('bio_details', 'view')
      and public.custom_role_scope_ok('bio_details', (storage.foldername(name))[1], null::uuid)
    )
  )
);

-- Returns only the private object path. Supabase Storage still applies its
-- own select policy when the client asks for a short-lived signed URL.
create or replace function public.patient_photo_path(p_patient_id text)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller_role text := public.current_app_role();
  result_path text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (
    caller_role in ('receptionist', 'admin_manager', 'matron', 'chief_embryologist', 'lab_tech')
    or (
      caller_role = 'doctor'
      and (
        public.doctor_has_patient_access(p_patient_id)
        or exists (
          select 1 from public.bio_details source
          where source.spouse_patient_id = p_patient_id
            and public.doctor_has_patient_access(source.patient_id)
        )
      )
    )
    or (
      caller_role = 'nurse'
      and (
        public.nurse_has_patient_access(p_patient_id)
        or exists (
          select 1 from public.bio_details source
          where source.spouse_patient_id = p_patient_id
            and public.nurse_has_patient_access(source.patient_id)
        )
      )
    )
    or (
      caller_role = 'patient'
      and (
        public.current_patient_id() = p_patient_id
        or exists (
          select 1 from public.bio_details source
          where source.patient_id = public.current_patient_id()
            and source.spouse_patient_id = p_patient_id
        )
      )
    )
    or (
      caller_role = ''
      and public.has_custom_permission('bio_details', 'view')
      and public.custom_role_scope_ok('bio_details', p_patient_id, null::uuid)
    )
  ) then
    raise exception 'not authorized to view patient photograph' using errcode = '42501';
  end if;

  select bd.photo_path into result_path
  from public.bio_details bd
  where bd.patient_id = p_patient_id;
  return result_path;
end;
$$;

revoke all on function public.patient_photo_path(text) from public, anon;
grant execute on function public.patient_photo_path(text) to authenticated;

-- A client uploads the new object first and then asks this function to attach
-- it to the record. The previous object path is returned for safe cleanup.
create or replace function public.set_patient_photo(p_patient_id text, p_photo_path text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  old_path text;
begin
  if public.current_app_role() <> 'receptionist' then
    raise exception 'only reception can change a patient photograph' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_photo_path, '')), '') is null
     or split_part(p_photo_path, '/', 1) <> p_patient_id
     or p_photo_path like '%..%' then
    raise exception 'invalid patient photograph path';
  end if;

  select bd.photo_path into old_path
  from public.bio_details bd
  where bd.patient_id = p_patient_id
  for update;
  if not found then raise exception 'patient not found' using errcode = 'P0002'; end if;

  update public.bio_details set photo_path = p_photo_path where patient_id = p_patient_id;
  perform public.log_audit_event('Updated Patient Photograph', p_patient_id);
  return old_path;
end;
$$;

revoke all on function public.set_patient_photo(text,text) from public, anon;
grant execute on function public.set_patient_photo(text,text) to authenticated;

-- Links two existing unlinked patients, or registers a new patient and links
-- both records. This mutation is deliberately receptionist-only.
create or replace function public.link_or_register_patient_spouse(
  p_patient_id text,
  p_existing_spouse_id text default null,
  p_new_spouse jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  subject_link text;
  spouse_link text;
  spouse_id text;
  subject_name text;
  spouse_name text;
  spouse_created boolean := false;
begin
  if public.current_app_role() <> 'receptionist' then
    raise exception 'only reception can link spouses' using errcode = '42501';
  end if;
  if (nullif(btrim(coalesce(p_existing_spouse_id, '')), '') is null) = (p_new_spouse is null) then
    raise exception 'choose either an existing spouse or register a new spouse';
  end if;

  select bd.spouse_patient_id, pn.full_name
  into subject_link, subject_name
  from public.bio_details bd
  join public.patient_names pn using (patient_id)
  where bd.patient_id = p_patient_id
  for update of bd;

  if not found then raise exception 'patient not found' using errcode = 'P0002'; end if;
  if subject_link is not null then raise exception 'patient already has a linked spouse'; end if;

  if p_new_spouse is not null then
    if nullif(btrim(p_new_spouse ->> 'first'), '') is null
       or nullif(btrim(p_new_spouse ->> 'last'), '') is null
       or nullif(btrim(p_new_spouse ->> 'dob'), '') is null then
      raise exception 'new spouse first name, surname, and date of birth are required';
    end if;

    select r.mrn into spouse_id
    from public.register_new_patient(
      p_new_spouse ->> 'first',
      p_new_spouse ->> 'last',
      (p_new_spouse ->> 'dob')::date,
      coalesce(nullif(p_new_spouse ->> 'sex', ''), 'Unknown'),
      p_new_spouse ->> 'phone',
      p_new_spouse ->> 'email',
      p_new_spouse ->> 'address',
      subject_name,
      'Spouse / Partner',
      coalesce((select bd.phone from public.bio_details bd where bd.patient_id = p_patient_id), ''),
      coalesce(nullif(p_new_spouse ->> 'referral_source', ''), 'Linked spouse')
    ) r limit 1;
    spouse_created := true;
  else
    spouse_id := btrim(p_existing_spouse_id);
    if spouse_id = p_patient_id then raise exception 'a patient cannot be linked to themselves'; end if;

    select bd.spouse_patient_id into spouse_link
    from public.bio_details bd
    where bd.patient_id = spouse_id
    for update;
    if not found then raise exception 'selected spouse patient was not found' using errcode = 'P0002'; end if;
    if spouse_link is not null then raise exception 'selected patient is already linked to another spouse'; end if;
  end if;

  select pn.full_name into spouse_name
  from public.patient_names pn where pn.patient_id = spouse_id;

  update public.bio_details
  set spouse_patient_id = spouse_id,
      spouse = coalesce(spouse, '{}'::jsonb) || jsonb_build_object('name', spouse_name, 'patientId', spouse_id)
  where patient_id = p_patient_id;

  update public.bio_details
  set spouse_patient_id = p_patient_id,
      spouse = coalesce(spouse, '{}'::jsonb) || jsonb_build_object('name', subject_name, 'patientId', p_patient_id)
  where patient_id = spouse_id;

  perform public.log_audit_event('Linked Patient Spouses', p_patient_id || ' <-> ' || spouse_id);
  return jsonb_build_object(
    'spouse_patient_id', spouse_id,
    'spouse_name', spouse_name,
    'spouse_created', spouse_created
  );
end;
$$;

revoke all on function public.link_or_register_patient_spouse(text,text,jsonb) from public, anon;
grant execute on function public.link_or_register_patient_spouse(text,text,jsonb) to authenticated;

commit;

select jsonb_pretty(jsonb_build_object(
  'patient_photo_column_present', exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'bio_details' and column_name = 'photo_path'
  ),
  'private_patient_photo_bucket_present', exists (
    select 1 from storage.buckets where id = 'patient-photos' and public = false
  ),
  'patient_photo_functions_present',
    to_regprocedure('public.patient_photo_path(text)') is not null
    and to_regprocedure('public.set_patient_photo(text,text)') is not null,
  'reception_spouse_link_function_present',
    to_regprocedure('public.link_or_register_patient_spouse(text,text,jsonb)') is not null,
  'spouse_column_guard_present', exists (
    select 1 from pg_trigger
    where tgrelid = 'public.bio_details'::regclass
      and tgname = 'bio_details_guard_reception_spouse_columns'
      and not tgisinternal
  ),
  'spouse_link_is_reception_only', position(
    'only reception can link spouses'
    in pg_get_functiondef('public.link_or_register_patient_spouse(text,text,jsonb)'::regprocedure)
  ) > 0
)) as patient_photo_spouse_verification;
