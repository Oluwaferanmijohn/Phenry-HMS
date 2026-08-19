<template>
  <div v-if="patient">
    <div class="page-header">
      <div><h1>Payment Plan Generator</h1><div class="desc">{{ patient.full_name }} · {{ patient.patient_id }}</div></div>
      <div class="page-actions">
        <select class="input" :value="patient.patient_id" @change="loadPatient(($event.target as HTMLSelectElement).value)">
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
import { ref, computed } from 'vue'
import { fmtNaira } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'

const PACKAGE_COST: Record<string, number> = {
  'ICSI Cycle': 4_500_000,
  'Basic IVF Cycle': 3_500_000,
  'Egg Freezing': 2_100_000,
  'IUI Cycle': 900_000,
}

const supabase = useSupabaseClient()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()

const patients = ref<any[]>([])
const patient = ref<any>(null)
const billPackage = ref('')
const milestones = ref([
  { id: 1, label: 'Initial Deposit / Drugs', amount: 0 },
  { id: 2, label: 'Before OPU / Retrieval', amount: 0 },
  { id: 3, label: 'Before Transfer', amount: 0 },
])
const submitting = ref(false)

const total = computed(() => milestones.value.reduce((s, m) => s + Number(m.amount || 0), 0))
const remaining = computed(() => (PACKAGE_COST[billPackage.value] || 0) - total.value)

async function loadPatient(patientId: string) {
  const { data } = await supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', patientId).single()
  patient.value = data ? { ...data, full_name: data.patient_names?.full_name } : null
}

await useAsyncData('doctor-billing-init', async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  if (patients.value[0]) await loadPatient(patients.value[0].patient_id)
  return true
})

async function generate() {
  if (!billPackage.value) return toast('Choose a treatment package first', 'warn')
  if (!patient.value) return
  submitting.value = true

  await queueOrRun(`Payment plan sent to ${patient.value.full_name}`, async () => {
    const { data: existing } = await supabase.from('payment_plans').select('id').eq('patient_id', patient.value.patient_id).limit(1).maybeSingle()

    let planId = existing?.id
    if (existing) {
      await supabase.from('payment_plans').update({ package: billPackage.value, total_cost: total.value }).eq('id', existing.id)
      await supabase.from('payment_milestones').delete().eq('plan_id', existing.id)
    } else {
      const { data: created, error } = await supabase
        .from('payment_plans')
        .insert({ patient_id: patient.value.patient_id, package: billPackage.value, total_cost: total.value })
        .select()
        .single()
      if (error) throw error
      planId = created.id
    }

    const { error: milestonesError } = await supabase.from('payment_milestones').insert(
      milestones.value.map((m) => ({ plan_id: planId, label: m.label, amount: Number(m.amount || 0), status: 'Upcoming', due_context: 'Scheduled' }))
    )
    if (milestonesError) throw milestonesError
  })

  submitting.value = false
  milestones.value = []
  billPackage.value = ''
  await navigateTo('/doctor/waiting')
}
</script>
