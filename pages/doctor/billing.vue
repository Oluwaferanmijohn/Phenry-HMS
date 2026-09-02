<template>
  <div v-if="billingStatus === 'pending' || loadingPatient">
    <div class="page-header"><div><h1>Payment Plan Generator</h1><div class="desc">Loading accessible patient information…</div></div></div>
    <div class="card card-pad"><div class="cell-muted">Loading payment-plan workspace…</div></div>
  </div>
  <div v-else-if="billingError || patientLoadError">
    <div class="page-header"><div><h1>Payment Plan Generator</h1><div class="desc">The workspace could not be opened.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="alert" title="Payment-plan data could not be loaded" description="A temporary connection or permission error prevented the patient context from loading." />
      <div style="margin-top:12px; text-align:center;"><button class="btn btn-secondary btn-sm" @click="retryBilling">Try Again</button></div>
    </div>
  </div>
  <div v-else-if="!patient">
    <div class="page-header"><div><h1>Payment Plan Generator</h1><div class="desc">Select an accessible patient to continue.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="user" title="No accessible patients" description="No patient is currently assigned to this doctor or present in today’s permitted waiting-room scope." />
    </div>
  </div>
  <div v-else>
    <div class="page-header">
      <div><h1>Payment Plan Generator</h1><div class="desc">{{ patient.full_name }} · {{ patient.patient_id }}</div></div>
      <div class="page-actions">
        <select class="input" :value="patient.patient_id" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
      </div>
    </div>
    <div class="card card-pad" style="max-width:640px;">
      <b style="font-size:12.5px; color:var(--text-500); text-transform:uppercase; letter-spacing:.04em;">Step 1: Package Selection</b>
      <div class="form-row" style="margin-top:10px;">
        <div class="field">
          <label>Treatment Package</label>
          <select v-model="billPackage" class="input">
            <option value="">Select Package</option>
            <option v-for="(cost, name) in PACKAGE_COST" :key="name" :value="name">{{ name }}</option>
          </select>
        </div>
        <div class="field"><label>Total Package Cost</label><input class="input" disabled :value="fmtNaira(PACKAGE_COST[billPackage] || 0)" /></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px; color:var(--text-500); text-transform:uppercase; letter-spacing:.04em;">Step 2: Installment Breakdown</b>
      <div style="margin-top:10px; display:flex; flex-direction:column; gap:10px;">
        <div v-for="(m, i) in milestones" :key="m.id" class="flex gap-10">
          <input v-model="m.label" class="input" style="flex:1;" />
          <input v-model.number="m.amount" class="input" style="width:140px;" type="number" placeholder="0.00" />
          <button class="icon-btn" style="color:var(--red-600);" @click="milestones.splice(i, 1)"><Icon name="trash" :size="13" /></button>
        </div>
        <button class="btn btn-secondary btn-sm" style="align-self:flex-start;" @click="milestones.push({ id: Date.now(), label: 'New Milestone', amount: 0 })">
          <Icon name="plus" :size="12" /> Add Milestone
        </button>
      </div>
      <hr class="hr" />
      <div class="flex-between" style="font-size:13px;"><span class="cell-muted">Total Amount Scheduled</span><b>{{ fmtNaira(total) }}</b></div>
      <div class="flex-between" style="font-size:13px; margin-top:6px;"><span class="cell-muted">Remaining Balance</span><b :style="{ color: remaining === 0 ? 'var(--green-600)' : 'var(--text-900)' }">{{ fmtNaira(remaining) }}</b></div>
      <button class="btn btn-primary btn-block" style="margin-top:16px;" :disabled="submitting" @click="generate"><Icon name="arrow-right" :size="13" /> Generate &amp; Send Payment Plan</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { fmtNaira } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'
import { fetchClinicalPatientDirectory } from '~/composables/useClinicalPatientAccess'

