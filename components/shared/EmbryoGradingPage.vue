<template>
  <div v-if="patientId">
    <div class="page-header">
      <div><h1>Embryo Development Grading</h1><div class="desc">{{ patientName }} — bulk entry by day, built for cohorts of 40+ embryos.</div></div>
      <div class="page-actions">
        <select class="input" :value="patientId" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
      </div>
    </div>
    <div style="display:flex; flex-direction:column; gap:16px;">
      <div v-for="d in DAY_DEFS" :key="d.key" class="card card-pad">
        <div class="flex-between">
          <b style="font-size:14px;">{{ d.label }}</b>
          <div class="flex gap-8" style="align-items:center;">
            <label class="cell-muted" style="font-size:12px;">Total Embryos</label>
            <input v-model.number="batches[d.key].total" class="input" style="width:90px;" type="number" placeholder="0" />
          </div>
        </div>
        <div style="margin-top:12px; display:flex; flex-direction:column; gap:8px;">
          <p v-if="!batches[d.key].grades.length" class="muted" style="font-size:12px;">No grade rows yet — add one below.</p>
          <div v-for="(g, i) in batches[d.key].grades" :key="i" class="flex gap-10">
            <select class="input" style="flex:1;" :value="isCustom(d, g) ? '__custom__' : g.label" @change="setGradeLabel(d, i, ($event.target as HTMLSelectElement).value)">
              <option value="" disabled>Select grade…</option>
              <option v-for="pr in d.presets" :key="pr">{{ pr }}</option>
              <option value="__custom__">Custom…</option>
            </select>
            <input v-if="isCustom(d, g)" v-model="g.label" class="input" style="flex:1;" placeholder="Custom grade label" />
            <input v-model.number="g.count" class="input" style="width:90px;" type="number" placeholder="Count" />
            <button class="icon-btn" style="color:var(--red-600);" @click="batches[d.key].grades.splice(i, 1)"><Icon name="trash" :size="13" /></button>
          </div>
        </div>
        <button class="btn btn-secondary btn-sm" style="margin-top:10px;" @click="batches[d.key].grades.push({ label: '', count: '' })"><Icon name="plus" :size="12" /> Add Grade Row</button>
        <div style="margin-top:10px;">
          <Badge :tone="matchTone(d)">{{ matchTone(d) === 'green' ? '✓' : '⚠' }} Graded {{ gradedSum(d) }} / {{ batches[d.key].total || 0 }}</Badge>
        </div>
      </div>
    </div>
    <div style="margin-top:18px; text-align:right;">
      <button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save &amp; Sync Data</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const DAY_DEFS = [
  { key: 'day1', label: 'Day 1', presets: ['2PN (Normal Fertilization)', '1PN', '0PN / Not Fertilized', 'Degenerate'] },
  { key: 'day2', label: 'Day 2', presets: ['4-Cell', '2-Cell', 'Fragmented', 'Arrested'] },
  { key: 'day3', label: 'Day 3', presets: ['8-Cell Grade A', '8-Cell Grade B', '6-Cell', 'Arrested'] },
  { key: 'day5', label: 'Day 5/6', presets: ['Expanded Blastocyst', 'Early Blastocyst', 'Morula', 'Arrested'] },
]

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const route = useRoute()
const router = useRouter()

const patients = ref<any[]>([])
const patientId = ref('')
const patientName = ref('')
const saving = ref(false)

function emptyBatches() {
  return { day1: { total: '', grades: [] as any[] }, day2: { total: '', grades: [] as any[] }, day3: { total: '', grades: [] as any[] }, day5: { total: '', grades: [] as any[] } }
}
const batches = reactive(emptyBatches())

function isCustom(d: any, g: any) {
  return g.label !== '' && !d.presets.includes(g.label)
}
function setGradeLabel(d: any, i: number, val: string) {
  batches[d.key].grades[i].label = val === '__custom__' ? '' : val
}
function gradedSum(d: any) {
  return batches[d.key].grades.reduce((s: number, g: any) => s + Number(g.count || 0), 0)
}
function matchTone(d: any) {
  const total = Number(batches[d.key].total || 0)
  return total > 0 && gradedSum(d) === total ? 'green' : 'amber'
}

async function loadPatient(id: string) {
  const [nameRes, batchRes] = await Promise.all([
    supabase.from('patient_names').select('full_name').eq('patient_id', id).single(),
    supabase.from('embryo_batches').select('*').eq('patient_id', id),
  ])
  patientName.value = nameRes.data?.full_name || 'Unknown'
  const fresh = emptyBatches()
  for (const row of batchRes.data || []) {
    ;(fresh as any)[row.day_key] = { total: row.total ?? '', grades: row.grades || [] }
  }
  Object.assign(batches, fresh)
}

await useAsyncData(`embryo-grading-init-${props.role}`, async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  patientId.value = (route.query.patient as string) || patients.value[0]?.patient_id || ''
  if (patientId.value) await loadPatient(patientId.value)
  return true
})

function switchPatient(id: string) {
  router.replace({ query: { ...route.query, patient: id } })
  patientId.value = id
  loadPatient(id)
}

async function save() {
  if (!patientId.value) return
  saving.value = true
  const targetPatientId = patientId.value
  const targetPatientName = patientName.value
  const snapshot = DAY_DEFS.map((d) => ({
    patient_id: targetPatientId,
    day_key: d.key,
    total: batches[d.key].total === '' ? null : Number(batches[d.key].total),
    grades: [...batches[d.key].grades],
  }))
  await queueOrRun(`Embryo grading saved for ${targetPatientName}`, async () => {
    const { error } = await supabase.from('embryo_batches').upsert(snapshot, { onConflict: 'patient_id,day_key' })
    if (error) throw error
  })
  saving.value = false
}
</script>
