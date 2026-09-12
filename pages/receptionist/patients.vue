<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Patients</h1>
        <div class="desc">{{ patients.length }} patients registered</div>
      </div>
      <div class="page-actions">
        <button class="btn btn-primary" @click="$router.push('/receptionist/register')"><Icon name="plus" :size="14" /> New Patient</button>
      </div>
    </div>

    <div class="card">
      <div style="padding:14px 20px; border-bottom:1px solid var(--border);">
        <div class="search-box" style="max-width:320px;">
          <Icon name="search" :size="14" />
          <input v-model="search" placeholder="Search name or ID…" />
        </div>
      </div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>ID</th><th>Age</th><th>Status</th><th>Assigned Doctor</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.patient_id" class="clickable" @click="openProfile(p.patient_id)">
            <td class="cell-strong">{{ p.full_name }}</td>
            <td class="cell-muted mono">{{ p.patient_id }}</td>
            <td>{{ computeAge(p.dob) }}</td>
            <td><StatusBadge :status="p.status" /></td>
            <td class="cell-muted">{{ doctorNames[p.assigned_doctor_id] || '—' }}</td>
            <td style="text-align:right;"><Icon name="chevron-right" :size="14" /></td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal v-model="showProfile" :title="activeProfile?.full_name || ''">
      <template v-if="activeProfile">
        <div class="patient-profile-hero">
          <div class="patient-profile-photo">
            <img v-if="activePhotoUrl" :src="activePhotoUrl" :alt="`${activeProfile.full_name} patient picture`" />
            <Avatar v-else :name="activeProfile.full_name" :size="68" />
          </div>
          <div class="grid grid-4 patient-profile-facts">
            <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.patient_id }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(activeProfile.dob) }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.blood_group || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="activeProfile.status" /></div>
          </div>
        </div>
        <div class="card-pad" style="padding:10px 12px; background:var(--bg); border-radius:var(--radius-sm);">
          <div class="grid grid-4" style="gap:10px;">
            <div><div class="muted" style="font-size:10.5px;">SEX</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.sex || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">REGISTERED</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.registered_on || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">REFERRAL SOURCE</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.referral_source || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">REGISTRATION CONSENT</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.registration_consent_at ? 'Confirmed' : 'Not recorded' }}</div></div>
          </div>
        </div>
        <hr class="hr" />
        <b style="font-size:13px;">Contact</b>
        <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);"><Icon name="phone" :size="11" /> {{ activeProfile.phone || '—' }} &nbsp; <Icon name="mail" :size="11" /> {{ activeProfile.email || '—' }}</p>
        <p style="font-size:12.5px; color:var(--text-700);">{{ activeProfile.address || '—' }}</p>
        <div class="whatsapp-card">
          <div class="field"><label>WhatsApp reminder number</label><input v-model="activeProfile.whatsapp_phone" class="input" placeholder="e.g. +2348012345678" /></div>
          <label class="checkbox-row"><input v-model="activeProfile.whatsapp_opt_in" type="checkbox" /><span>Patient has agreed to receive care reminders on WhatsApp.</span></label>
          <button class="btn btn-secondary btn-sm" :disabled="savingWhatsapp" @click="saveWhatsapp"><Icon name="check-circle" :size="12" /> {{ savingWhatsapp ? 'Saving…' : 'Save WhatsApp preference' }}</button>
        </div>
        <template v-if="activeProfile.spouse_patient_id">
          <hr class="hr" />
          <b style="font-size:13px;">Spouse / Partner</b>
          <button type="button" class="linked-spouse-card" @click="openProfile(activeProfile.spouse_patient_id)">
            <span><b>{{ activeProfile.spouse_name || 'Linked patient' }}</b><small>{{ activeProfile.spouse_patient_id }}</small></span>
            <span class="link">View patient details <Icon name="chevron-right" :size="12" /></span>
          </button>
        </template>
        <template v-else>
          <hr class="hr" />
          <div class="flex-between" style="gap:12px; align-items:center;">
            <div><b style="font-size:13px;">Spouse / Partner</b><p class="hint" style="margin-top:3px;">No spouse is linked to this patient.</p></div>
            <button type="button" class="btn btn-secondary btn-sm" @click="openSpouseLink"><Icon name="users" :size="12" /> Link Spouse</button>
          </div>
        </template>
        <hr class="hr" />
        <b style="font-size:13px;">Emergency Contact</b>
        <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
          {{ activeProfile.emergency_contact?.name || '—' }} ({{ activeProfile.emergency_contact?.relationship || '—' }}) · {{ activeProfile.emergency_contact?.phone || '—' }}
        </p>
        <hr class="hr" />
        <b style="font-size:13px;">Patient Portal Login</b>
        <div class="portal-access-card">
          <div><span>Login ID</span><b class="mono">{{ activeProfile.patient_id }}</b></div>
          <div><span>Portal account</span><b>{{ activeProfile.portal_login_exists ? (activeProfile.portal_login_active ? 'Active' : 'Inactive') : 'Not created' }}</b></div>
          <button class="btn btn-secondary btn-sm" :disabled="resettingPassword || !activeProfile.portal_login_exists || !activeProfile.portal_login_active" @click="resetPatientPassword">
            <Icon name="lock" :size="12" /> {{ resettingPassword ? 'Resetting…' : 'Reset Password' }}
          </button>
        </div>
        <p class="hint" style="margin-top:6px;">Passwords are never displayed or stored here. A reset creates a one-time temporary password.</p>
      </template>
      <template #footer>
        <button class="btn btn-secondary" @click="showProfile = false">Close</button>
        <button class="btn btn-primary" @click="showProfile = false; $router.push('/receptionist/book')"><Icon name="calendar" :size="13" /> Book Visit</button>
      </template>
    </Modal>

    <SpouseLinkModal
      :model-value="showSpouseLink"
      :patient-id="spouseLinkTarget.patientId"
      :patient-name="spouseLinkTarget.patientName"
      @update:model-value="handleSpouseLinkVisibility"
      @linked="handleSpouseLinked"
    />

    <Modal :model-value="!!resetCredential" title="Temporary Patient Password" @update:model-value="closeResetCredential">
      <div v-if="resetCredential">
        <div class="empty-state" style="padding:4px 0 12px;">
          <div class="icon-wrap"><Icon name="lock" :size="21" /></div>
          <h4>Password reset successfully</h4>
          <p>Give this temporary password directly to {{ resetCredential.patientName }}. It is shown only once and must be changed at the next login.</p>
        </div>
        <div class="credential-box">
          <div><span>Patient ID</span><b class="mono">{{ resetCredential.patientId }}</b></div>
          <div><span>Temporary password</span><b class="mono">{{ resetCredential.temporaryPassword }}</b></div>
        </div>
      </div>
      <template #footer><button class="btn btn-primary" @click="closeResetCredential">Done</button></template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { computeAge } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { fetchPatientPhotoUrl } from '~/composables/usePatientPhoto'

