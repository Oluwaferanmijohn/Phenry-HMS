<template>
  <div v-if="directoryStatus === 'pending' || loadingContext">
    <div class="page-header"><div><h1>Consultation</h1><div class="desc">Loading accessible patient information…</div></div></div>
    <div class="card card-pad"><div class="cell-muted">Loading consultation workspace…</div></div>
  </div>
  <div v-else-if="directoryError || contextError">
    <div class="page-header"><div><h1>Consultation</h1><div class="desc">The workspace could not be opened.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="alert" title="Consultation data could not be loaded" description="A temporary connection or permission error prevented the patient context from loading." />
      <div style="margin-top:12px; text-align:center;"><button class="btn btn-secondary btn-sm" @click="retryConsultation">Try Again</button></div>
    </div>
  </div>
  <div v-else-if="!patient">
    <div class="page-header"><div><h1>Consultation</h1><div class="desc">Select an accessible patient to begin.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="user" title="No accessible patients" description="No patient is currently assigned to this account or present in its permitted waiting-room scope." />
    </div>
  </div>
  <div v-else>
    <div class="page-header">
      <div><h1>Consultation — {{ patient.full_name }}</h1><div class="desc">{{ patient.patient_id }} · {{ fmtDate(new Date()) }}</div></div>
      <div class="page-actions">
        <select class="input" style="max-width:220px;" :value="patient.patient_id" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in allPatients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
        <button class="btn btn-secondary" @click="showFullHistory = true"><Icon name="clipboard" :size="13" /> Full History</button>
      </div>
    </div>

    <div class="grid" style="grid-template-columns: 1.6fr 1fr; gap:18px; align-items:start;">
      <div class="card">
        <div class="card-body">
          <div class="grid grid-4" style="margin-bottom:14px;">
            <div><div class="muted" style="font-size:10.5px;">BLOOD GRP</div><div style="font-weight:700; font-size:13px;">{{ patient.blood_group || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:700; font-size:13px;">{{ computeAge(patient.dob) }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">ALLERGIES</div><div style="font-weight:700; font-size:13px;" :style="{ color: patient.allergies?.length ? 'var(--red-600)' : 'var(--text-900)' }">{{ patient.allergies?.join(', ') || 'None' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">CYCLE</div><div style="font-weight:700; font-size:13px;">{{ cycle ? `${cycle.stage} · D${cycle.cycle_day}` : '—' }}</div></div>
          </div>

          <div v-if="cycle" class="cell-muted" style="margin-bottom:10px;"><Icon name="user" :size="11" /> Cycle Manager: <b style="color:var(--text-900);">{{ cycleManagerName || 'Unassigned' }}</b></div>

          <div v-if="cycle && cycle.status !== 'Closed'" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm); margin-bottom:14px;">
            <div class="flex-between">
              <b style="font-size:12.5px;"><Icon name="target" :size="12" /> Cycle Progress — {{ cycle.stage }}</b>
              <button class="btn btn-secondary btn-sm" @click="showCloseCycle = !showCloseCycle"><Icon name="check-circle" :size="12" /> Close Cycle</button>
            </div>
            <div class="flex gap-8" style="margin-top:8px;">
              <button v-if="nextStage" class="btn btn-secondary btn-sm" :disabled="advancingStage" @click="advanceStage">
                <Icon name="activity" :size="12" /> Advance to {{ nextStage }}
              </button>
              <span v-else class="cell-muted">Final stage reached — close the cycle to record an outcome.</span>
            </div>
            <div v-if="showCloseCycle" style="margin-top:10px; border-top:1px solid var(--border); padding-top:10px;">
              <div class="field">
                <label>Outcome</label>
                <select v-model="outcomeDraft" class="input">
                  <option value="">Select outcome…</option>
                  <option>Positive — Clinical Pregnancy</option>
                  <option>Positive — Biochemical Pregnancy</option>
                  <option>Negative — Not Pregnant</option>
                  <option>Cancelled — Poor Ovarian Response</option>
                  <option>Cancelled — OHSS Risk</option>
                  <option>Cancelled — Patient Withdrew</option>
                </select>
              </div>
              <button class="btn btn-primary btn-sm" :disabled="!outcomeDraft || closingCycle" @click="closeCycle"><Icon name="check-circle" :size="12" /> Confirm &amp; Close Cycle</button>
            </div>
          </div>
          <div v-else-if="cycle" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm); margin-bottom:14px; background:var(--bg);">
            <b style="font-size:12.5px;">Cycle Closed</b> — <span class="cell-muted">{{ cycle.outcome }}</span>
          </div>

          <b style="font-size:12.5px;">Findings &amp; Notes</b>
          <div class="tabs" style="margin:8px 0 10px;">
            <div class="tab" :class="{ active: consultType === 'Standard Consult' }" @click="consultType = 'Standard Consult'">Standard Consult</div>
            <div class="tab" :class="{ active: consultType === 'Follicular Tracking Scan' }" @click="consultType = 'Follicular Tracking Scan'">Follicular Tracking Scan</div>
            <div class="tab" :class="{ active: consultType === 'Post-Op Note' }" @click="consultType = 'Post-Op Note'">Post-Op Note</div>
          </div>
          <textarea v-model="notes" class="input" rows="7" :placeholder="notesPlaceholder" />
          <hr class="hr" />
          <b style="font-size:12.5px;">Diagnosis &amp; Treatment Plan</b>
          <div class="form-row" style="margin-top:8px;">
            <div class="field"><label>ICD-10 Code</label><input v-model="icd" class="input" placeholder="e.g. N97.9" /></div>
            <div class="field"><label>Diagnosis</label><input v-model="diagnosis" class="input" /></div>
          </div>
          <button class="btn btn-primary" :disabled="finalizing" @click="finalize"><Icon name="check-circle" :size="13" /> Finalize &amp; Save Consultation</button>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card card-pad">
          <div class="flex-between"><b style="font-size:13px;"><Icon name="pill" :size="13" /> Prescriptions</b><span class="link" @click="showRx = true"><Icon name="plus" :size="12" /></span></div>
          <div style="margin-top:10px; display:flex; flex-direction:column; gap:8px;">
            <p v-if="!prescriptions.length" class="muted" style="font-size:12px;">No active prescriptions.</p>
            <div v-for="r in prescriptions" :key="r.id" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm); padding:8px 10px;">
              <div style="font-size:12.5px; font-weight:600;">{{ r.medication }}</div><div class="cell-muted">{{ r.sig }}</div>
            </div>
          </div>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:10px;" @click="showRx = true"><Icon name="plus" :size="12" /> Add Medication</button>
        </div>

        <div v-if="cycle" class="card card-pad">
          <CycleDayChart :cycle-id="cycle.id" :start-date="cycle.start_date" :can-edit="false" />
        </div>

        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="flask" :size="13" /> Order Tests</b>
          <div style="margin-top:10px; display:flex; flex-direction:column; gap:8px; font-size:12.5px;">
            <label v-for="t in TEST_OPTIONS" :key="t" class="flex gap-8"><input v-model="orderedTests[t]" type="checkbox" /> {{ t }}</label>
          </div>
          <div v-if="pendingOrders.length" style="margin-top:10px; display:flex; flex-direction:column; gap:6px;">
            <div v-for="o in pendingOrders" :key="o.id" class="cell-muted" style="display:flex; align-items:center; gap:6px;">
              <Badge tone="amber">Ordered</Badge> {{ o.tests.join(', ') }}
            </div>
          </div>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:10px;" :disabled="sendingOrder" @click="sendToLab"><Icon name="flask" :size="12" /> Send to Lab</button>
        </div>

        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="siren" :size="13" /> Schedule Procedure</b>
          <p class="muted" style="font-size:11.5px; margin-top:4px;">OPU, Embryo Transfer, or another clinical procedure.</p>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:8px;" @click="showScheduleProcedure = true"><Icon name="plus" :size="12" /> Schedule Procedure</button>
        </div>

        <div v-if="props.role === 'doctor'" class="card card-pad">
          <b style="font-size:13px;"><Icon name="cash" :size="13" /> Payment Plan</b>
          <p class="muted" style="font-size:11.5px; margin-top:4px;">Generate or update this patient's treatment payment plan.</p>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:8px;" @click="router.push(`/doctor/billing?patient=${patient.patient_id}`)"><Icon name="arrow-right" :size="12" /> Open Payment Plan Generator</button>
        </div>

        <div v-if="caps.allowScheduleAppointment" class="card card-pad">
          <b style="font-size:13px;"><Icon name="calendar" :size="13" /> Schedule Next Appointment</b>
          <div class="field" style="margin-top:8px;"><label>Date</label><input v-model="followUpDate" class="input" type="date" /></div>
          <div class="field"><label>Time</label><input v-model="followUpTime" class="input" type="time" /></div>
          <button class="btn btn-secondary btn-block btn-sm" @click="scheduleFollowUp"><Icon name="plus" :size="12" /> Add to Schedule</button>
        </div>
      </div>
    </div>

    <RxModal v-model="showRx" :patient-id="patient.patient_id" :patient-name="patient.full_name" @added="onRxAdded" />
    <ScheduleProcedureModal v-model="showScheduleProcedure" :preselected-patient-id="patient.patient_id" />
    <PatientDetailModal v-model="showFullHistory" :patient="patient" :cycle="cycle" :consultations="pastConsultations" :lab-results="pastLabResults" :caps="{}" @open-spouse="$router.push(`/${role}/patients?patient=${$event}&linkedFrom=${patient.patient_id}`)" />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'
import { fetchClinicalPatientContext, fetchClinicalPatientDirectory } from '~/composables/useClinicalPatientAccess'
import { useRecentPatientCache } from '~/composables/useRecentPatientCache'

const { loadWithCache } = useRecentPatientCache()

const STAGES = ['Baseline', 'Stimulation', 'OPU', 'Transfer']
const TEST_OPTIONS = ['SFA (Semen Fluid Analysis)', 'Hormonal Panel (FSH, LH, E2)', 'Karyotype', 'Beta hCG (Quantitative)']

// Doctor: read-only on appointments per spec §2.2 (flagged in the Doctor
// migration) — no "Schedule Next Appointment" card for them. Matron gets it
// when that role is built.
const CONSULT_CAPS: Record<string, { allowScheduleAppointment?: boolean }> = {
  doctor: { allowScheduleAppointment: false },
  matron: { allowScheduleAppointment: true },
}

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()
const route = useRoute()
const router = useRouter()

const caps = computed(() => CONSULT_CAPS[props.role] || {})

const allPatients = ref<any[]>([])
const patient = ref<any>(null)
const cycle = ref<any>(null)
const cycleManagerName = ref('')
const prescriptions = ref<any[]>([])
const pastConsultations = ref<any[]>([])
const pastLabResults = ref<any[]>([])
const pendingOrders = ref<any[]>([])
const loadingContext = ref(false)
const contextError = ref('')

const notes = ref('')
const consultType = ref('Standard Consult')
const notesPlaceholder = computed(() => {
  if (consultType.value === 'Follicular Tracking Scan') return 'Scan findings — endometrial thickness, follicle counts and sizes, impression…'
  if (consultType.value === 'Post-Op Note') return 'Post-operative status — recovery, wound/incision check, complications, follow-up plan…'
  return 'Patient presents today for...'
})
const diagnosis = ref('')
const icd = ref('')
const finalizing = ref(false)
const showRx = ref(false)
const showScheduleProcedure = ref(false)
const showFullHistory = ref(false)

const orderedTests = reactive<Record<string, boolean>>(Object.fromEntries(TEST_OPTIONS.map((t) => [t, false])))
const sendingOrder = ref(false)

const showCloseCycle = ref(false)
const outcomeDraft = ref('')
const advancingStage = ref(false)
const closingCycle = ref(false)

const nextStage = computed(() => {
  if (!cycle.value || cycle.value.status === 'Closed') return null
  const idx = STAGES.indexOf(cycle.value.stage)
  return idx >= 0 && idx < STAGES.length - 1 ? STAGES[idx + 1] : null
})

const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
const followUpDate = ref(tomorrow)
const followUpTime = ref('09:00')

async function loadPatientContext(patientId: string) {
  if (!allPatients.value.some((entry) => entry.patient_id === patientId)) return
  loadingContext.value = true
  contextError.value = ''
  // Cached so a patient already opened once on this device can be reopened
  // offline — see useRecentPatientCache. The UI-state resets below (notes,
  // consultType, etc.) still run every time regardless of cache/online state.
  try {
    const { data } = await loadWithCache(patientId, async () => {
      return fetchClinicalPatientContext(supabase, patientId)
    })

    if (!data?.patient) throw new Error('Patient context is unavailable')
    patient.value = data.patient
    cycle.value = data.cycle || null
    cycleManagerName.value = data.cycleManagerName || ''
    prescriptions.value = data.prescriptions || []
    pastConsultations.value = data.pastConsultations || []
    pastLabResults.value = data.pastLabResults || []
    pendingOrders.value = data.pendingOrders || []

    notes.value = cycle.value?.physician_notes || ''
    consultType.value = 'Standard Consult'
    diagnosis.value = cycle.value ? `Infertility — undergoing ${cycle.value.type}` : ''
    icd.value = ''
    showCloseCycle.value = false
    outcomeDraft.value = ''
    TEST_OPTIONS.forEach((t) => (orderedTests[t] = false))
  } catch {
    patient.value = null
    cycle.value = null
    cycleManagerName.value = ''
    prescriptions.value = []
    pastConsultations.value = []
    pastLabResults.value = []
    pendingOrders.value = []
    contextError.value = 'Patient context could not be loaded.'
  } finally {
    loadingContext.value = false
  }
}

const consultationDirectoryKey = `consultation-directory-${profile.value?.id || 'anonymous'}-${props.role}`
const {
  data: directoryData,
  error: directoryError,
  status: directoryStatus,
  refresh: refreshDirectory,
} = await useAsyncData<any[]>(consultationDirectoryKey, async () => {
  const directory = await fetchClinicalPatientDirectory(supabase)
  return directory.patients
}, {
  default: () => [],
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

allPatients.value = directoryData.value || []
const requestedPatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
const initialPatientId = allPatients.value.some((entry) => entry.patient_id === requestedPatientId)
  ? requestedPatientId
  : allPatients.value[0]?.patient_id
if (initialPatientId) await loadPatientContext(initialPatientId)

async function retryConsultation() {
  contextError.value = ''
  await refreshDirectory()
  allPatients.value = directoryData.value || []
  if (directoryError.value) return
  const routePatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
  const nextPatientId = allPatients.value.some((entry) => entry.patient_id === routePatientId)
    ? routePatientId
    : allPatients.value[0]?.patient_id
  if (nextPatientId) await loadPatientContext(nextPatientId)
}

function switchPatient(patientId: string) {
  router.replace({ query: { ...route.query, patient: patientId } })
  void loadPatientContext(patientId)
}

watch(
  () => route.query.patient,
  (pid) => {
    if (typeof pid === 'string' && pid !== patient.value?.patient_id && allPatients.value.some((entry) => entry.patient_id === pid)) {
      void loadPatientContext(pid)
    }
  }
)

function onRxAdded(rx: any) {
  prescriptions.value = [rx, ...prescriptions.value]
}

async function sendToLab() {
  if (!patient.value) return
  const tests = TEST_OPTIONS.filter((t) => orderedTests[t])
  if (!tests.length) {
    toast('Select at least one test to send to the lab')
    return
  }
  sendingOrder.value = true
  const targetPatientId = patient.value.patient_id
  const targetPatientName = patient.value.full_name
  const targetCycleId = cycle.value?.id || null
  const orderedByProfileId = profile.value!.id
  const orderedByRole = props.role
  const order = {
    id: crypto.randomUUID(),
    patient_id: targetPatientId,
    cycle_id: targetCycleId,
    ordered_by_profile_id: orderedByProfileId,
    ordered_by_role: orderedByRole,
    tests,
    status: 'Ordered',
    created_at: new Date().toISOString(),
  }
  await queueOrRun(
    `Lab order sent for ${targetPatientName}: ${tests.join(', ')}`,
    { table: 'lab_test_orders', kind: 'insert', payload: order },
    () => { pendingOrders.value = [order, ...pendingOrders.value] },
  )
  sendingOrder.value = false
  TEST_OPTIONS.forEach((t) => (orderedTests[t] = false))
}

async function advanceStage() {
  if (!cycle.value || !nextStage.value) return
  advancingStage.value = true
  const targetCycleId = cycle.value.id
  const targetPatientName = patient.value.full_name
  const targetNextStage = nextStage.value
  const patch: Record<string, any> = { stage: targetNextStage }
  const today = new Date().toISOString().slice(0, 10)
  if (targetNextStage === 'OPU' && !cycle.value.opu_date) patch.opu_date = today
  if (targetNextStage === 'Transfer' && !cycle.value.transfer_date) patch.transfer_date = today
  await queueOrRun(
    `Cycle advanced to ${targetNextStage} for ${targetPatientName}`,
    { table: 'cycles', kind: 'update', payload: patch, match: { id: targetCycleId } },
    () => { if (cycle.value?.id === targetCycleId) Object.assign(cycle.value, patch) }
  )
  advancingStage.value = false
}

async function closeCycle() {
  if (!cycle.value || !outcomeDraft.value) return
  closingCycle.value = true
  const targetCycleId = cycle.value.id
  const targetPatientName = patient.value.full_name
  const targetOutcome = outcomeDraft.value
  const patch = { status: 'Closed', outcome: targetOutcome }
  await queueOrRun(
    `Cycle closed for ${targetPatientName} — ${targetOutcome}`,
    { table: 'cycles', kind: 'update', payload: patch, match: { id: targetCycleId } },
    () => { if (cycle.value?.id === targetCycleId) Object.assign(cycle.value, patch) }
  )
  closingCycle.value = false
  showCloseCycle.value = false
}

async function finalize() {
  if (!patient.value) return
  finalizing.value = true
  const targetPatientId = patient.value.patient_id
  const targetPatientName = patient.value.full_name
  const targetCycleId = cycle.value?.id || null
  const providerProfileId = profile.value!.id
  const providerRole = props.role
  const targetType = consultType.value
  const targetNotes = notes.value
  const targetDiagnosis = diagnosis.value
  const targetIcd = icd.value
  await queueOrRun(`Consultation finalized for ${targetPatientName}`, [
    {
      table: 'consultations',
      kind: 'insert',
      payload: {
        patient_id: targetPatientId,
        provider_profile_id: providerProfileId,
        provider_role: providerRole,
        type: targetType,
        notes: targetNotes,
        diagnosis: targetDiagnosis,
        icd10: targetIcd,
      },
    },
    ...(targetCycleId ? [{ table: 'cycles', kind: 'update' as const, payload: { physician_notes: targetNotes }, match: { id: targetCycleId } }] : []),
  ])
  finalizing.value = false
  router.push(`/${props.role}/patients`)
}

async function scheduleFollowUp() {
  if (!patient.value) return
  const targetPatientId = patient.value.patient_id
  const targetPatientName = patient.value.full_name
  const providerRole = props.role
  const providerProfileId = profile.value!.id
  const targetDate = followUpDate.value
  const targetTime = followUpTime.value
  await queueOrRun(`Follow-up booked for ${targetPatientName} on ${fmtDate(targetDate)}`, {
    table: 'appointments',
    kind: 'insert',
    payload: {
      patient_id: targetPatientId,
      provider_role: providerRole,
      provider_profile_id: providerProfileId,
      type: 'Follow-up Consultation',
      date: targetDate,
      time: targetTime,
      duration: 30,
      status: 'Scheduled',
    },
  })
}
</script>
