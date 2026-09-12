<template>
  <div>
    <div class="page-header"><div><h1>New Patient Registration</h1><div class="desc">Step {{ step }} of {{ steps.length }} — {{ steps[step - 1] }}</div></div></div>

    <div class="card card-pad" style="max-width:700px;">
      <div class="steps" style="margin-bottom:22px;">
        <template v-for="(s, i) in steps" :key="s">
          <div class="step" :class="{ done: i + 1 < step, current: i + 1 === step }">
            <div class="num"><Icon v-if="i + 1 < step" name="check-circle" :size="13" /><template v-else>{{ i + 1 }}</template></div>
            <div class="step-label">{{ s }}</div>
          </div>
          <div v-if="i < steps.length - 1" class="step-line" :class="{ done: i + 1 < step }" />
        </template>
      </div>

      <div v-if="step === 1">
        <b style="font-size:13px;"><Icon name="user" :size="13" /> Personal Identification</b>
        <div style="margin-top:12px;">
          <PatientPhotoPicker v-model="primaryPhotoFile" :patient-name="`${draft.first} ${draft.last}`.trim()" />
        </div>
        <div class="form-row" style="margin-top:12px;">
          <div class="field"><label>Legal First Name</label><input v-model="draft.first" class="input" placeholder="e.g. Jane" /></div>
          <div class="field"><label>Surname</label><input v-model="draft.last" class="input" placeholder="e.g. Doe" /></div>
        </div>
        <div class="form-row">
          <div class="field"><label>Date of Birth</label><input v-model="draft.dob" class="input" type="date" /></div>
          <div class="field"><label>Assigned Sex at Birth</label><select v-model="draft.sex" class="input"><option>F</option><option>M</option></select></div>
        </div>
      </div>

      <div v-else-if="step === 2">
        <b style="font-size:13px;"><Icon name="phone" :size="13" /> Contact Information</b>
        <div class="form-row" style="margin-top:12px;">
          <div class="field"><label>Primary Phone Number</label><input v-model="draft.phone" class="input" placeholder="(555) 000-0000" /></div>
          <div class="field"><label>Email Address</label><input v-model="draft.email" class="input" placeholder="jane.doe@example.com" /></div>
        </div>
        <div class="form-row">
          <div class="field"><label>WhatsApp Number</label><input v-model="draft.whatsappPhone" class="input" placeholder="e.g. +2348012345678" /></div>
          <label class="checkbox-row whatsapp-consent"><input v-model="draft.whatsappOptIn" type="checkbox" /><span>Patient agrees to receive appointment and daily treatment reminders on WhatsApp.</span></label>
        </div>
        <div class="field"><label>Home Address</label><textarea v-model="draft.addr" class="input" rows="2" placeholder="Street Address, City, State" /></div>
        <div class="card-pad" style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); margin-top:6px;">
          <b style="font-size:12.5px; color:var(--red-600);">✳ Emergency Contact</b>
          <div class="form-row" style="margin-top:10px;">
            <div class="field"><label>Contact Full Name</label><input v-model="draft.ecName" class="input" placeholder="Contact Name" /></div>
            <div class="field"><label>Relationship</label><input v-model="draft.ecRel" class="input" placeholder="e.g. Spouse, Parent" /></div>
          </div>
          <div class="field"><label>Emergency Phone Number</label><input v-model="draft.ecPhone" class="input" placeholder="(555) 000-0000" /></div>
        </div>
      </div>

      <div v-else-if="step === 3">
        <b style="font-size:13px;"><Icon name="users" :size="13" /> Spouse / Partner</b>
        <p class="cell-muted" style="margin:6px 0 14px;">Connect this patient to an existing registered partner, register both partners together, or continue without a spouse link.</p>
        <div class="spouse-mode-grid">
          <button type="button" :class="['spouse-mode', { active: spouseMode === 'none' }]" @click="spouseMode = 'none'"><b>No spouse link</b><span>Register this patient only</span></button>
          <button type="button" :class="['spouse-mode', { active: spouseMode === 'existing' }]" @click="spouseMode = 'existing'"><b>Link existing patient</b><span>Choose an already registered partner</span></button>
          <button type="button" :class="['spouse-mode', { active: spouseMode === 'new' }]" @click="spouseMode = 'new'"><b>Register partner too</b><span>Create and connect a second patient</span></button>
        </div>
        <div v-if="spouseMode === 'existing'" class="field" style="margin-top:16px;">
          <label>Existing Spouse / Partner</label>
          <input v-model="spouseSearch" class="input" placeholder="Search by patient name or ID" />
          <div class="spouse-search-results">
            <button v-for="patient in filteredSpousePatients" :key="patient.patient_id" type="button" :class="['spouse-result', { selected: existingSpouseId === patient.patient_id }]" @click="existingSpouseId = patient.patient_id">
              <span><b>{{ patient.full_name }}</b><small>{{ patient.patient_id }} · {{ patient.sex || 'Sex not recorded' }}</small></span>
              <Icon :name="existingSpouseId === patient.patient_id ? 'check-circle' : 'chevron-right'" :size="14" />
            </button>
          </div>
        </div>
        <div v-else-if="spouseMode === 'new'" class="partner-form">
          <PatientPhotoPicker v-model="partnerPhotoFile" :patient-name="`${partner.first} ${partner.last}`.trim()" />
          <div class="form-row">
            <div class="field"><label>Partner Legal First Name</label><input v-model="partner.first" class="input" /></div>
            <div class="field"><label>Partner Surname</label><input v-model="partner.last" class="input" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Partner Date of Birth</label><input v-model="partner.dob" class="input" type="date" /></div>
            <div class="field"><label>Partner Sex at Birth</label><select v-model="partner.sex" class="input"><option>F</option><option>M</option><option>Other</option><option>Unknown</option></select></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Partner Phone</label><input v-model="partner.phone" class="input" /></div>
            <div class="field"><label>Partner Email</label><input v-model="partner.email" class="input" type="email" /></div>
          </div>
          <div class="form-row"><div class="field"><label>Partner WhatsApp Number</label><input v-model="partner.whatsappPhone" class="input" placeholder="e.g. +2348012345678" /></div><label class="checkbox-row whatsapp-consent"><input v-model="partner.whatsappOptIn" type="checkbox" /><span>Partner agrees to WhatsApp care reminders.</span></label></div>
          <div class="field"><label>Partner Address</label><textarea v-model="partner.address" class="input" rows="2" :placeholder="draft.addr || 'Leave blank to use the primary patient address'" /></div>
        </div>
      </div>

      <div v-else>
        <b style="font-size:13px;"><Icon name="clipboard" :size="13" /> Referral Source</b>
        <div class="field" style="margin-top:12px;">
          <label>How did the patient hear about us?</label>
          <select v-model="draft.ref" class="input">
            <option>Instagram Ad</option><option>Google Search</option><option>Physician Referral</option>
            <option>Referral — Friend/Family</option><option>Walk-in</option>
          </select>
        </div>
        <div class="checkbox-row"><input id="rg-consent" v-model="draft.consent" type="checkbox" /><label for="rg-consent">Patient has agreed to the Data Privacy &amp; Medical Consent terms.</label></div>
      </div>

      <div class="flex-between" style="margin-top:22px;">
        <button class="btn btn-secondary" :disabled="step === 1" @click="step--"><Icon name="chevron-left" :size="13" /> Back</button>
        <button v-if="step < steps.length" class="btn btn-primary" @click="nextStep">Next <Icon name="arrow-right" :size="13" /></button>
        <button v-else class="btn btn-primary" :disabled="submitting" @click="submit"><Icon name="check-circle" :size="13" /> Complete Registration</button>
      </div>
    </div>

    <Modal :model-value="portalCredentials.length > 0" title="Patient Registration Complete" @update:model-value="closeCredentials">
      <div class="empty-state" style="padding:6px 0;">
        <div class="icon-wrap"><Icon name="check-circle" :size="22" /></div>
        <h4>{{ portalCredentials.length > 1 ? 'Both portal logins were created' : 'Portal login created' }}</h4>
        <p>Give each patient only their own temporary details. They will be required to choose a new password at first sign-in.</p>
      </div>
      <div v-for="credential in portalCredentials" :key="credential.patientId" class="card-pad credential-card">
        <b>{{ credential.name }}</b>
        <div class="flex-between" style="margin-top:9px;"><span class="cell-muted">Patient ID (username)</span><b class="mono">{{ credential.patientId }}</b></div>
        <div class="flex-between" style="margin-top:8px;"><span class="cell-muted">One-time temporary password</span><b class="mono">{{ credential.password }}</b></div>
      </div>
      <template #footer>
        <button class="btn btn-primary" @click="closeCredentials"><Icon name="check-circle" :size="13" /> Done</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, reactive } from 'vue'
