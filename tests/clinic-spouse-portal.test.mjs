import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const read = (path) => readFile(new URL(`../${path}`, import.meta.url), 'utf8')

test('admin captures complete official identity and the lab report consumes it', async () => {
  const [settings, report, migration] = await Promise.all([
    read('pages/admin_manager/settings.vue'),
    read('components/shared/LabResultReportModal.vue'),
    read('supabase/migrations/20260905100000_clinic_identity_spouses_and_portal_access.sql'),
  ])

  for (const field of [
    'clinic_tagline', 'company_email', 'company_website', 'company_phone_alt',
    'registration_number', 'laboratory_license_number', 'tax_identification_number',
    'laboratory_director_name', 'laboratory_director_title', 'report_footer',
  ]) {
    assert.match(settings, new RegExp(field))
    assert.match(migration, new RegExp(field))
  }
  assert.match(report, /officialIdentifiers/)
  assert.match(report, /clinicContacts/)
  assert.match(report, /clinic\.report_footer/)
})

test('reception can register or connect spouses as reciprocal patient records', async () => {
  const [registration, migration, detail, directory] = await Promise.all([
    read('pages/receptionist/register.vue'),
    read('supabase/migrations/20260905100000_clinic_identity_spouses_and_portal_access.sql'),
    read('components/shared/PatientDetailModal.vue'),
    read('components/shared/PatientsSearchPage.vue'),
  ])

  assert.match(registration, /Link existing patient/)
  assert.match(registration, /Register partner too/)
  assert.match(registration, /register_new_patient_with_partner/)
  assert.match(registration, /spouse_created/)
  assert.match(migration, /set spouse_patient_id = partner_id/)
  assert.match(migration, /set spouse_patient_id = primary_id/)
  assert.match(migration, /patient_spouse_summary/)
  assert.match(migration, /linked_spouse_patient_detail/)
  assert.match(detail, /open-spouse/)
  assert.match(directory, /openLinkedSpouseFrom/)
})

test('reception sees only patient login ID and resets passwords server-side', async () => {
  const [patients, resetRoute, migration] = await Promise.all([
    read('pages/receptionist/patients.vue'),
    read('server/api/receptionist/reset-patient-password.post.ts'),
    read('supabase/migrations/20260905100000_clinic_identity_spouses_and_portal_access.sql'),
  ])

  assert.match(patients, /Patient Portal Login/)
  assert.match(patients, /Login ID/)
  assert.match(patients, /Reset Password/)
  assert.match(resetRoute, /generateTemporaryPassword/)
  assert.match(resetRoute, /updateUserById/)
  assert.match(resetRoute, /force_password_reset: true/)
  assert.match(resetRoute, /Reset Patient Portal Password/)
  assert.doesNotMatch(resetRoute, /\.select\(['"]password['"]\)/i)
  assert.match(migration, /portal_login_exists/)
})

test('patient pictures are private, validated, and visible from shared patient details', async () => {
  const [migration, photoHelper, photoPicker, registration, detail] = await Promise.all([
    read('supabase/migrations/20260905130000_patient_photos_and_reception_spouse_management.sql'),
    read('composables/usePatientPhoto.ts'),
    read('components/shared/PatientPhotoPicker.vue'),
    read('pages/receptionist/register.vue'),
    read('components/shared/PatientDetailModal.vue'),
  ])

  assert.match(migration, /add column if not exists photo_path/)
  assert.match(migration, /'patient-photos'[\s\S]*false/)
  assert.match(migration, /file_size_limit/)
  assert.match(migration, /patient_photo_path/)
  assert.match(migration, /set_patient_photo/)
  assert.match(photoHelper, /createSignedUrl/)
  assert.match(photoHelper, /5 \* 1024 \* 1024/)
  assert.match(photoPicker, /capture="environment"/)
  assert.match(registration, /primaryPhotoFile/)
  assert.match(registration, /partnerPhotoFile/)
  assert.match(registration, /uploadPatientPhoto/)
  assert.match(detail, /patientPhotoUrl/)
  assert.match(detail, /fetchPatientPhotoUrl/)
})

test('only reception can add spouse links after registration', async () => {
  const [migration, receptionPatients, linkModal, nurseVisit] = await Promise.all([
    read('supabase/migrations/20260905130000_patient_photos_and_reception_spouse_management.sql'),
    read('pages/receptionist/patients.vue'),
    read('components/receptionist/SpouseLinkModal.vue'),
    read('pages/nurse/visit.vue'),
  ])

  assert.match(migration, /link_or_register_patient_spouse/)
  assert.match(migration, /current_app_role\(\) <> 'receptionist'/)
  assert.match(migration, /bio_details_guard_reception_spouse_columns/)
  assert.match(migration, /only reception can change a patient spouse link/)
  assert.match(migration, /set spouse_patient_id = spouse_id/)
  assert.match(migration, /set spouse_patient_id = p_patient_id/)
  assert.match(receptionPatients, /Link Spouse/)
  assert.match(receptionPatients, /SpouseLinkModal/)
  assert.match(linkModal, /Link existing patient/)
  assert.match(linkModal, /Register new spouse/)
  assert.match(linkModal, /link_or_register_patient_spouse/)
  assert.doesNotMatch(nurseVisit, /function linkSpouse/)
  assert.doesNotMatch(nurseVisit, /function unlinkSpouse/)
  assert.doesNotMatch(nurseVisit, /update\(\{ spouse_patient_id:/)
})
