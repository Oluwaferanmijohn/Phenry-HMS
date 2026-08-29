<template>
  <Modal :model-value="modelValue" :title="cycle ? patientName + ' — ' + cycle.type + ' · Cycle ' + cycle.cycle_number : ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="cycle">
      <div class="card-pad" style="border:1px solid var(--blue-100); background:var(--blue-50); border-radius:var(--radius-sm); margin-bottom:14px;">
        <div class="flex-between">
          <b style="color:var(--blue-700); font-size:13px;"><Icon name="activity" :size="14" /> Current Phase — {{ cycle.stage }}</b>
          <Badge :tone="cycle.status === 'Closed' ? 'gray' : 'blue'">{{ cycle.status === 'Closed' ? 'Closed' : `Cycle Day ${cycle.cycle_day}` }}</Badge>
        </div>
        <p style="font-size:12px; color:var(--text-700); margin-top:6px;">{{ cycle.physician_notes }}</p>
        <p v-if="cycle.status === 'Closed'" style="font-size:12px; color:var(--text-700); margin-top:6px;"><b>Outcome:</b> {{ cycle.outcome }}</p>
        <div class="flex-between" style="margin-top:8px; padding-top:8px; border-top:1px solid var(--blue-100);">
          <span class="cell-muted"><Icon name="user" :size="11" /> Cycle Manager: <b style="color:var(--text-900);">{{ cycleManagerName || 'Unassigned' }}</b></span>
          <span v-if="canManage" class="link" @click="showReassign = !showReassign">Reassign</span>
        </div>
        <div v-if="showReassign" class="flex gap-8" style="margin-top:8px;">
          <select v-model="reassignNurseId" class="input" style="font-size:12px;">
            <option value="">Unassigned</option>
            <option v-for="n in nurses" :key="n.id" :value="n.id">{{ n.full_name }}</option>
          </select>
          <button class="btn btn-primary btn-sm" :disabled="reassigning" @click="reassignManager">Save</button>
        </div>
      </div>

      <div v-if="canManage && cycle.status !== 'Closed'" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm); margin-bottom:14px;">
        <b style="font-size:12.5px;"><Icon name="target" :size="12" /> Cycle Progress</b>
        <div class="flex gap-8" style="margin-top:8px; flex-wrap:wrap;">
          <Badge v-for="s in STAGES" :key="s" :tone="s === cycle.stage ? 'blue' : STAGES.indexOf(s) < STAGES.indexOf(cycle.stage) ? 'green' : 'gray'">{{ s }}</Badge>
        </div>
        <div class="flex gap-8" style="margin-top:10px; flex-wrap:wrap;">
          <button v-if="nextStage" class="btn btn-secondary btn-sm" :disabled="advancing" @click="advanceStage">
            <Icon name="activity" :size="12" /> Advance to {{ nextStage }}
          </button>
          <button class="btn btn-secondary btn-sm" @click="showClose = !showClose"><Icon name="check-circle" :size="12" /> Close Cycle / Record Outcome</button>
        </div>
        <div v-if="showClose" style="margin-top:10px; border-top:1px solid var(--border); padding-top:10px;">
          <div class="field">
            <label>Outcome</label>
            <select v-model="outcomeDraft" class="input">
              <option value="">Select outcome…</option>
              <option>Positive — Clinical Pregnancy</option>
              <option>Positive — Biochemical Pregnancy</option>
              <option>Negative — Not Pregnant</option>
              <option>Cancelled — Poor Ovarian Response</option>
              <option>Cancelled — OHSS Risk</option>
              <option>Cancelled — Patient Withdrew</option>
            </select>
          </div>
          <button class="btn btn-primary btn-sm" :disabled="!outcomeDraft || closing" @click="closeCycle"><Icon name="check-circle" :size="12" /> Confirm &amp; Close Cycle</button>
        </div>
      </div>

      <CycleDayChart :cycle-id="cycle.id" :start-date="cycle.start_date" :can-edit="canManage || canEditChart" />
    </template>
    <template #footer><button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button></template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { resolveCycleManagerNames } from '~/composables/useCycleManagerNames'