import { useToast } from '~/composables/useToast'
import { uploadPatientPhoto } from '~/composables/usePatientPhoto'

const supabase = useSupabaseClient()
const { toast } = useToast()
const router = useRouter()

const steps = ['Personal Details', 'Contact & Emergency', 'Spouse / Partner', 'Referral & Consent']
const step = ref(1)
const submitting = ref(false)
const primaryPhotoFile = ref<File | null>(null)
const partnerPhotoFile = ref<File | null>(null)

const draft = reactive({
  first: '', last: '', dob: '', sex: 'F',
  phone: '', whatsappPhone: '', whatsappOptIn: false, email: '', addr: '', ecName: '', ecRel: '', ecPhone: '',
  ref: 'Instagram Ad', consent: true,
})
const spouseMode = ref<'none' | 'existing' | 'new'>('none')
const existingSpouseId = ref('')
const spouseSearch = ref('')
const spousePatients = ref<any[]>([])
const partner = reactive({ first: '', last: '', dob: '', sex: 'M', phone: '', whatsappPhone: '', whatsappOptIn: false, email: '', address: '' })

await useAsyncData('registration-spouse-directory', async () => {
  const { data } = await supabase.rpc('reception_spouse_directory', { p_search: '' })
  spousePatients.value = data || []
  return true
})

