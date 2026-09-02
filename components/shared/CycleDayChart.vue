<template>
  <div class="card" style="margin-top:14px;">
    <div class="card-header">
      <h3><Icon name="calendar" :size="15" /> Cycle Day Log</h3>
      <div v-if="canEdit" class="flex gap-8">
        <button v-if="!rows.length" class="btn btn-secondary btn-sm" @click="initialize"><Icon name="plus" :size="12" /> Initialize Blank 14-Day Log</button>
        <button v-else class="btn btn-secondary btn-sm" @click="addDay"><Icon name="plus" :size="12" /> Add Day</button>
      </div>
    </div>
    <p v-if="canEdit" class="hint" style="padding:10px 16px;border-bottom:1px solid var(--border);">
      No medication regimen is generated automatically. Enter only the patient-specific plan approved by the treating team.
    </p>
    <div style="overflow-x:auto;">
      <table class="data-table">
        <thead><tr><th>Day / Date</th><th>Phase</th><th>Medication / Instructions</th><th>Milestone</th><th>Checks</th><th>Notes</th><th v-if="canEdit"></th></tr></thead>
        <tbody>
          <tr v-for="row in rows" :key="row.id">
            <td class="cell-strong">Day {{ row.day }}<div class="cell-muted">{{ fmtDate(row.date) }}</div></td>
            <td><input v-if="canEdit" v-model="row.phase" class="input" placeholder="Clinical phase" /><span v-else>{{ row.phase || '—' }}</span></td>
            <td><textarea v-if="canEdit" v-model="row.medication" class="input" rows="2" placeholder="Drug, dose, route, time" /><span v-else>{{ row.medication || '—' }}</span></td>
            <td><input v-if="canEdit" v-model="row.milestone" class="input" placeholder="Scan / collection / transfer" /><span v-else>{{ row.milestone || '—' }}</span></td>
            <td>
              <label class="flex gap-8" style="font-size:11px;"><input v-model="row.medication_administered" type="checkbox" :disabled="!canEdit" /> Medication</label>
              <label class="flex gap-8" style="font-size:11px;margin-top:4px;"><input v-model="row.vitals_logged" type="checkbox" :disabled="!canEdit" /> Vitals</label>
            </td>
            <td><textarea v-if="canEdit" v-model="row.note" class="input" rows="2" placeholder="Signed clinical notes" /><span v-else>{{ row.note || '—' }}</span></td>
            <td v-if="canEdit"><button class="btn btn-primary btn-sm" @click="save(row)">Save</button></td>
          </tr>
        </tbody>
      </table>
      <div v-if="!rows.length" style="padding:18px;"><EmptyState icon="calendar" title="No day log yet" description="An authorized clinician can initialize a blank day-by-day chart." /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { createBlankCycleDays, nextBlankCycleDay } from '~/composables/useIvfProtocol'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ cycleId: string; startDate: string; canEdit?: boolean }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const rows = ref<any[]>([])

async function load() {
  if (!props.cycleId) return
  const { data, error } = await supabase.from('cycle_daily_logs').select('*').eq('cycle_id', props.cycleId).order('day')
  if (error) throw error
  rows.value = data || []
}

watch(() => props.cycleId, () => { void load() }, { immediate: true })

async function initialize() {
  const generated = createBlankCycleDays(props.cycleId, props.startDate, 14)
  await queueOrRun(
    'Blank cycle day log initialized',
    { table: 'cycle_daily_logs', kind: 'upsert', payload: generated, onConflict: 'cycle_id,day' },
    () => { rows.value = generated },
  )
}

async function addDay() {
  const row = nextBlankCycleDay(props.cycleId, props.startDate, rows.value.map((item) => item.day))
  await queueOrRun(
    `Cycle day ${row.day} added`,
    { table: 'cycle_daily_logs', kind: 'insert', payload: row },
    () => rows.value.push(row),
  )
}

async function save(row: any) {
  const payload = {
    phase: String(row.phase || '').trim(),
    medication: row.medication || null,
    milestone: row.milestone || null,
    medication_administered: Boolean(row.medication_administered),
    vitals_logged: Boolean(row.vitals_logged),
    note: row.note || null,
  }
  await queueOrRun(
    `Cycle day ${row.day} saved`,
    { table: 'cycle_daily_logs', kind: 'update', payload, match: { id: row.id }, expectedUpdatedAt: row.updated_at },
    () => Object.assign(row, payload, { updated_at: new Date().toISOString() }),
  )
}
</script>
