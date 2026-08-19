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
const patientId = ref('')
const type = ref('IVF Cycle')
const protocol = ref('Antagonist Protocol')
const startDate = ref(new Date().toISOString().slice(0, 10))
const submitting = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    const [namesRes, cyclesRes] = await Promise.all([
      supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
      supabase.from('cycles').select('patient_id').neq('status', 'Closed'),
    ])
    const withActiveCycle = new Set((cyclesRes.data || []).map((c: any) => c.patient_id))
    eligible.value = (namesRes.data || []).filter((p: any) => !withActiveCycle.has(p.patient_id))
  }
)

async function submit() {
  if (!patientId.value) return
  submitting.value = true
  const providerLabel = ROLE_META[props.role]?.label || props.role
  await queueOrRun(`${type.value} started`, async () => {
    const { error } = await supabase.from('cycles').insert({
      patient_id: patientId.value,
      cycle_number: 1,
      protocol: protocol.value,
      type: type.value,
      start_date: startDate.value,
      stage: 'Baseline',
      cycle_day: 1,
      status: 'Active',
      physician_notes: `Cycle started by ${providerLabel}.`,
    })
    if (error) throw error
    await supabase.from('bio_details').update({ status: 'Active' }).eq('patient_id', patientId.value)
  })
  submitting.value = false
  emit('started')
  emit('update:modelValue', false)
}
</script>