const filteredSpousePatients = computed(() => {
  const query = spouseSearch.value.trim().toLowerCase()
  return spousePatients.value
    .filter((patient) => !patient.spouse_patient_id)
    .filter((patient) => !query || `${patient.full_name} ${patient.patient_id}`.toLowerCase().includes(query))
    .slice(0, 8)
})

const portalCredentials = ref<{ patientId: string; password: string; name: string }[]>([])
function closeCredentials() {
  portalCredentials.value = []
  router.push('/receptionist/patients')
}

function nextStep() {
  if (step.value === 1 && (!draft.first.trim() || !draft.last.trim() || !draft.dob)) {
    toast('First name, surname, and date of birth are required', 'warn')
    return
  }
  if (step.value === 2 && draft.whatsappOptIn && !draft.whatsappPhone.trim()) {
    toast('Enter the patient WhatsApp number before enabling reminders.', 'warn')
    return
  }
  if (step.value === 3 && spouseMode.value === 'existing' && !existingSpouseId.value) {
    toast('Select the existing spouse, or choose another spouse option.', 'warn')
    return
  }
  if (step.value === 3 && spouseMode.value === 'new' && (!partner.first.trim() || !partner.last.trim() || !partner.dob)) {
    toast('Partner first name, surname, and date of birth are required.', 'warn')
    return
  }
  if (step.value === 3 && spouseMode.value === 'new' && partner.whatsappOptIn && !partner.whatsappPhone.trim()) {
    toast('Enter the partner WhatsApp number before enabling reminders.', 'warn')
    return
  }
  step.value++
}

