<template>
  <div v-if="patient">
    <div class="page-header">
      <div><h1>Clinical Visit Documentation</h1><div class="desc">{{ fmtDate(new Date()) }} · Routine Monitoring</div></div>
      <div class="page-actions">
        <select class="input" :value="patient.patient_id" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
      </div>
    </div>
    <div class="grid" style="grid-template-columns:220px 1fr; gap:20px; align-items:start;">
      <div style="display:flex; flex-direction:column; gap:14px;">
        <div class="card card-pad">
          <div style="text-align:center;"><Avatar :name="patient.full_name" :size="54" /><div style="font-weight:700; margin-top:10px;">{{ patient.full_name }}</div><div class="cell-muted">{{ patient.patient_id }}</div></div>
          <div style="margin-top:16px; display:flex; flex-direction:column; gap:2px;">
            <div
              v-for="(s, i) in steps"
              :key="s"
              class="nav-item"
              :style="{ color: i === step ? 'var(--blue-600)' : 'var(--text-500)', background: i === step ? 'var(--blue-50)' : 'transparent' }"
              @click="step = i"
            >
              <Icon :name="i < step ? 'check-circle' : 'clock'" :size="14" /> {{ s }}
            </div>
          </div>
        </div>

        <div class="card card-pad">
          <b style="font-size:12px;"><Icon name="user" :size="11" /> Spouse / Partner</b>
          <template v-if="patient.spouse_patient_id">
            <p style="font-size:12.5px; margin-top:6px;">{{ spouseName || 'Linked patient' }}</p>
            <span class="link" style="font-size:11.5px;" @click="unlinkSpouse">Unlink</span>
          </template>
          <template v-else>
            <input v-model="spouseSearch" class="input" style="font-size:12px; margin-top:8px;" placeholder="Search by name or ID…" @input="searchSpouse" />
            <div v-if="spouseResults.length" style="margin-top:6px; display:flex; flex-direction:column; gap:4px;">
              <div v-for="r in spouseResults" :key="r.patient_id" class="link" style="font-size:12px;" @click="linkSpouse(r.patient_id)">{{ r.full_name }} ({{ r.patient_id }})</div>
            </div>
          </template>
        </div>

        <div class="card card-pad">
          <b style="font-size:12px;"><Icon name="file" :size="11" /> Signed Consent Form</b>
          <template v-if="patient.consent_form_url">
            <button class="btn btn-secondary btn-sm btn-block" style="margin-top:8px;" :disabled="viewingConsent" @click="viewConsent"><Icon name="eye" :size="11" /> View on File</button>
          </template>
          <template v-else>
            <input ref="consentFileInput" type="file" accept="application/pdf,image/*" style="font-size:11px; margin-top:8px;" @change="onConsentFileChosen" />
            <button class="btn btn-secondary btn-sm btn-block" style="margin-top:6px;" :disabled="!consentFile || uploadingConsent" @click="uploadConsent"><Icon name="upload" :size="11" /> Upload</button>
          </template>
        </div>
      </div>

      <div class="card card-pad">
        <b style="font-size:14.5px;">{{ steps[step] }}</b>
        <p class="cell-muted" style="margin-top:4px; margin-bottom:14px;">Document patient condition and detailed observations for this visit.</p>

        <template v-if="step === 0">
          <div class="form-row">
            <div class="field"><label>Blood Pressure — Systolic</label><input v-model="vitals.bpSystolic" class="input" type="number" placeholder="120" /></div>
            <div class="field"><label>Blood Pressure — Diastolic</label><input v-model="vitals.bpDiastolic" class="input" type="number" placeholder="80" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Temperature (°C)</label><input v-model="vitals.temperature" class="input" type="number" step="0.1" placeholder="36.8" /></div>
            <div class="field"><label>Pulse (bpm)</label><input v-model="vitals.pulse" class="input" type="number" placeholder="76" /></div>
          </div>
          <div class="form-row">
            <div class="field"><label>SpO₂ (%)</label><input v-model="vitals.spo2" class="input" type="number" placeholder="98" /></div>
            <div class="field"></div>
          </div>
          <div class="form-row">
            <div class="field"><label>Height (cm)</label><input v-model="vitals.height" class="input" type="number" step="0.1" placeholder="165" /></div>
            <div class="field"><label>Weight (kg)</label><input v-model="vitals.weight" class="input" type="number" step="0.1" placeholder="62" /></div>
          </div>
          <p v-if="bmi" class="cell-muted">BMI: <b style="color:var(--text-900);">{{ bmi }}</b></p>
        </template>

        <template v-else-if="step === 1">
          <div class="field"><label>Patient Condition</label><select v-model="condition" class="input"><option>Stable</option><option>Needs Review</option></select></div>
          <div class="field"><label>Detailed Nursing Notes</label><textarea v-model="nursingNotes" class="input" rows="4" placeholder="Observations, complaints, response to treatment…" /></div>
        </template>

        <template v-else-if="step === 2">
          <b style="font-size:12.5px;">Prescribe Medication / Injection</b>
          <div class="form-row" style="margin-top:8px;">
            <div class="field"><label>Medication</label><input v-model="rxMed" class="input" placeholder="e.g. Gonal-F 150 IU" /></div>
            <div class="field"><label>Sig / Dosage Instructions</label><input v-model="rxSig" class="input" placeholder="e.g. Inject SubQ this evening" /></div>
          </div>
          <button class="btn btn-secondary btn-sm" @click="addPrescription"><Icon name="plus" :size="12" /> Add to Patient's Prescriptions</button>
          <div style="margin-top:14px;">
            <p v-if="!existingRx.length" class="muted" style="font-size:12px;">No prescriptions logged yet for this visit.</p>
            <div v-for="r in existingRx" :key="r.id" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm); padding:8px 10px; margin-bottom:6px;">
              <div style="font-size:12.5px; font-weight:600;">{{ r.medication }}</div>
              <div class="cell-muted">{{ r.sig }} · <StatusBadge :status="r.status" /></div>
            </div>
          </div>
        </template>

        <div v-else class="field"><label>Post-Visit Instructions for Patient</label><textarea v-model="postVisitInstructions" class="input" rows="4" placeholder="Instructions communicated to patient…" /></div>

        <div class="flex-between" style="margin-top:20px;">
          <span />
          <button v-if="step < 3" class="btn btn-primary" :disabled="saving" @click="saveAndProceed">Save &amp; Proceed <Icon name="arrow-right" :size="13" /></button>
          <button v-else class="btn btn-success" :disabled="saving" @click="finalize"><Icon name="check-circle" :size="13" /> Finalize Visit</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()
