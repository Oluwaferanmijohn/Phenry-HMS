<template>
  <Modal :model-value="modelValue" :title="tank ? 'Edit Tank' : 'Add New Tank'" @update:model-value="$emit('update:modelValue', $event)">
    <div class="field"><label>Tank Name</label><input v-model="name" class="input" placeholder="e.g. Tank D" /></div>
    <div class="form-row">
      <div class="field"><label>Phase</label><select v-model="phase" class="input"><option>Vapor Phase LN2</option><option>Liquid Phase LN2</option></select></div>
      <div class="field"><label>Capacity (straws)</label><input v-model.number="capacity" class="input" type="number" /></div>
    </div>
    <template #footer>
      <button v-if="tank" class="btn btn-secondary" style="color:var(--red-600); margin-right:auto;" @click="remove"><Icon name="trash" :size="13" /> Remove Tank</button>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="!name || submitting" @click="save"><Icon name="check-circle" :size="13" /> {{ tank ? 'Save Changes' : 'Add Tank' }}</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ modelValue: boolean; tank: any | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: [] }>()

const supabase = useSupabaseClient()
const { toast } = useToast()

const name = ref('')
const phase = ref('Vapor Phase LN2')
const capacity = ref(100)
const submitting = ref(false)

watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    name.value = props.tank?.name || ''
    phase.value = props.tank?.phase || 'Vapor Phase LN2'
    capacity.value = props.tank?.capacity ?? 100
  }
)

async function save() {
  submitting.value = true
  const payload = { name: name.value, phase: phase.value, capacity: capacity.value }
  const { error } = props.tank
    ? await supabase.from('cryo_tanks').update(payload).eq('id', props.tank.id)
    : await supabase.from('cryo_tanks').insert({ ...payload, current_temp: -196.0, used: 0 })
  submitting.value = false
  if (error) {
    toast('Could not save the tank', 'warn')
    return
  }
  emit('saved')
  emit('update:modelValue', false)
}

async function remove() {
  if (!props.tank) return
  const { error } = await supabase.from('cryo_tanks').delete().eq('id', props.tank.id)
  if (error) {
    toast('Could not remove the tank — it may still have records assigned to it', 'warn')
    return
  }
  toast(`${props.tank.name} removed`, 'success')
  emit('saved')
  emit('update:modelValue', false)
}
</script>