async function submit() {
  if (!draft.first || !draft.last || !draft.dob) {
    step.value = 1
    toast('First name, surname, and date of birth are required', 'warn')
    return
  }
  if (!draft.consent) {
    step.value = 4
    toast('Patient consent must be confirmed before registration', 'warn')
    return
  }
  submitting.value = true
  const { data, error } = await supabase.rpc('register_new_patient_with_partner', {
    p_first: draft.first,
    p_last: draft.last,
    p_dob: draft.dob,
    p_sex: draft.sex,
    p_phone: draft.phone,
    p_email: draft.email,
    p_address: draft.addr,
    p_ec_name: draft.ecName,
    p_ec_relationship: draft.ecRel,
    p_ec_phone: draft.ecPhone,
    p_referral_source: draft.ref,
    p_existing_spouse_id: spouseMode.value === 'existing' ? existingSpouseId.value : null,
    p_new_spouse: spouseMode.value === 'new' ? { ...partner } : null,
  })

  if (error || !data?.patient_id) {
    submitting.value = false
    toast(error?.message || 'Could not register the patient — please try again', 'warn')
    return
  }

  const mrn = data.patient_id as string
  const spouseMrn = data.spouse_patient_id as string | null
  const whatsappUpdates = [
    supabase.from('bio_details').update({ whatsapp_phone: draft.whatsappPhone.trim() || null, whatsapp_opt_in: draft.whatsappOptIn }).eq('patient_id', mrn),
    ...(data.spouse_created && spouseMrn ? [supabase.from('bio_details').update({ whatsapp_phone: partner.whatsappPhone.trim() || null, whatsapp_opt_in: partner.whatsappOptIn }).eq('patient_id', spouseMrn)] : []),
  ]
  const whatsappResults = await Promise.all(whatsappUpdates)
  if (whatsappResults.some((result) => result.error)) toast('Registration succeeded, but WhatsApp consent details need the latest database update.', 'warn')
  const newlyRegisteredIds = [mrn, data.spouse_created ? spouseMrn : null].filter(Boolean) as string[]
  const consentResults = await Promise.all(newlyRegisteredIds.map((patientId) => supabase.rpc('record_registration_consent', { p_patient_id: patientId })))
  if (consentResults.some((result) => result.error)) toast('Registration succeeded, but a consent timestamp could not be recorded', 'warn')

  const photoUploads: Array<{ patientId: string; file: File; name: string }> = []
  if (primaryPhotoFile.value) photoUploads.push({ patientId: mrn, file: primaryPhotoFile.value, name: `${draft.first.trim()} ${draft.last.trim()}` })
  if (data.spouse_created && spouseMrn && partnerPhotoFile.value) photoUploads.push({ patientId: spouseMrn, file: partnerPhotoFile.value, name: `${partner.first.trim()} ${partner.last.trim()}` })
  for (const photo of photoUploads) {
    try { await uploadPatientPhoto(supabase, photo.patientId, photo.file) }
    catch (photoError: any) { toast(`${photo.name} was registered, but their picture could not be saved: ${photoError?.message || 'upload failed'}`, 'warn') }
  }

  // Registration and portal-account creation are two separate calls — the
  // account needs the service-role key (server route), the RPC doesn't.
  // A failure here still leaves the patient successfully registered; it
  // just means Admin needs to set up their login separately, which is
  // surfaced clearly rather than silently losing that step.
  const accountNames = new Map<string, string>([
    [mrn, `${draft.first.trim()} ${draft.last.trim()}`],
    ...(data.spouse_created && spouseMrn ? [[spouseMrn, `${partner.first.trim()} ${partner.last.trim()}`] as [string, string]] : []),
  ])
  for (const patientId of newlyRegisteredIds) {
    try {
      const account = await $fetch<{ tempPassword?: string; alreadyExists?: boolean }>('/api/receptionist/create-patient-account', { method: 'POST', body: { patientId } })
      if (account.tempPassword) portalCredentials.value.push({ patientId, password: account.tempPassword, name: accountNames.get(patientId) || patientId })
      else toast(`${accountNames.get(patientId) || patientId} was registered, but the portal login already existed and its password was not changed.`, 'warn')
    } catch {
      toast(`${accountNames.get(patientId) || patientId} was registered, but the portal login could not be created — ask Admin to set it up.`, 'warn')
    }
  }

  submitting.value = false
  step.value = 1
  Object.assign(draft, { first: '', last: '', dob: '', sex: 'F', phone: '', whatsappPhone: '', whatsappOptIn: false, email: '', addr: '', ecName: '', ecRel: '', ecPhone: '', ref: 'Instagram Ad', consent: true })
  Object.assign(partner, { first: '', last: '', dob: '', sex: 'M', phone: '', whatsappPhone: '', whatsappOptIn: false, email: '', address: '' })
  spouseMode.value = 'none'
  existingSpouseId.value = ''
  spouseSearch.value = ''
  primaryPhotoFile.value = null
  partnerPhotoFile.value = null
  if (!portalCredentials.value.length) router.push('/receptionist/patients')
}
</script>

<style scoped>
.spouse-mode-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:10px; }
.spouse-mode { border:1px solid var(--border-strong); border-radius:var(--radius-sm); background:#fff; padding:13px; text-align:left; color:var(--text-700); font-family:inherit; }
.spouse-mode b, .spouse-mode span { display:block; }
.spouse-mode b { font-size:12.5px; color:var(--text-900); }
.spouse-mode span { margin-top:4px; font-size:10.5px; color:var(--text-500); line-height:1.35; }
.spouse-mode.active { border-color:var(--blue-500); background:var(--blue-50); box-shadow:0 0 0 2px var(--blue-50); }
.partner-form { margin-top:16px; padding:14px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }
.spouse-search-results { display:flex; flex-direction:column; gap:6px; max-height:270px; overflow-y:auto; margin-top:8px; }
.spouse-result { display:flex; align-items:center; justify-content:space-between; width:100%; padding:10px 11px; border:1px solid var(--border); border-radius:8px; background:#fff; text-align:left; color:var(--text-700); font-family:inherit; }
.spouse-result span, .spouse-result small { display:block; }
.spouse-result b { font-size:12px; color:var(--text-900); }
.spouse-result small { margin-top:2px; color:var(--text-500); font-size:10.5px; }
.spouse-result.selected { border-color:var(--blue-500); background:var(--blue-50); color:var(--blue-600); }
.credential-card { border:1px solid var(--border); border-radius:var(--radius-sm); margin-top:10px; }
@media (max-width:700px) { .spouse-mode-grid { grid-template-columns:1fr; } }
</style>