const route = useRoute()
const router = useRouter()

const steps = ['Triage & Vitals', 'Nursing Assessment', 'Medication Admin', 'Post-Visit Instructions']
const step = ref(0)
const patients = ref<any[]>([])
const patient = ref<any>(null)
const existingRx = ref<any[]>([])
const rxMed = ref('')
const rxSig = ref('')
const saving = ref(false)
const visitId = ref<string | null>(null)
const activeCycleId = ref<string | null>(null)

const vitals = reactive({ bpSystolic: '', bpDiastolic: '', temperature: '', pulse: '', spo2: '', height: '', weight: '' })
const condition = ref('Stable')
const nursingNotes = ref('')
const postVisitInstructions = ref('')

const bmi = computed(() => {
  const h = Number(vitals.height)
  const w = Number(vitals.weight)
  if (!h || !w) return null
  return (w / (h / 100) ** 2).toFixed(1)
})

function resetForm() {
  step.value = 0
  visitId.value = null
  Object.assign(vitals, { bpSystolic: '', bpDiastolic: '', temperature: '', pulse: '', spo2: '', height: '', weight: '' })
  condition.value = 'Stable'
  nursingNotes.value = ''
  postVisitInstructions.value = ''
}

async function loadPatient(patientId: string) {
  const [bioRes, rxRes, cycleRes] = await Promise.all([
    supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', patientId).single(),
    supabase.from('prescriptions').select('*').eq('patient_id', patientId).neq('status', 'Cancelled').order('date', { ascending: false }),
    supabase.from('cycles').select('id').eq('patient_id', patientId).neq('status', 'Closed').order('start_date', { ascending: false }).limit(1).maybeSingle(),
  ])
  patient.value = bioRes.data ? { ...bioRes.data, full_name: bioRes.data.patient_names?.full_name } : null
  existingRx.value = rxRes.data || []
  activeCycleId.value = cycleRes.data?.id || null
  spouseName.value = ''
  if (patient.value?.spouse_patient_id) {
    const { data } = await supabase.from('patient_names').select('full_name').eq('patient_id', patient.value.spouse_patient_id).maybeSingle()
    spouseName.value = data?.full_name || ''
  }
}

await useAsyncData('nurse-visit-init', async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  const startId = (route.query.patient as string) || patients.value[0]?.patient_id
  if (startId) await loadPatient(startId)
  return true
})

function switchPatient(patientId: string) {
  resetForm()
  router.replace({ query: { ...route.query, patient: patientId } })
  loadPatient(patientId)
}

// Saved incrementally (upserted on every "Save & Proceed", not only at the
// end) — a nurse stepping away mid-visit shouldn't lose vitals already
// entered. visitId tracks the in-progress row across steps within this
// session; a fresh patient switch starts a new one (see resetForm/switchPatient).
async function persistVisit() {
  if (!patient.value) return
  const targetPatientId = patient.value.patient_id
  const targetCycleId = activeCycleId.value
  const documentedBy = profile.value!.id
  const payload: any = {
    patient_id: targetPatientId,
    cycle_id: targetCycleId,
    documented_by: documentedBy,
    bp_systolic: vitals.bpSystolic === '' ? null : Number(vitals.bpSystolic),
    bp_diastolic: vitals.bpDiastolic === '' ? null : Number(vitals.bpDiastolic),
    temperature_c: vitals.temperature === '' ? null : Number(vitals.temperature),
    pulse_bpm: vitals.pulse === '' ? null : Number(vitals.pulse),
    spo2_pct: vitals.spo2 === '' ? null : Number(vitals.spo2),
    height_cm: vitals.height === '' ? null : Number(vitals.height),
    weight_kg: vitals.weight === '' ? null : Number(vitals.weight),
    condition: condition.value,
    nursing_notes: nursingNotes.value,
    post_visit_instructions: postVisitInstructions.value,
  }
  if (visitId.value) {
    const { error } = await supabase.from('nurse_visits').update(payload).eq('id', visitId.value)
    if (error) throw error
  } else {
    const { data, error } = await supabase.from('nurse_visits').insert(payload).select('id').single()
    if (error) throw error
    visitId.value = data.id
  }
}

