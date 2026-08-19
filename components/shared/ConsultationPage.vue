<template>
  <div v-if="patient">
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
          <b style="font-size:12.5px;">Findings &amp; Notes</b>
          <div class="tabs" style="margin:8px 0 10px;"><div class="tab active">Standard Consult</div><div class="tab">Follicular Tracking Scan</div><div class="tab">Post-Op Note</div></div>
          <textarea v-model="notes" class="input" rows="7" placeholder="Patient presents today for..." />
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

        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="flask" :size="13" /> Order Tests</b>
          <div style="margin-top:10px; display:flex; flex-direction:column; gap:8px; font-size:12.5px;">
            <label class="flex gap-8"><input type="checkbox" /> SFA (Semen Fluid Analysis)</label>
            <label class="flex gap-8"><input type="checkbox" checked /> Hormonal Panel (FSH, LH, E2)</label>
            <label class="flex gap-8"><input type="checkbox" /> Karyotype</label>
            <label class="flex gap-8"><input type="checkbox" /> Beta hCG (Quantitative)</label>
          </div>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:10px;" @click="toast('Lab order sent to the embryology lab')"><Icon name="flask" :size="12" /> Send to Lab</button>
        </div>

        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="siren" :size="13" /> Schedule Procedure</b>
          <p class="muted" style="font-size:11.5px; margin-top:4px;">OPU, Embryo Transfer, or another clinical procedure.</p>
          <button class="btn btn-secondary btn-block btn-sm" style="margin-top:8px;" @click="showScheduleProcedure = true"><Icon name="plus" :size="12" /> Schedule Procedure</button>
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
    <PatientDetailModal v-model="showFullHistory" :patient="patient" :cycle="cycle" :consultations="pastConsultations" :lab-results="pastLabResults" :caps="{}" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

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
const prescriptions = ref<any[]>([])
const pastConsultations = ref<any[]>([])
const pastLabResults = ref<any[]>([])

const notes = ref('')
const diagnosis = ref('')
const icd = ref('')
const finalizing = ref(false)
const showRx = ref(false)
const showScheduleProcedure = ref(false)
const showFullHistory = ref(false)

const tomorrow = new Date(Date.now() + 86400000).toISOString().slice(0, 10)
const followUpDate = ref(tomorrow)
const followUpTime = ref('09:00')

async function loadPatientContext(patientId: string) {
  const [bioRes, cycleRes, rxRes, consultRes, labRes] = await Promise.all([
    supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', patientId).single(),
    supabase.from('cycles').select('*').eq('patient_id', patientId).neq('status', 'Closed').order('start_date', { ascending: false }).limit(1).maybeSingle(),
    supabase.from('prescriptions').select('*').eq('patient_id', patientId).neq('status', 'Cancelled').order('date', { ascending: false }),
    supabase.from('consultations').select('*, profiles:provider_profile_id(full_name)').eq('patient_id', patientId).order('date', { ascending: false }),
    supabase.from('lab_results').select('*, lab_templates(name)').eq('patient_id', patientId).order('collected_on', { ascending: false }),
  ])
  patient.value = bioRes.data ? { ...bioRes.data, full_name: bioRes.data.patient_names?.full_name } : null
  cycle.value = cycleRes.data
  prescriptions.value = rxRes.data || []
  pastConsultations.value = (consultRes.data || []).map((c: any) => ({ ...c, provider_name: c.profiles?.full_name || 'Staff' }))
  pastLabResults.value = labRes.data || []

  notes.value = cycle.value?.physician_notes || ''
  diagnosis.value = cycle.value ? `Infertility — undergoing ${cycle.value.type}` : ''
  icd.value = ''
}

await useAsyncData(`consultation-init-${props.role}`, async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  allPatients.value = data || []
  const startId = (route.query.patient as string) || allPatients.value[0]?.patient_id
  if (startId) await loadPatientContext(startId)
  return true
})

function switchPatient(patientId: string) {
  router.replace({ query: { ...route.query, patient: patientId } })
  loadPatientContext(patientId)
}

watch(
  () => route.query.patient,
  (pid) => {
    if (pid && pid !== patient.value?.patient_id) loadPatientContext(pid as string)
  }
)

function onRxAdded(rx: any) {
  prescriptions.value = [rx, ...prescriptions.value]
}

async function finalize() {
  if (!patient.value) return
  finalizing.value = true
  await queueOrRun(`Consultation finalized for ${patient.value.full_name}`, async () => {
    const { error } = await supabase.from('consultations').insert({
      patient_id: patient.value.patient_id,
      provider_profile_id: profile.value!.id,
      provider_role: props.role,
      type: 'Standard Consult',
      notes: notes.value,
      diagnosis: diagnosis.value,
      icd10: icd.value,
    })
    if (error) throw error
    if (cycle.value) {
      await supabase.from('cycles').update({ physician_notes: notes.value }).eq('id', cycle.value.id)
    }
  })
  finalizing.value = false
  router.push(`/${props.role}/patients`)
}

async function scheduleFollowUp() {
  if (!patient.value) return
  await queueOrRun(`Follow-up booked for ${patient.value.full_name} on ${fmtDate(followUpDate.value)}`, async () => {
    const { error } = await supabase.from('appointments').insert({
      patient_id: patient.value.patient_id,
      provider_role: props.role,
      provider_profile_id: profile.value!.id,
      type: 'Follow-up Consultation',
      date: followUpDate.value,
      time: followUpTime.value,
      duration: 30,
      status: 'Scheduled',
    })
    if (error) throw error
  })
}
</script>
