<template>
  <Modal :model-value="modelValue" :title="fmtDate(dateStr)" @update:model-value="$emit('update:modelValue', $event)">
    <template v-for="block in shiftBlocks" :key="block.key">
      <b style="font-size:11.5px; text-transform:uppercase; color:var(--text-500);">{{ block.label }}</b>
      <div style="margin-bottom:12px;">
        <p v-if="!duty[block.key]?.length" class="muted" style="font-size:12px;">Unassigned</p>
        <div v-for="name in duty[block.key]" :key="name" class="list-row" style="padding:6px 0;">
          <Avatar :name="name" :size="26" />
          <span class="main-txt" :style="{ color: name === myName ? 'var(--blue-600)' : 'inherit' }">{{ name }}{{ name === myName ? ' (You)' : '' }}</span>
        </div>
      </div>
    </template>
    <template #footer><button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button></template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'

const props = defineProps<{ modelValue: boolean; dateStr: string; myName?: string }>()
defineEmits<{ 'update:modelValue': [boolean] }>()

const supabase = useSupabaseClient()
const shiftBlocks = [
  { key: 'morning', label: 'Morning' },
  { key: 'afternoon', label: 'Afternoon' },
  { key: 'night', label: 'Night' },
]
const duty = ref<Record<string, string[]>>({ morning: [], afternoon: [], night: [] })

watch(
  () => [props.modelValue, props.dateStr],
  async ([open]) => {
    if (!open || !props.dateStr) return
    const { data } = await supabase.from('duty_roster').select('*').eq('date', props.dateStr).maybeSingle()
    duty.value = { morning: data?.morning || [], afternoon: data?.afternoon || [], night: data?.night || [] }
  },
  { immediate: true }
)
</script>
