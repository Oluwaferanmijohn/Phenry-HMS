<template>
  <div v-if="patientId" class="grading-page">
    <div class="page-header">
      <div>
        <h1>Embryo Development Grading</h1>
        <div class="desc">{{ patientName }} — focused cohort tracking from oocyte assessment through blastocyst.</div>
      </div>
      <div class="page-actions">
        <select class="input patient-select" :value="patientId" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option>
        </select>
        <button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save grading</button>
      </div>
    </div>

    <div class="culture-timeline" aria-label="Embryo culture days">
      <button
        v-for="(day, index) in DAY_DEFS"
        :key="day.key"
        class="day-step"
        :class="{ active: activeDayKey === day.key, complete: isComplete(day) }"
        type="button"
        @click="activeDayKey = day.key"
      >
        <span class="day-index"><Icon v-if="isComplete(day)" name="check-circle" :size="15" /><span v-else>{{ index }}</span></span>
        <span class="day-copy"><b>{{ day.label }}</b><small>{{ day.shortLabel }}</small></span>
        <span class="day-count">{{ gradedSum(day) }}/{{ totalFor(day) }}</span>
      </button>
    </div>

    <div class="grading-workspace">
      <section class="card grading-editor">
        <div class="editor-head">
          <div>
            <div class="eyebrow">{{ activeDay.phase }}</div>
            <h2>{{ activeDay.label }} assessment</h2>
            <p>{{ activeDay.guidance }}</p>
          </div>
          <div class="total-field">
            <label>{{ activeDay.totalLabel }}</label>
            <input v-model.number="activeBatch.total" class="input" type="number" min="0" step="1" placeholder="0" />
          </div>
        </div>

        <div class="cohort-meter" :class="{ over: remainingFor(activeDay) < 0 }">
          <div><b>{{ gradedSum(activeDay) }}</b><span>classified</span></div>
          <div class="progress-track"><div class="progress-fill" :style="{ width: `${completionPercent(activeDay)}%` }" /></div>
          <strong>{{ remainingLabel(activeDay) }}</strong>
        </div>

        <div class="grade-toolbar">
          <div><b>Grade distribution</b><span>Record the number in each observed category.</span></div>
          <button class="btn btn-secondary btn-sm" type="button" @click="addStandardRows(activeDay)"><Icon name="plus" :size="12" /> Add standard rows</button>
        </div>

        <div v-if="activeBatch.grades.length" class="grade-list">
          <div class="grade-list-head"><span>Classification</span><span>Count</span><span>Share</span><span /></div>
          <div v-for="(grade, index) in activeBatch.grades" :key="`${activeDay.key}-${index}`" class="grade-row">
            <div class="grade-label">
              <select class="input" :value="isCustom(activeDay, grade) ? '__custom__' : grade.label" @change="setGradeLabel(activeDay, index, ($event.target as HTMLSelectElement).value)">
                <option value="" disabled>Select classification…</option>
                <option v-for="preset in activeDay.presets" :key="preset">{{ preset }}</option>
                <option value="__custom__">Custom classification…</option>
              </select>
              <input v-if="isCustom(activeDay, grade)" v-model="grade.label" class="input" placeholder="Enter custom classification" />
            </div>
            <input v-model.number="grade.count" class="input count-input" type="number" min="0" step="1" placeholder="0" />
            <span class="share-value">{{ gradeShare(activeDay, grade) }}%</span>
            <button class="icon-btn remove-row" type="button" title="Remove row" @click="activeBatch.grades.splice(index, 1)"><Icon name="trash" :size="13" /></button>
          </div>
        </div>
        <div v-else class="empty-grades">
          <div class="empty-icon"><Icon name="layers" :size="21" /></div>
          <div><b>No classifications recorded</b><p>Add the standard assessment rows or create a custom row.</p></div>
        </div>

        <button class="btn btn-secondary btn-sm custom-row-btn" type="button" @click="addCustomRow"><Icon name="plus" :size="12" /> Add custom row</button>

        <div class="editor-foot">
          <button class="btn btn-secondary" :disabled="activeDayIndex === 0" @click="moveDay(-1)"><Icon name="chevron-left" :size="13" /> Previous</button>
          <Badge :tone="dayTone(activeDay)">{{ dayStatus(activeDay) }}</Badge>
          <button class="btn btn-secondary" :disabled="activeDayIndex === DAY_DEFS.length - 1" @click="moveDay(1)">Next day <Icon name="chevron-right" :size="13" /></button>
        </div>
      </section>

      <aside class="card cohort-summary">
        <div class="card-header"><h3><Icon name="layers" :size="15" /> Cohort summary</h3><Badge tone="blue">{{ completedDays }}/{{ DAY_DEFS.length }} days</Badge></div>
        <div class="summary-body">
          <div v-for="day in DAY_DEFS" :key="day.key" class="summary-row" :class="{ selected: activeDayKey === day.key }" @click="activeDayKey = day.key">
            <span class="summary-dot" :class="{ complete: isComplete(day) }" />
            <div><b>{{ day.label }}</b><small>{{ day.shortLabel }}</small></div>
            <strong>{{ gradedSum(day) }} / {{ totalFor(day) }}</strong>
          </div>
        </div>
        <div class="summary-note"><Icon name="shield" :size="15" /><span>Day 0 captures oocyte maturity. Day 1 begins fertilization assessment.</span></div>
      </aside>
    </div>
  </div>

  <div v-else>
    <div class="page-header"><div><h1>Embryo Development Grading</h1><div class="desc">Track embryo development from Day 0 onward.</div></div></div>
    <EmptyState icon="user" title="No patients available" description="Register a patient before starting embryo grading." />
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const DAY_DEFS = [
  { key: 'day0', label: 'Day 0', shortLabel: 'Oocyte maturity', phase: 'Retrieval & maturity', totalLabel: 'Oocytes retrieved', guidance: 'Document the maturity assessment of all retrieved oocytes.', presets: ['MII (Mature)', 'MI (Immature)', 'GV (Immature)', 'Degenerated / Abnormal'] },
  { key: 'day1', label: 'Day 1', shortLabel: 'Fertilization', phase: 'Fertilization check', totalLabel: 'Oocytes assessed', guidance: 'Record pronuclear status at the fertilization check.', presets: ['2PN (Normal Fertilization)', '1PN', '0PN / Not Fertilized', '≥3PN (Abnormal Fertilization)', 'Degenerate'] },
  { key: 'day2', label: 'Day 2', shortLabel: 'Early cleavage', phase: 'Cleavage assessment', totalLabel: 'Embryos assessed', guidance: 'Capture cell stage and any fragmentation or arrest.', presets: ['4-Cell', '3-Cell', '2-Cell', 'Fragmented', 'Arrested'] },
  { key: 'day3', label: 'Day 3', shortLabel: 'Cleavage', phase: 'Cleavage assessment', totalLabel: 'Embryos assessed', guidance: 'Record developmental stage and morphology for the active cohort.', presets: ['8-Cell Grade A', '8-Cell Grade B', '7-Cell', '6-Cell', 'Fragmented', 'Arrested'] },
  { key: 'day5', label: 'Day 5/6', shortLabel: 'Blastocyst', phase: 'Blastocyst assessment', totalLabel: 'Embryos assessed', guidance: 'Document blastocyst development, morulae, and arrested embryos.', presets: ['Expanded Blastocyst', 'Full Blastocyst', 'Early Blastocyst', 'Morula', 'Arrested'] },
] as const
type DayKey = (typeof DAY_DEFS)[number]['key']
type DayDefinition = (typeof DAY_DEFS)[number]
type GradeRow = { label: string; count: string | number; custom?: boolean }
type DayBatch = { total: string | number; grades: GradeRow[] }

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const route = useRoute()
const router = useRouter()

