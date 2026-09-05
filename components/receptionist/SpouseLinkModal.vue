<template>
  <Modal :model-value="modelValue" title="Link Spouse / Partner" @update:model-value="close">
    <template v-if="credential">
      <div class="empty-state" style="padding:4px 0 12px;">
        <div class="icon-wrap"><Icon name="check-circle" :size="21" /></div>
        <h4>Spouse registered and linked</h4>
        <p>Give these temporary login details directly to {{ credential.name }}. The password is shown only once.</p>
      </div>
      <div class="credential-box">
        <div><span>Patient ID</span><b class="mono">{{ credential.patientId }}</b></div>
        <div><span>Temporary password</span><b class="mono">{{ credential.password }}</b></div>
      </div>
    </template>
    <template v-else>
      <p class="cell-muted" style="margin-bottom:14px;">Connect {{ patientName }} to an existing unlinked patient, or register their partner now.</p>
      <div class="mode-grid">
        <button type="button" :class="['mode-button', { active: mode === 'existing' }]" @click="mode = 'existing'"><b>Link existing patient</b><span>Choose someone already registered</span></button>
        <button type="button" :class="['mode-button', { active: mode === 'new' }]" @click="mode = 'new'"><b>Register new spouse</b><span>Create a patient and link both records</span></button>
      </div>

      <div v-if="mode === 'existing'" class="field" style="margin-top:15px;">
        <label>Find Patient</label>
        <input v-model="search" class="input" placeholder="Search by name or patient ID" />
        <div class="result-list">
          <button v-for="entry in filteredPatients" :key="entry.patient_id" type="button" :class="['patient-result', { selected: existingSpouseId === entry.patient_id }]" @click="existingSpouseId = entry.patient_id">
            <span><b>{{ entry.full_name }}</b><small>{{ entry.patient_id }} · {{ entry.sex || 'Sex not recorded' }}</small></span>
            <Icon :name="existingSpouseId === entry.patient_id ? 'check-circle' : 'chevron-right'" :size="14" />
          </button>
          <p v-if="!loadingDirectory && !filteredPatients.length" class="cell-muted" style="padding:10px 2px;">No available unlinked patient matches this search.</p>
        </div>
      </div>

      <div v-else class="new-spouse-form">
        <PatientPhotoPicker v-model="photoFile" :patient-name="`${partner.first} ${partner.last}`.trim()" />
        <div class="form-row" style="margin-top:13px;">
          <div class="field"><label>Legal First Name</label><input v-model="partner.first" class="input" /></div>
          <div class="field"><label>Surname</label><input v-model="partner.last" class="input" /></div>
        </div>
        <div class="form-row">
          <div class="field"><label>Date of Birth</label><input v-model="partner.dob" class="input" type="date" /></div>
          <div class="field"><label>Sex at Birth</label><select v-model="partner.sex" class="input"><option>F</option><option>M</option><option>Other</option><option>Unknown</option></select></div>
        </div>
        <div class="form-row">
          <div class="field"><label>Phone</label><input v-model="partner.phone" class="input" /></div>
          <div class="field"><label>Email</label><input v-model="partner.email" class="input" type="email" /></div>
        </div>
        <div class="field"><label>Home Address</label><textarea v-model="partner.address" class="input" rows="2" /></div>
        <div class="checkbox-row"><input id="spouse-consent" v-model="consent" type="checkbox" /><label for="spouse-consent">The new patient has agreed to the Data Privacy &amp; Medical Consent terms.</label></div>
      </div>
    </template>

    <template #footer>
      <button v-if="credential" class="btn btn-primary" @click="close">Done</button>
      <template v-else>
        <button class="btn btn-secondary" :disabled="submitting" @click="close">Cancel</button>
        <button class="btn btn-primary" :disabled="submitting" @click="submitLink"><Icon name="users" :size="13" /> {{ submitting ? 'Linking…' : mode === 'new' ? 'Register & Link' : 'Link Spouse' }}</button>
      </template>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { uploadPatientPhoto } from '~/composables/usePatientPhoto'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ modelValue: boolean; patientId: string; patientName: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; linked: [string] }>()
const supabase = useSupabaseClient()
const { toast } = useToast()
const mode = ref<'existing' | 'new'>('existing')
const search = ref('')
const directory = ref<any[]>([])
const loadingDirectory = ref(false)
const existingSpouseId = ref('')
const submitting = ref(false)
const consent = ref(false)
const photoFile = ref<File | null>(null)
const credential = ref<{ patientId: string; name: string; password: string } | null>(null)
const partner = reactive({ first: '', last: '', dob: '', sex: 'M', phone: '', email: '', address: '', referral_source: 'Linked spouse' })