async function saveAndProceed() {
  saving.value = true
  try {
    await persistVisit()
    toast('Progress saved', 'success')
    step.value++
  } catch {
    toast('Could not save — please try again', 'warn')
  }
  saving.value = false
}

async function addPrescription() {
  if (!patient.value) return
  const med = rxMed.value || 'Medication'
  const sig = rxSig.value || 'As directed'
  const targetPatientId = patient.value.patient_id
  const prescribedBy = profile.value!.id
  await queueOrRun(`${med} logged for ${patient.value.full_name}`, async () => {
    const { data, error } = await supabase
      .from('prescriptions')
      .insert({
        patient_id: targetPatientId,
        prescribed_by_profile_id: prescribedBy,
        prescribed_by_role: 'nurse',
        medication: med,
        sig,
      })
      .select()
      .single()
    if (error) throw error
    if (patient.value?.patient_id === targetPatientId) existingRx.value = [data, ...existingRx.value]
  })
  rxMed.value = ''
  rxSig.value = ''
}

async function finalize() {
  saving.value = true
  try {
    await persistVisit()
    toast('Visit finalized', 'success')
    resetForm()
    router.push('/nurse/overview')
  } catch {
    toast('Could not finalize — please try again', 'warn')
  }
  saving.value = false
}

// ---- Spouse / partner linking ----
const spouseName = ref('')
const spouseSearch = ref('')
const spouseResults = ref<any[]>([])
let spouseSearchTimer: ReturnType<typeof setTimeout> | null = null

function searchSpouse() {
  if (spouseSearchTimer) clearTimeout(spouseSearchTimer)
  const q = spouseSearch.value.trim()
  if (!q) {
    spouseResults.value = []
    return
  }
  spouseSearchTimer = setTimeout(async () => {
    const { data } = await supabase.from('patient_names').select('patient_id, full_name').ilike('full_name', `%${q}%`).limit(5)
    spouseResults.value = (data || []).filter((r: any) => r.patient_id !== patient.value?.patient_id)
  }, 300)
}

async function linkSpouse(spouseId: string) {
  if (!patient.value) return
  const targetPatientId = patient.value.patient_id
  const { error } = await supabase.from('bio_details').update({ spouse_patient_id: spouseId }).eq('patient_id', targetPatientId)
  if (error) {
    toast('Could not link partner', 'warn')
    return
  }
  patient.value.spouse_patient_id = spouseId
  spouseSearch.value = ''
  spouseResults.value = []
  const { data } = await supabase.from('patient_names').select('full_name').eq('patient_id', spouseId).maybeSingle()
  spouseName.value = data?.full_name || ''
  toast('Partner linked', 'success')
}

async function unlinkSpouse() {
  if (!patient.value) return
  const targetPatientId = patient.value.patient_id
  const { error } = await supabase.from('bio_details').update({ spouse_patient_id: null }).eq('patient_id', targetPatientId)
  if (error) return
  patient.value.spouse_patient_id = null
  spouseName.value = ''
}

// ---- Signed consent form ----
const consentFileInput = ref<HTMLInputElement | null>(null)
const consentFile = ref<File | null>(null)
const uploadingConsent = ref(false)
const viewingConsent = ref(false)

function onConsentFileChosen(e: Event) {
  consentFile.value = (e.target as HTMLInputElement).files?.[0] || null
}

async function uploadConsent() {
  if (!patient.value || !consentFile.value) return
  uploadingConsent.value = true
  const targetPatientId = patient.value.patient_id
  const path = `${targetPatientId}/${Date.now()}-${consentFile.value.name}`
  const { error: upErr } = await supabase.storage.from('consent-forms').upload(path, consentFile.value)
  if (upErr) {
    toast('Could not upload the consent form', 'warn')
    uploadingConsent.value = false
    return
  }
  const { error } = await supabase.from('bio_details').update({ consent_form_url: path }).eq('patient_id', targetPatientId)
  uploadingConsent.value = false
  if (error) {
    toast('Uploaded, but could not save the reference — please retry', 'warn')
    return
  }
  patient.value.consent_form_url = path
  consentFile.value = null
  toast('Consent form on file', 'success')
}

async function viewConsent() {
  if (!patient.value?.consent_form_url) return
  viewingConsent.value = true
  const { data, error } = await supabase.storage.from('consent-forms').createSignedUrl(patient.value.consent_form_url, 60)
  viewingConsent.value = false
  if (error || !data?.signedUrl) {
    toast("Couldn't open the consent form", 'warn')
    return
  }
  window.open(data.signedUrl, '_blank')
}
</script>
