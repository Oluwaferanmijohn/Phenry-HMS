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
        <select v-model="protocol" class="input"><option>Standard Buserelin Protocol</option><option>Antagonist Protocol</option><option>Long Agonist Protocol</option><option>Natural Cycle</option></select>
      </div>
    </div>
    <div class="field">
      <label>Reusable Cycle Template</label>
      <select v-model="templateId" class="input">
        <option value="">No saved template — use the selected protocol</option>
        <option v-for="template in templates" :key="template.id" :value="template.id">
          {{ template.name }}{{ template.is_system ? ' · Hospital default' : '' }}
        </option>
      </select>
      <div v-if="selectedTemplate?.description" class="template-preview">
        <Icon name="layers" :size="13" />
        <span><b>{{ selectedTemplate.name }}</b>{{ selectedTemplate.description }}</span>
      </div>
      <div v-else class="hint">Saved templates copy the planned days, medicines and procedures. Patient-specific records and signatures are never copied.</div>
      <div v-if="templateLoadError" class="hint template-error">{{ templateLoadError }}</div>
    </div>
    <div class="field"><label>Cycle Start Date (Down-Regulation Day 1)</label><input v-model="startDate" class="input" type="date" /><div class="hint">The standard Buserelin daily chart is created automatically and can be adjusted for the patient.</div></div>
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
import { computed, ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; role: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; started: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const eligible = ref<any[]>([])
const nurses = ref<any[]>([])
const templates = ref<any[]>([])
const patientId = ref('')
const cycleManagerId = ref('')
const templateId = ref('')
const type = ref('IVF Cycle')
const protocol = ref('Standard Buserelin Protocol')
const startDate = ref(new Date().toISOString().slice(0, 10))
const submitting = ref(false)
const templateLoadError = ref('')
const selectedTemplate = computed(() => templates.value.find((template) => template.id === templateId.value))

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    cycleManagerId.value = ''
    templateLoadError.value = ''
    const [namesRes, cyclesRes, nursesRes, templatesRes] = await Promise.all([
      supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
      supabase.from('cycles').select('patient_id').neq('status', 'Closed'),
      supabase.from('profiles').select('id, full_name').eq('role', 'nurse').order('full_name', { ascending: true }),
      supabase.from('cycle_templates').select('id, name, description, cycle_type, protocol, is_system').eq('active', true).order('is_system', { ascending: false }).order('name'),
    ])
    const withActiveCycle = new Set((cyclesRes.data || []).map((c: any) => c.patient_id))
    eligible.value = (namesRes.data || []).filter((p: any) => !withActiveCycle.has(p.patient_id))
    nurses.value = nursesRes.data || []
    templates.value = templatesRes.data || []
    templateLoadError.value = templatesRes.error
      ? 'Run the reusable cycle-template SQL update to enable saved templates.'
      : ''
    templateId.value = templates.value.find((template) => template.is_system)?.id || ''
  }
)

watch(templateId, (id) => {
  const template = templates.value.find((item) => item.id === id)
  if (!template) return
  if (template.cycle_type) type.value = template.cycle_type
  if (template.protocol) protocol.value = template.protocol
})

async function submit() {
  if (!patientId.value) return
  submitting.value = true
  const targetPatientId = patientId.value
  const targetType = type.value
  const targetProtocol = protocol.value
  const targetStartDate = startDate.value
  const targetCycleManagerId = cycleManagerId.value || null

  await queueOrRun(`${targetType} started`, {
    kind: 'rpc',
    rpcName: 'start_fertility_cycle',
    payload: {
      p_patient_id: targetPatientId,
      p_type: targetType,
      p_protocol: targetProtocol,
      p_start_date: targetStartDate,
      p_cycle_manager_id: targetCycleManagerId,
      p_template_id: templateId.value || null,
    },
  })
  submitting.value = false
  emit('started')
  emit('update:modelValue', false)
}
</script>

<style scoped>
.template-preview{display:flex;align-items:flex-start;gap:8px;margin-top:7px;padding:9px 10px;border:1px solid var(--blue-100);border-radius:8px;background:var(--blue-50);color:var(--text-600);font-size:11px;line-height:1.45}.template-preview b{display:block;color:var(--text-800);margin-bottom:2px}.template-error{color:var(--amber-700)}
</style>
