<template>
  <Modal :model-value="modelValue" title="Start New Cycle" @update:model-value="$emit('update:modelValue', $event)">
    <div class="field">
      <label>Patient</label>
      <select v-model="patientId" class="input">
        <option value="">{{ eligible.length ? 'Select a patient…' : 'No eligible patients (all have active cycles)' }}</option>
        <option v-for="p in eligible" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option>
      </select>
    </div>
    <div class="form-row">
      <div class="field">
        <label>Cycle Type</label>
        <select v-model="type" class="input"><option>IVF Cycle</option><option>ICSI Cycle</option><option>IUI Cycle</option><option>Egg Freezing</option><option>Donor Cycle</option></select>
      </div>
      <div class="field">
        <label>Protocol</label>
        <select v-model="protocol" class="input"><option>Antagonist Protocol</option><option>Long Agonist Protocol</option><option>Natural Cycle</option></select>
      </div>
    </div>
    <div class="field"><label>Cycle Start Date (Day 1)</label><input v-model="startDate" class="input" type="date" /></div>
    <div class="field">
      <label>Cycle Manager (Fertility Nurse){{ nurses.length ? '' : ' — optional' }}</label>
      <select v-model="cycleManagerId" class="input">
        <option value="">{{ nurses.length ? 'Select a nurse…' : 'No nurse accounts on staff yet — leave unassigned for now' }}</option>
        <option v-for="n in nurses" :key="n.id" :value="n.id">{{ n.full_name }}</option>
      </select>
      <div class="hint">The dedicated nurse who'll guide this patient day-to-day through the cycle.</div>
    </div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="!patientId || submitting" @click="submit"><Icon name="check-circle" :size="13" /> Start Cycle</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { ROLE_META } from '~/composables/useRoleMeta'

const props = defineProps<{ modelValue: boolean; role: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; started: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const eligible = ref<any[]>([])
const nurses = ref<any[]>([])
const patientId = ref('')
const cycleManagerId = ref('')
const type = ref('IVF Cycle')
const protocol = ref('Antagonist Protocol')
const startDate = ref(new Date().toISOString().slice(0, 10))
const submitting = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    cycleManagerId.value = ''
    const [namesRes, cyclesRes, nursesRes] = await Promise.all([
      supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
      supabase.from('cycles').select('patient_id').neq('status', 'Closed'),
      supabase.from('profiles').select('id, full_name').eq('role', 'nurse').order('full_name', { ascending: true }),
    ])
    const withActiveCycle = new Set((cyclesRes.data || []).map((c: any) => c.patient_id))
    eligible.value = (namesRes.data || []).filter((p: any) => !withActiveCycle.has(p.patient_id))
    nurses.value = nursesRes.data || []
  }
)

async function submit() {
  if (!patientId.value) return
  submitting.value = true
  const providerLabel = ROLE_META[props.role]?.label || props.role
  const targetPatientId = patientId.value
  const targetType = type.value
  const targetProtocol = protocol.value
  const targetStartDate = startDate.value
  const targetCycleManagerId = cycleManagerId.value || null

  // Cycle numbering + history. "Eligible" above only excludes patients with
  // a CURRENTLY active cycle — a returning patient starting their 3rd
  // attempt after their prior cycles closed is still eligible, and needs
  // cycle_number to reflect that, not a hardcoded 1. cycles.prior_cycles
  // jsonb already exists in the schema for exactly this (a per-cycle
  // summary snapshot) but had never been written to.
  const { data: priorCycles } = await supabase
    .from('cycles')
    .select('cycle_number, type, protocol, start_date, opu_date, transfer_date, outcome, status')
    .eq('patient_id', targetPatientId)
    .order('cycle_number', { ascending: true })
  const cycleNumber = (priorCycles?.length || 0) + 1

  await queueOrRun(`${targetType} started`, [
    {
      table: 'cycles',
      kind: 'insert',
      payload: {
        patient_id: targetPatientId,
        cycle_number: cycleNumber,
        prior_cycles: priorCycles || [],
        protocol: targetProtocol,
        type: targetType,
        start_date: targetStartDate,
        stage: 'Baseline',
        cycle_day: 1,
        status: 'Active',
        cycle_manager_id: targetCycleManagerId,
        physician_notes: `Cycle started by ${providerLabel}.`,
      },
    },
    { table: 'bio_details', kind: 'update', payload: { status: 'Active' }, match: { patient_id: targetPatientId } },
  ])
  submitting.value = false
  emit('started')
  emit('update:modelValue', false)
}
</script>
