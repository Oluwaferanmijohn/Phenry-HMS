<template>
  <Modal :model-value="modelValue" :title="'Set Duty — ' + fmtDate(dateStr)" @update:model-value="$emit('update:modelValue', $event)">
    <template v-for="block in shiftBlocks" :key="block.key">
      <b style="font-size:11.5px; text-transform:uppercase; color:var(--text-500);">{{ block.label }}</b>
      <div class="pick-list" style="margin:6px 0 14px;">
        <label v-for="n in nurses" :key="n.id" class="pick-row">
          <input type="checkbox" :checked="duty[block.key].includes(n.full_name)" @change="toggle(block.key, n.full_name)" />
          {{ n.full_name }}
        </label>
        <p v-if="!nurses.length" class="muted" style="font-size:12px;">No nurses on staff yet.</p>
      </div>
    </template>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="submitting" @click="save"><Icon name="check-circle" :size="13" /> Save Duty Roster</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; dateStr: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const shiftBlocks = [
  { key: 'morning', label: 'Morning Duty' },
  { key: 'afternoon', label: 'Afternoon Duty' },
  { key: 'night', label: 'Night Duty' },
]

const nurses = ref<any[]>([])
const duty = reactive<Record<string, string[]>>({ morning: [], afternoon: [], night: [] })
const submitting = ref(false)

watch(
  () => [props.modelValue, props.dateStr],
  async ([open]) => {
    if (!open || !props.dateStr) return
    const [nursesRes, rosterRes] = await Promise.all([
      supabase.from('profiles').select('id, full_name').eq('role', 'nurse'),
      supabase.from('duty_roster').select('*').eq('date', props.dateStr).maybeSingle(),
    ])
    nurses.value = nursesRes.data || []
    duty.morning = rosterRes.data?.morning || []
    duty.afternoon = rosterRes.data?.afternoon || []
    duty.night = rosterRes.data?.night || []
  },
  { immediate: true }
)

function toggle(shiftKey: string, name: string) {
  const arr = duty[shiftKey]
  const i = arr.indexOf(name)
  if (i === -1) arr.push(name)
  else arr.splice(i, 1)
}

async function save() {
  submitting.value = true
  await queueOrRun(`Duty roster updated for ${fmtDate(props.dateStr)}`, async () => {
    const { error } = await supabase
      .from('duty_roster')
      .upsert({ date: props.dateStr, morning: duty.morning, afternoon: duty.afternoon, night: duty.night }, { onConflict: 'date' })
    if (error) throw error
  })
  submitting.value = false
  emit('saved')
  emit('update:modelValue', false)
}
</script>