const filteredPatients = computed(() => {
  const query = search.value.trim().toLowerCase()
  return directory.value
    .filter(entry => entry.patient_id !== props.patientId)
    .filter(entry => !query || `${entry.full_name} ${entry.patient_id}`.toLowerCase().includes(query))
    .slice(0, 10)
})

async function loadDirectory() {
  loadingDirectory.value = true
  const { data, error } = await supabase.rpc('reception_spouse_directory', { p_search: '' })
  directory.value = data || []
  loadingDirectory.value = false
  if (error) toast('Could not load the available spouse directory.', 'warn')
}

function reset() {
  mode.value = 'existing'
  search.value = ''
  existingSpouseId.value = ''
  consent.value = false
  photoFile.value = null
  credential.value = null
  Object.assign(partner, { first: '', last: '', dob: '', sex: 'M', phone: '', email: '', address: '', referral_source: 'Linked spouse' })
}

function close() {
  emit('update:modelValue', false)
  reset()
}

async function submitLink() {
  if (mode.value === 'existing' && !existingSpouseId.value) {
    toast('Select an existing patient to link.', 'warn')
    return
  }
  if (mode.value === 'new' && (!partner.first.trim() || !partner.last.trim() || !partner.dob)) {
    toast('First name, surname, and date of birth are required for the new spouse.', 'warn')
    return
  }
  if (mode.value === 'new' && !consent.value) {
    toast('Confirm the new patient’s registration consent before continuing.', 'warn')
    return
  }

  submitting.value = true
  const { data, error } = await supabase.rpc('link_or_register_patient_spouse', {
    p_patient_id: props.patientId,
    p_existing_spouse_id: mode.value === 'existing' ? existingSpouseId.value : null,
    p_new_spouse: mode.value === 'new' ? { ...partner } : null,
  })
  if (error || !data?.spouse_patient_id) {
    submitting.value = false
    toast(error?.message || 'Could not link the spouse.', 'warn')
    return
  }

  const spouseId = data.spouse_patient_id as string
  emit('linked', spouseId)
  if (!data.spouse_created) {
    submitting.value = false
    toast('Both patient records are now linked as spouses.', 'success')
    close()
    return
  }

  const consentResult = await supabase.rpc('record_registration_consent', { p_patient_id: spouseId })
  if (consentResult.error) toast('The spouse was registered, but the consent timestamp could not be recorded.', 'warn')
  if (photoFile.value) {
    try { await uploadPatientPhoto(supabase, spouseId, photoFile.value) }
    catch (photoError: any) { toast(photoError?.message || 'The spouse was registered, but their picture could not be saved.', 'warn') }
  }

  try {
    const account = await $fetch<{ tempPassword?: string; alreadyExists?: boolean }>('/api/receptionist/create-patient-account', { method: 'POST', body: { patientId: spouseId } })
    if (account.tempPassword) {
      credential.value = { patientId: spouseId, name: data.spouse_name || `${partner.first} ${partner.last}`.trim(), password: account.tempPassword }
    } else {
      toast('The spouse was registered and linked, but their portal account already existed.', 'warn')
      close()
    }
  } catch {
    toast('The spouse was registered and linked, but the portal login could not be created. Ask Admin to set it up.', 'warn')
    close()
  } finally {
    submitting.value = false
  }
}

watch(() => props.modelValue, (open) => {
  if (open) void loadDirectory()
  else reset()
})
</script>

<style scoped>
.mode-grid { display:grid; grid-template-columns:1fr 1fr; gap:10px; }
.mode-button { padding:12px; border:1px solid var(--border-strong); border-radius:var(--radius-sm); background:#fff; text-align:left; color:var(--text-700); font-family:inherit; }
.mode-button b, .mode-button span { display:block; }.mode-button b { font-size:12.5px; color:var(--text-900); }.mode-button span { margin-top:4px; color:var(--text-500); font-size:10.5px; }
.mode-button.active { border-color:var(--blue-500); background:var(--blue-50); }
.result-list { display:flex; flex-direction:column; gap:6px; max-height:250px; overflow:auto; margin-top:8px; }
.patient-result { display:flex; align-items:center; justify-content:space-between; width:100%; padding:10px 11px; border:1px solid var(--border); border-radius:8px; background:#fff; text-align:left; font-family:inherit; }
.patient-result span, .patient-result small { display:block; }.patient-result b { font-size:12px; }.patient-result small { margin-top:2px; color:var(--text-500); font-size:10.5px; }.patient-result.selected { border-color:var(--blue-500); background:var(--blue-50); }
.new-spouse-form { margin-top:15px; padding:13px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }
.credential-box { display:flex; flex-direction:column; gap:11px; padding:14px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }.credential-box span { display:block; margin-bottom:3px; color:var(--text-500); font-size:9.5px; text-transform:uppercase; }
@media (max-width:600px) { .mode-grid { grid-template-columns:1fr; } }
</style>
