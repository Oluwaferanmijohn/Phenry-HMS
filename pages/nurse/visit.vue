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
        <b style="font-size:14.5px;">{{ steps[step] }}</b>
        <p class="cell-muted" style="margin-top:4px; margin-bottom:14px;">Document patient condition and detailed observations for this visit.</p>

        <div v-if="step === 0" class="form-row">
          <div class="field"><label>Blood Pressure</label><input class="input" placeholder="120/80" /></div>
          <div class="field"><label>Temperature</label><input class="input" placeholder="98.6°F" /></div>
        </div>

        <template v-else-if="step === 1">
          <div class="field"><label>Patient Condition</label><select class="input"><option>Stable</option><option>Needs Review</option></select></div>
          <div class="field"><label>Detailed Nursing Notes</label><textarea class="input" rows="4">Patient reports mild cramping, which is expected at this stage of the cycle. Vitals are within normal limits.</textarea></div>
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

        <div v-else class="field"><label>Post-Visit Instructions for Patient</label><textarea class="input" rows="4" placeholder="Instructions communicated to patient…" /></div>

        <div class="flex-between" style="margin-top:20px;">
          <span />
          <button v-if="step < 3" class="btn btn-primary" @click="saveAndProceed">Save &amp; Proceed <Icon name="arrow-right" :size="13" /></button>
          <button v-else class="btn btn-success" @click="finalize"><Icon name="check-circle" :size="13" /> Finalize Visit</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
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

async function loadPatient(patientId: string) {
  const [bioRes, rxRes] = await Promise.all([
    supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', patientId).single(),
    supabase.from('prescriptions').select('*').eq('patient_id', patientId).neq('status', 'Cancelled').order('date', { ascending: false }),
  ])
  patient.value = bioRes.data ? { ...bioRes.data, full_name: bioRes.data.patient_names?.full_name } : null
  existingRx.value = rxRes.data || []
}

await useAsyncData('nurse-visit-init', async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  const startId = (route.query.patient as string) || patients.value[0]?.patient_id
  if (startId) await loadPatient(startId)
  return true
})

function switchPatient(patientId: string) {
  step.value = 0
  router.replace({ query: { ...route.query, patient: patientId } })
  loadPatient(patientId)
}

// Steps 0/1/3 have no backing table in spec §1 (matching the prototype's
// own visitStepBody — only the Medication Admin step actually reads/writes
// anything). "Save & Proceed" here confirms the step, matching that.
function saveAndProceed() {
  toast('Progress saved', 'success')
  step.value++
}

async function addPrescription() {
  if (!patient.value) return
  const med = rxMed.value || 'Medication'
  const sig = rxSig.value || 'As directed'
  await queueOrRun(`${med} logged for ${patient.value.full_name}`, async () => {
    const { data, error } = await supabase
      .from('prescriptions')
      .insert({
        patient_id: patient.value.patient_id,
        prescribed_by_profile_id: profile.value!.id,
        prescribed_by_role: 'nurse',
        medication: med,
        sig,
      })
      .select()
      .single()
    if (error) throw error
    existingRx.value = [data, ...existingRx.value]
  })
  rxMed.value = ''
  rxSig.value = ''
}

function finalize() {
  toast('Visit finalized', 'success')
  step.value = 0
  router.push('/nurse/overview')
}
</script>