const PACKAGE_COST: Record<string, number> = {
  'ICSI Cycle': 4_500_000,
  'Basic IVF Cycle': 3_500_000,
  'Egg Freezing': 2_100_000,
  'IUI Cycle': 900_000,
}

const supabase = useSupabaseClient()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()
const profile = useProfile()
const route = useRoute()
const router = useRouter()

const patients = ref<any[]>([])
const patient = ref<any>(null)
const billPackage = ref('')
const milestones = ref([
  { id: 1, label: 'Initial Deposit / Drugs', amount: 0 },
  { id: 2, label: 'Before OPU / Retrieval', amount: 0 },
  { id: 3, label: 'Before Transfer', amount: 0 },
])
const submitting = ref(false)
const loadingPatient = ref(false)
const patientLoadError = ref('')

const total = computed(() => milestones.value.reduce((s, m) => s + Number(m.amount || 0), 0))
const remaining = computed(() => (PACKAGE_COST[billPackage.value] || 0) - total.value)

async function loadPatient(patientId: string) {
  const selected = patients.value.find((entry) => entry.patient_id === patientId)
  if (!selected) return
  loadingPatient.value = true
  patientLoadError.value = ''
  try {
    patient.value = selected
  } catch {
    patient.value = null
    patientLoadError.value = 'Patient billing context could not be loaded.'
  } finally {
    loadingPatient.value = false
  }
}

interface BillingPayload {
  patients: any[]
  patient: any | null
}

const billingKey = `doctor-billing-${profile.value?.id || 'anonymous'}`
const {
  data: billingData,
  error: billingError,
  status: billingStatus,
  refresh: refreshBilling,
} = await useAsyncData<BillingPayload>(billingKey, async () => {
  const directoryPayload = await fetchClinicalPatientDirectory(supabase)
  const directory = directoryPayload.patients
  const requestedPatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
  const startId = directory.some((entry) => entry.patient_id === requestedPatientId)
    ? requestedPatientId
    : directory[0]?.patient_id
  if (!startId) return { patients: directory, patient: null }
  return {
    patients: directory,
    patient: directory.find((entry) => entry.patient_id === startId) || null,
  }
}, {
  default: () => ({ patients: [], patient: null }),
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

function applyBillingData(payload: BillingPayload | null | undefined) {
  patients.value = payload?.patients || []
  patient.value = payload?.patient || null
}

watch(billingData, applyBillingData, { immediate: true })

async function retryBilling() {
  patientLoadError.value = ''
  await refreshBilling()
  applyBillingData(billingData.value)
}

async function switchPatient(patientId: string) {
  await router.replace({ query: { ...route.query, patient: patientId } })
  await loadPatient(patientId)
}

async function generate() {
  if (!billPackage.value) return toast('Choose a treatment package first', 'warn')
  if (!patient.value) return
  if (!milestones.value.length || milestones.value.some((milestone) => !milestone.label.trim() || Number(milestone.amount) <= 0)) {
    return toast('Every installment needs a label and an amount greater than zero', 'warn')
  }
  if (Math.abs(remaining.value) > 0.005) {
    return toast('Installments must add up exactly to the treatment package cost', 'warn')
  }
  submitting.value = true

  const targetPatientId = patient.value.patient_id
  const targetPatientName = patient.value.full_name
  const targetPackage = billPackage.value
  const targetTotal = PACKAGE_COST[targetPackage]
  const targetMilestones = milestones.value.map((m) => ({ label: m.label, amount: Number(m.amount || 0) }))

  try {
    await queueOrRun(`Payment plan sent to ${targetPatientName}`, {
      kind: 'rpc',
      rpcName: 'save_payment_plan',
      payload: {
        p_patient_id: targetPatientId,
        p_package: targetPackage,
        p_total: targetTotal,
        p_milestones: targetMilestones,
      },
    })
    milestones.value = []
    billPackage.value = ''
    await navigateTo('/doctor/waiting')
  } finally {
    submitting.value = false
  }
}
</script>
