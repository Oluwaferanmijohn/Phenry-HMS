<template>
  <Modal :model-value="modelValue" :title="cycle ? patientName + ' — ' + cycle.type + ' · Cycle ' + cycle.cycle_number : ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="cycle">
      <div class="card-pad" style="border:1px solid var(--blue-100); background:var(--blue-50); border-radius:var(--radius-sm); margin-bottom:14px;">
        <div class="flex-between"><b style="color:var(--blue-700); font-size:13px;"><Icon name="activity" :size="14" /> Current Phase — {{ cycle.stage }}</b><Badge tone="blue">Cycle Day {{ cycle.cycle_day }}</Badge></div>
        <p style="font-size:12px; color:var(--text-700); margin-top:6px;">{{ cycle.physician_notes }}</p>
      </div>
      <b style="font-size:12.5px;">Daily Treatment Tracker</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:8px; max-height:340px; overflow-y:auto;">
        <div v-for="day in [1, 2, 3, 4, 5]" :key="day" style="border:1px solid var(--border); border-radius:var(--radius-sm); padding:10px 12px;" :style="{ background: day === logs.length + 1 ? 'var(--blue-50)' : 'transparent' }">
          <div class="flex-between">
            <b style="font-size:12px;">Day {{ day }}</b>
            <Badge v-if="logFor(day)" tone="green">Logged</Badge>
            <Badge v-else-if="day === logs.length + 1" tone="blue">Action Required</Badge>
            <Badge v-else tone="gray">Not yet active</Badge>
          </div>
          <template v-if="logFor(day)">
            <div class="flex gap-8" style="font-size:11px; margin-top:6px;"><Badge tone="green">Medication Administered</Badge><Badge tone="green">Vitals Logged</Badge></div>
            <div class="sub-txt" style="margin-top:4px;">{{ logFor(day).note }}</div>
          </template>
          <template v-else-if="day === logs.length + 1">
            <div class="flex gap-14" style="margin:8px 0 6px;">
              <label class="flex gap-8" style="font-size:12px;"><input v-model="draftMed" type="checkbox" /> Medication</label>
              <label class="flex gap-8" style="font-size:12px;"><input v-model="draftVit" type="checkbox" /> Vitals</label>
            </div>
            <textarea v-model="draftNotes" class="input" rows="2" placeholder="Daily observation notes…" />
            <button class="btn btn-primary btn-sm" style="margin-top:6px;" @click="saveDay(day)">Save Day {{ day }} Log</button>
          </template>
        </div>
      </div>
    </template>
    <template #footer><button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button></template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; cycleId: string; patientName: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const cycle = ref<any>(null)
const logs = ref<any[]>([])
const draftMed = ref(false)
const draftVit = ref(false)
const draftNotes = ref('')

watch(
  () => [props.modelValue, props.cycleId],
  async ([open]) => {
    if (!open || !props.cycleId) return
    draftMed.value = false
    draftVit.value = false
    draftNotes.value = ''
    const [cycleRes, logsRes] = await Promise.all([
      supabase.from('cycles').select('*').eq('id', props.cycleId).single(),
      supabase.from('cycle_daily_logs').select('*').eq('cycle_id', props.cycleId).order('day', { ascending: true }),
    ])
    cycle.value = cycleRes.data
    logs.value = logsRes.data || []
  },
  { immediate: true }
)

function logFor(day: number) {
  return logs.value.find((l) => l.day === day)
}

async function saveDay(day: number) {
  await queueOrRun(`Day ${day} log saved`, async () => {
    const { error } = await supabase.from('cycle_daily_logs').insert({
      cycle_id: props.cycleId,
      day,
      date: new Date().toISOString().slice(0, 10),
      medication_administered: draftMed.value,
      vitals_logged: draftVit.value,
      note: draftNotes.value || 'No additional notes.',
    })
    if (error) throw error
    await supabase.from('cycles').update({ cycle_day: day + 9 }).eq('id', props.cycleId)
    logs.value = [...logs.value, { day, medication_administered: draftMed.value, vitals_logged: draftVit.value, note: draftNotes.value }]
  })
}
</script>