const props = defineProps<{ modelValue: boolean; cycleId: string; patientName: string; role?: string; canManage?: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; updated: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const STAGES = ['Baseline', 'Stimulation', 'OPU', 'Transfer']

const cycle = ref<any>(null)
const cycleManagerName = ref('')
const nurses = ref<any[]>([])
const showClose = ref(false)
const outcomeDraft = ref('')
const advancing = ref(false)
const closing = ref(false)
const showReassign = ref(false)
const reassignNurseId = ref('')
const reassigning = ref(false)

// Day-to-day chart entries are the one thing Nurse can write directly (per
// nurse_role.sql's own cycle_daily_logs policy) — separate from canManage
// (stage-advance/close), which stays Matron-only.
const canEditChart = computed(() => props.role === 'nurse')

const nextStage = computed(() => {
  if (!cycle.value || cycle.value.status === 'Closed') return null
  const idx = STAGES.indexOf(cycle.value.stage)
  return idx >= 0 && idx < STAGES.length - 1 ? STAGES[idx + 1] : null
})

watch(
  () => [props.modelValue, props.cycleId],
  async ([open]) => {
    if (!open || !props.cycleId) return
    showClose.value = false
    outcomeDraft.value = ''
    showReassign.value = false
    const [cycleRes, nursesRes] = await Promise.all([
      supabase.from('cycles').select('*').eq('id', props.cycleId).single(),
      props.canManage ? supabase.from('profiles').select('id, full_name').eq('role', 'nurse').order('full_name', { ascending: true }) : Promise.resolve({ data: [] }),
    ])
    cycle.value = cycleRes.data
    cycleManagerName.value = cycleRes.data?.cycle_manager_id
      ? (await resolveCycleManagerNames(supabase, [cycleRes.data.cycle_manager_id])).get(cycleRes.data.cycle_manager_id) || ''
      : ''
    nurses.value = nursesRes.data || []
    reassignNurseId.value = cycleRes.data?.cycle_manager_id || ''
  },
  { immediate: true }
)

async function advanceStage() {
  if (!cycle.value || !nextStage.value) return
  advancing.value = true
  const targetCycleId = props.cycleId
  const targetPatientName = props.patientName
  const targetNextStage = nextStage.value
  const patch: Record<string, any> = { stage: targetNextStage }
  const today = new Date().toISOString().slice(0, 10)
  if (targetNextStage === 'OPU' && !cycle.value.opu_date) patch.opu_date = today
  if (targetNextStage === 'Transfer' && !cycle.value.transfer_date) patch.transfer_date = today
  await queueOrRun(
    `Cycle advanced to ${targetNextStage} for ${targetPatientName}`,
    { table: 'cycles', kind: 'update', payload: patch, match: { id: targetCycleId } },
    () => { if (cycle.value && props.cycleId === targetCycleId) Object.assign(cycle.value, patch) }
  )
  advancing.value = false
  emit('updated')
}

async function closeCycle() {
  if (!cycle.value || !outcomeDraft.value) return
  closing.value = true
  const targetCycleId = props.cycleId
  const targetPatientName = props.patientName
  const targetOutcome = outcomeDraft.value
  const patch = { status: 'Closed', outcome: targetOutcome }
  await queueOrRun(
    `Cycle closed for ${targetPatientName} — ${targetOutcome}`,
    { table: 'cycles', kind: 'update', payload: patch, match: { id: targetCycleId } },
    () => { if (cycle.value && props.cycleId === targetCycleId) Object.assign(cycle.value, patch) }
  )
  closing.value = false
  showClose.value = false
  emit('updated')
}

async function reassignManager() {
  if (!cycle.value) return
  reassigning.value = true
  const targetCycleId = props.cycleId
  const targetPatientName = props.patientName
  const targetNurseId = reassignNurseId.value || null
  const nurse = nurses.value.find((n) => n.id === reassignNurseId.value)
  const nurseFullName = nurse?.full_name || ''
  await queueOrRun(
    `Cycle manager ${nurse ? 'set to ' + nurseFullName : 'unassigned'} for ${targetPatientName}`,
    { table: 'cycles', kind: 'update', payload: { cycle_manager_id: targetNurseId }, match: { id: targetCycleId } },
    () => {
      if (cycle.value && props.cycleId === targetCycleId) {
        cycle.value.cycle_manager_id = targetNurseId
        cycleManagerName.value = nurseFullName
      }
    }
  )
  reassigning.value = false
  showReassign.value = false
  emit('updated')
}
</script>