const supabase = useSupabaseClient()
const route = useRoute()
const { toast } = useToast()
const search = ref('')
const patients = ref<any[]>([])
const doctorNames = ref<Record<string, string>>({})
const showProfile = ref(false)
const activeProfile = ref<any>(null)
const activePhotoUrl = ref('')
const showSpouseLink = ref(false)
const spouseLinkTarget = ref({ patientId: '', patientName: '' })
const resettingPassword = ref(false)
const resetCredential = ref<{ patientId: string; patientName: string; temporaryPassword: string } | null>(null)
const savingWhatsapp = ref(false)

await useAsyncData('receptionist-patients', async () => {
  const [patientsRes, doctorsRes] = await Promise.all([
    supabase.rpc('patients_front_desk_directory', { p_search: '' }),
    supabase.from('profiles').select('id, full_name').eq('role', 'doctor'),
  ])
  patients.value = patientsRes.data || []
  doctorNames.value = Object.fromEntries((doctorsRes.data || []).map((d: any) => [d.id, d.full_name]))
  return true
})

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((p) => (p.full_name + p.patient_id).toLowerCase().includes(q))
})

async function openProfile(patientId: string) {
  activePhotoUrl.value = ''
  const [{ data, error }, photoUrl] = await Promise.all([
    supabase.rpc('patient_front_desk_profile_v2', { p_patient_id: patientId }),
    fetchPatientPhotoUrl(supabase, patientId),
  ])
  if (error) {
    const fallback = await supabase.rpc('patient_front_desk_profile', { p_patient_id: patientId })
    activeProfile.value = fallback.data?.[0] || null
  } else {
    activeProfile.value = data || null
  }
  activePhotoUrl.value = photoUrl
  showProfile.value = true
}