const patients = ref<any[]>([])
const patientId = ref('')
const patientName = ref('')
const saving = ref(false)
const activeDayKey = ref<DayKey>('day0')

function emptyBatches(): Record<DayKey, DayBatch> {
  return {
    day0: { total: '', grades: [] },
    day1: { total: '', grades: [] },
    day2: { total: '', grades: [] },
    day3: { total: '', grades: [] },
    day5: { total: '', grades: [] },
  }
}
const batches = reactive(emptyBatches())
const activeDay = computed(() => DAY_DEFS.find((day) => day.key === activeDayKey.value) || DAY_DEFS[0])
const activeDayIndex = computed(() => DAY_DEFS.findIndex((day) => day.key === activeDayKey.value))
const activeBatch = computed(() => batches[activeDayKey.value])
const completedDays = computed(() => DAY_DEFS.filter(isComplete).length)

function isCustom(day: DayDefinition, grade: GradeRow) {
  return Boolean(grade.custom) || (grade.label !== '' && !(day.presets as readonly string[]).includes(grade.label))
}
function setGradeLabel(day: DayDefinition, index: number, value: string) {
  const grade = batches[day.key].grades[index]
  if (!grade) return
  grade.custom = value === '__custom__'
  grade.label = value === '__custom__' ? '' : value
}
function totalFor(day: DayDefinition) {
  return Math.max(0, Number(batches[day.key].total || 0))
}
function gradedSum(day: DayDefinition) {
  return batches[day.key].grades.reduce((sum, grade) => sum + Math.max(0, Number(grade.count || 0)), 0)
}
function remainingFor(day: DayDefinition) {
  return totalFor(day) - gradedSum(day)
}
function remainingLabel(day: DayDefinition) {
  const remaining = remainingFor(day)
  if (!totalFor(day)) return 'Set cohort total'
  if (remaining === 0) return 'Complete'
  return remaining > 0 ? `${remaining} unclassified` : `${Math.abs(remaining)} over total`
}
function completionPercent(day: DayDefinition) {
  const total = totalFor(day)
  return total ? Math.min(100, Math.round((gradedSum(day) / total) * 100)) : 0
}
function gradeShare(day: DayDefinition, grade: GradeRow) {
  const total = totalFor(day)
  return total ? Math.round((Math.max(0, Number(grade.count || 0)) / total) * 100) : 0
}
function isComplete(day: DayDefinition) {
  return totalFor(day) > 0 && remainingFor(day) === 0
}
function dayTone(day: DayDefinition): 'green' | 'amber' | 'gray' {
  if (isComplete(day)) return 'green'
  return totalFor(day) || gradedSum(day) ? 'amber' : 'gray'
}
function dayStatus(day: DayDefinition) {
  if (isComplete(day)) return 'Complete'
  if (remainingFor(day) < 0) return 'Count exceeds total'
  if (totalFor(day) || gradedSum(day)) return 'In progress'
  return 'Not started'
}
function addStandardRows(day: DayDefinition) {
  for (const preset of day.presets) {
    if (!batches[day.key].grades.some((grade) => grade.label === preset)) batches[day.key].grades.push({ label: preset, count: '' })
  }
}
function addCustomRow() {
  activeBatch.value.grades.push({ label: '', count: '', custom: true })
}
function moveDay(offset: number) {
  const next = DAY_DEFS[activeDayIndex.value + offset]
  if (next) activeDayKey.value = next.key
}