function openSpouseLink() {
  if (!activeProfile.value?.patient_id) return
  spouseLinkTarget.value = { patientId: activeProfile.value.patient_id, patientName: activeProfile.value.full_name }
  showProfile.value = false
  showSpouseLink.value = true
}

function handleSpouseLinked(spouseId: string) {
  if (activeProfile.value) activeProfile.value.spouse_patient_id = spouseId
}

function handleSpouseLinkVisibility(open: boolean) {
  showSpouseLink.value = open
  if (!open && spouseLinkTarget.value.patientId) void openProfile(spouseLinkTarget.value.patientId)
}

async function resetPatientPassword() {
  if (!activeProfile.value?.patient_id || resettingPassword.value) return
  if (!window.confirm(`Reset the portal password for ${activeProfile.value.full_name}? Their current password will stop working immediately.`)) return
  resettingPassword.value = true
  try {
    resetCredential.value = await $fetch<{ patientId: string; patientName: string; temporaryPassword: string }>('/api/receptionist/reset-patient-password', {
      method: 'POST',
      body: { patientId: activeProfile.value.patient_id },
    })
  } catch (error: any) {
    toast(error?.data?.statusMessage || error?.statusMessage || 'Could not reset the patient password.', 'warn')
  } finally {
    resettingPassword.value = false
  }
}

function closeResetCredential() {
  resetCredential.value = null
}

async function saveWhatsapp() {
  if (!activeProfile.value?.patient_id) return
  if (activeProfile.value.whatsapp_opt_in && !String(activeProfile.value.whatsapp_phone || '').trim()) return toast('Enter a WhatsApp number before enabling reminders.', 'warn')
  savingWhatsapp.value = true
  const { error } = await supabase.from('bio_details').update({ whatsapp_phone: String(activeProfile.value.whatsapp_phone || '').trim() || null, whatsapp_opt_in: Boolean(activeProfile.value.whatsapp_opt_in) }).eq('patient_id', activeProfile.value.patient_id)
  savingWhatsapp.value = false
  if (error) return toast(error.message.includes('whatsapp_') ? 'Run the latest WhatsApp database migration first.' : error.message, 'warn')
  toast('WhatsApp reminder preference saved.', 'success')
}

watch(() => route.query.patient, (patientId) => {
  if (typeof patientId === 'string') void openProfile(patientId)
}, { immediate: true })
</script>

<style scoped>
.linked-spouse-card { display:flex; align-items:center; justify-content:space-between; gap:12px; width:100%; margin-top:8px; padding:11px 12px; border:1px solid var(--blue-100); border-radius:var(--radius-sm); background:var(--blue-50); text-align:left; font-family:inherit; }
.linked-spouse-card span, .linked-spouse-card small { display:block; }
.linked-spouse-card small { margin-top:3px; color:var(--text-500); font-size:10.5px; }
.linked-spouse-card .link { display:flex; align-items:center; gap:4px; color:var(--blue-600); font-size:11px; font-weight:700; white-space:nowrap; }
.patient-profile-hero { display:flex; align-items:center; gap:15px; margin-bottom:16px; }
.patient-profile-photo { width:72px; height:72px; flex:0 0 72px; overflow:hidden; border:3px solid #fff; border-radius:50%; background:#fff; box-shadow:0 0 0 1px var(--border); }
.patient-profile-photo img { width:100%; height:100%; object-fit:cover; }
.patient-profile-facts { flex:1; gap:10px; }
.portal-access-card { display:grid; grid-template-columns:1fr 1fr auto; align-items:end; gap:12px; margin-top:8px; padding:11px 12px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }
.portal-access-card span, .credential-box span { display:block; margin-bottom:3px; color:var(--text-500); font-size:9.5px; text-transform:uppercase; }
.portal-access-card b, .credential-box b { font-size:12px; }
.credential-box { display:flex; flex-direction:column; gap:11px; padding:14px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }
.whatsapp-card { display:grid; grid-template-columns:minmax(180px,1fr) minmax(220px,1.4fr) auto; align-items:end; gap:10px; margin-top:12px; padding:11px 12px; border:1px solid var(--green-200); border-radius:var(--radius-sm); background:var(--green-50); }.whatsapp-card .field{margin:0}.whatsapp-card .checkbox-row{margin:0 0 5px}
@media (max-width:700px) { .portal-access-card,.whatsapp-card { grid-template-columns:1fr; }.patient-profile-hero { align-items:flex-start; }.patient-profile-facts { grid-template-columns:repeat(2,minmax(0,1fr)); } }
</style>