async function loadPatient(id: string) {
  const [nameRes, batchRes] = await Promise.all([
    supabase.from('patient_names').select('full_name').eq('patient_id', id).single(),
    supabase.from('embryo_batches').select('*').eq('patient_id', id),
  ])
  patientName.value = nameRes.data?.full_name || 'Unknown'
  const fresh = emptyBatches()
  for (const row of batchRes.data || []) {
    if (!(row.day_key in fresh)) continue
    const day = DAY_DEFS.find((entry) => entry.key === row.day_key)!
    fresh[row.day_key as DayKey] = {
      total: row.total ?? '',
      grades: (row.grades || []).map((grade: GradeRow) => ({ ...grade, custom: grade.label !== '' && !(day.presets as readonly string[]).includes(grade.label) })),
    }
  }
  Object.assign(batches, fresh)
}

await useAsyncData(`embryo-grading-init-${props.role}`, async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  const requestedPatient = typeof route.query.patient === 'string' ? route.query.patient : ''
  patientId.value = patients.value.some((patient) => patient.patient_id === requestedPatient) ? requestedPatient : patients.value[0]?.patient_id || ''
  if (patientId.value) await loadPatient(patientId.value)
  return true
})

function switchPatient(id: string) {
  void router.replace({ query: { ...route.query, patient: id } })
  patientId.value = id
  activeDayKey.value = 'day0'
  void loadPatient(id)
}

function validate() {
  for (const day of DAY_DEFS) {
    const batch = batches[day.key]
    const total = Number(batch.total || 0)
    if (!Number.isInteger(total) || total < 0) return `${day.label}: total must be a whole number of zero or more.`
    for (const grade of batch.grades) {
      const count = Number(grade.count || 0)
      if (!grade.label.trim() && count > 0) return `${day.label}: name the custom classification.`
      if (!Number.isInteger(count) || count < 0) return `${day.label}: classification counts must be whole numbers of zero or more.`
    }
    if ((total > 0 || gradedSum(day) > 0) && gradedSum(day) !== total) return `${day.label}: classified count must equal the cohort total before saving.`
  }
  return ''
}

async function save() {
  if (!patientId.value) return
  const validationError = validate()
  if (validationError) return toast(validationError, 'warn')
  saving.value = true
  const targetPatientId = patientId.value
  const targetPatientName = patientName.value
  const snapshot = DAY_DEFS.map((day) => ({
    patient_id: targetPatientId,
    day_key: day.key,
    total: batches[day.key].total === '' ? null : Number(batches[day.key].total),
    grades: batches[day.key].grades.filter((grade) => grade.label.trim() || Number(grade.count || 0) > 0).map((grade) => ({ label: grade.label.trim(), count: Number(grade.count || 0) })),
  }))
  try {
    await queueOrRun(`Embryo grading saved for ${targetPatientName}`, { table: 'embryo_batches', kind: 'upsert', payload: snapshot, onConflict: 'patient_id,day_key' })
  } catch (error: any) {
    if (String(error?.message || '').includes('embryo_batches_day_key_check')) {
      toast('Day 0 grading needs the latest database migration. Apply the pending Supabase migrations, then save again.', 'warn')
    }
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.grading-page { max-width: 1180px; margin: 0 auto; }
.patient-select { min-width: 250px; }
.culture-timeline { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 8px; margin-bottom: 16px; }
.day-step { display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; align-items: center; gap: 9px; min-width: 0; padding: 11px; border: 1px solid var(--border); border-radius: var(--radius-md); background: var(--card); color: var(--text-500); text-align: left; transition: .15s ease; }
.day-step:hover { border-color: var(--blue-100); transform: translateY(-1px); }
.day-step.active { border-color: var(--blue-500); background: var(--blue-50); color: var(--blue-700); box-shadow: 0 0 0 2px rgba(39, 110, 241, .08); }
.day-step.complete:not(.active) { border-color: var(--green-500); }
.day-index { width: 30px; height: 30px; display: grid; place-items: center; border-radius: 9px; background: var(--bg); border: 1px solid var(--border); font-size: 12px; font-weight: 800; }
.day-step.active .day-index { background: var(--blue-600); border-color: var(--blue-600); color: white; }
.day-step.complete:not(.active) .day-index { background: var(--green-50); border-color: var(--green-500); color: var(--green-600); }
.day-copy { min-width: 0; display: flex; flex-direction: column; }
.day-copy b { color: var(--text-900); font-size: 13px; }
.day-copy small { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 10.5px; }
.day-count { font-size: 11px; font-weight: 700; }
.grading-workspace { display: grid; grid-template-columns: minmax(0, 1fr) 280px; gap: 16px; align-items: start; }
.grading-editor { overflow: hidden; }
.editor-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 24px; padding: 22px 24px 18px; border-bottom: 1px solid var(--border); }
.eyebrow { margin-bottom: 5px; color: var(--blue-600); font-size: 10.5px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }
.editor-head h2 { margin: 0 0 5px; font-size: 19px; color: var(--text-900); }
.editor-head p { margin: 0; max-width: 520px; color: var(--text-500); font-size: 12px; }
.total-field { width: 136px; flex-shrink: 0; }
.total-field label { display: block; margin-bottom: 5px; color: var(--text-500); font-size: 10.5px; font-weight: 700; }
.total-field .input { font-size: 18px; font-weight: 750; text-align: center; }
.cohort-meter { display: grid; grid-template-columns: auto minmax(100px, 1fr) auto; align-items: center; gap: 14px; margin: 16px 24px; padding: 12px 14px; border-radius: var(--radius-sm); background: var(--blue-50); color: var(--text-700); }
.cohort-meter > div:first-child { display: flex; align-items: baseline; gap: 5px; font-size: 11px; }
.cohort-meter b { font-size: 17px; color: var(--blue-700); }
.cohort-meter strong { font-size: 11.5px; color: var(--blue-700); }
.cohort-meter.over { background: var(--red-50); }
.cohort-meter.over strong, .cohort-meter.over b { color: var(--red-600); }
.progress-fill { height: 100%; border-radius: inherit; background: var(--blue-500); transition: width .2s ease; }
.cohort-meter.over .progress-fill { background: var(--red-500); }
.grade-toolbar { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 4px 24px 10px; }
.grade-toolbar > div { display: flex; flex-direction: column; gap: 2px; }
.grade-toolbar b { font-size: 12.5px; }
.grade-toolbar span { color: var(--text-500); font-size: 11px; }
.grade-list { margin: 0 24px; border: 1px solid var(--border); border-radius: var(--radius-sm); overflow: hidden; }
.grade-list-head, .grade-row { display: grid; grid-template-columns: minmax(230px, 1fr) 88px 62px 32px; align-items: center; gap: 10px; }
.grade-list-head { padding: 8px 12px; background: var(--bg); color: var(--text-500); font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; }
.grade-row { padding: 9px 12px; border-top: 1px solid var(--border); }
.grade-label { display: grid; grid-template-columns: minmax(0, 1fr); gap: 7px; }
.grade-label:has(input) { grid-template-columns: minmax(150px, .85fr) minmax(160px, 1fr); }
.count-input { text-align: center; }
.share-value { color: var(--text-500); font-size: 12px; font-weight: 700; text-align: center; }
.remove-row { color: var(--red-600); }
.empty-grades { display: flex; align-items: center; gap: 12px; margin: 0 24px; padding: 21px; border: 1px dashed var(--border-strong); border-radius: var(--radius-sm); color: var(--text-500); }
.empty-icon { width: 42px; height: 42px; display: grid; place-items: center; flex-shrink: 0; border-radius: 12px; background: var(--blue-50); color: var(--blue-600); }
.empty-grades b { color: var(--text-900); font-size: 12.5px; }
.empty-grades p { margin: 3px 0 0; font-size: 11.5px; }
.custom-row-btn { margin: 10px 24px 0; border-style: dashed; }
.editor-foot { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; gap: 10px; margin-top: 20px; padding: 14px 24px; border-top: 1px solid var(--border); background: var(--bg); }
.editor-foot .btn:last-child { justify-self: end; }
.cohort-summary { overflow: hidden; }
.summary-body { padding: 8px; }
.summary-row { display: grid; grid-template-columns: 10px minmax(0, 1fr) auto; align-items: center; gap: 10px; padding: 11px 9px; border-radius: 8px; cursor: pointer; }
.summary-row:hover, .summary-row.selected { background: var(--blue-50); }
.summary-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--border-strong); }
.summary-dot.complete { background: var(--green-500); box-shadow: 0 0 0 3px var(--green-50); }
.summary-row div { display: flex; flex-direction: column; }
.summary-row b { color: var(--text-900); font-size: 12px; }
.summary-row small { color: var(--text-500); font-size: 10.5px; }
.summary-row strong { color: var(--text-700); font-size: 11.5px; }
.summary-note { display: flex; align-items: flex-start; gap: 8px; margin: 0 12px 12px; padding: 11px; border-radius: 8px; background: var(--bg); color: var(--text-500); font-size: 10.5px; line-height: 1.45; }
.summary-note svg { flex-shrink: 0; color: var(--blue-600); }
@media (max-width: 1000px) {
  .culture-timeline { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .grading-workspace { grid-template-columns: 1fr; }
  .cohort-summary { display: none; }
}
@media (max-width: 700px) {
  .culture-timeline { display: flex; overflow-x: auto; padding-bottom: 4px; }
  .day-step { min-width: 165px; }
  .editor-head { flex-direction: column; }
  .total-field { width: 100%; }
  .grade-list-head { display: none; }
  .grade-row { grid-template-columns: minmax(0, 1fr) 76px 32px; }
  .grade-label { grid-column: 1 / -1; }
  .grade-label:has(input) { grid-template-columns: 1fr; }
  .share-value { text-align: left; }
}
</style>
