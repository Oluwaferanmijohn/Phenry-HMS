<template>
  <Modal :model-value="modelValue" :title="schedule ? `${schedule.procedure} Laboratory Report` : 'Fertility Procedure Report'" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="schedule">
      <div class="report-banner">
        <div><span>PATIENT</span><b>{{ schedule.patient_name }} · {{ schedule.patient_id }}</b></div>
        <div><span>SCHEDULED</span><b>{{ fmtDate(schedule.date) }} · {{ formatTime12(schedule.time) }}</b></div>
        <div><span>REPORT</span><StatusBadge :status="savedStatus || 'Draft'" /></div>
      </div>

      <section class="report-section">
        <div class="section-title"><span>1</span><div><b>Safety, identity &amp; team</b><small>Required checks and people involved in the procedure.</small></div></div>
        <div class="check-grid">
          <label><input v-model="common.identityVerified" type="checkbox" /> Two patient identifiers verified</label>
          <label><input v-model="common.consentVerified" type="checkbox" /> Procedure consent verified</label>
          <label><input v-model="common.witnessCheck" type="checkbox" /> Independent witness check completed</label>
          <label><input v-model="common.timeOutCompleted" type="checkbox" /> Team time-out completed</label>
        </div>
        <div class="form-row" style="margin-top:11px;">
          <div class="field"><label>Lead Clinician</label><input v-model="common.clinician" class="input" /></div>
          <div class="field"><label>Embryologist / Laboratory Scientist</label><input v-model="common.embryologist" class="input" /></div>
          <div class="field"><label>Witness</label><input v-model="common.witness" class="input" /></div>
        </div>
        <div class="form-row">
          <div class="field"><label>Procedure Start</label><input v-model="common.startedAt" class="input" type="time" /></div>
          <div class="field"><label>Procedure End</label><input v-model="common.completedAt" class="input" type="time" /></div>
          <div class="field"><label>Location</label><input v-model="common.location" class="input" :placeholder="schedule.location || 'Procedure room / laboratory'" /></div>
        </div>
      </section>

      <section class="report-section">
        <div class="section-title"><span>2</span><div><b>{{ sectionHeading }}</b><small>{{ sectionGuidance }}</small></div></div>
        <div class="dynamic-grid">
          <div v-for="field in fields" :key="field.key" class="field" :class="{ wide: field.type === 'textarea' }">
            <label>{{ field.label }}</label>
            <textarea v-if="field.type === 'textarea'" v-model="details[field.key]" class="input" rows="3" :placeholder="field.placeholder" />
            <select v-else-if="field.type === 'select'" v-model="details[field.key]" class="input"><option value="">Select…</option><option v-for="option in field.options" :key="option">{{ option }}</option></select>
            <input v-else v-model="details[field.key]" class="input" :type="field.type" :min="field.type === 'number' ? 0 : undefined" :placeholder="field.placeholder" />
          </div>
        </div>
      </section>

      <section class="report-section">
        <div class="section-title"><span>3</span><div><b>Outcome &amp; sign-off</b><small>Record the final outcome, deviations, and follow-up plan.</small></div></div>
        <div class="form-row">
          <div class="field"><label>Procedure Outcome</label><select v-model="outcome.result" class="input"><option>Completed as planned</option><option>Partially completed</option><option>Abandoned</option><option>Cancelled after preparation</option></select></div>
          <div class="field"><label>Complications / Deviations</label><select v-model="outcome.complications" class="input"><option>None</option><option>Minor — documented below</option><option>Major — escalated</option></select></div>
        </div>
        <div class="field"><label>Findings, deviations, and clinical notes</label><textarea v-model="outcome.notes" class="input" rows="4" placeholder="Procedure narrative, laboratory findings, complications, and any deviation from protocol" /></div>
        <div class="field"><label>Follow-up / Handover</label><textarea v-model="outcome.followUp" class="input" rows="2" placeholder="Instructions to the doctor, matron, nursing team, patient, or next laboratory stage" /></div>
        <p v-if="documentedByName" class="signed-note">Last documented by {{ documentedByName }}<template v-if="documentedAt"> on {{ fmtDate(documentedAt) }}</template>.</p>
      </section>
    </template>

    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button>
      <button v-if="schedule && procedureSupportsCryo(schedule.procedure)" class="btn btn-secondary" @click="requestStorage"><Icon name="snow" :size="13" /> Record Frozen Specimens</button>
      <button class="btn btn-secondary" :disabled="saving" @click="save('Draft')"><Icon name="file" :size="13" /> Save Draft</button>
      <button class="btn btn-primary" :disabled="saving" @click="save('Completed')"><Icon name="check-circle" :size="13" /> Complete &amp; Sign</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'
import { procedureCategory, procedureSupportsCryo } from '~/composables/useFertilityProcedures'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

type Field = { key: string; label: string; type: 'text' | 'number' | 'textarea' | 'select'; placeholder?: string; options?: string[] }
const props = defineProps<{ modelValue: boolean; schedule: any | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: []; 'store-specimen': [any] }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const saving = ref(false)
const savedStatus = ref('Draft')
const documentedByName = ref('')
const documentedAt = ref('')
const common = reactive({ identityVerified: false, consentVerified: false, witnessCheck: false, timeOutCompleted: false, clinician: '', embryologist: '', witness: '', startedAt: '', completedAt: '', location: '' })
const details = reactive<Record<string, any>>({})
const outcome = reactive({ result: 'Completed as planned', complications: 'None', notes: '', followUp: '' })

const category = computed(() => procedureCategory(props.schedule?.procedure))
const sectionHeading = computed(() => ({
  opu: 'Oocyte retrieval record', transfer: 'Embryo transfer record', iui: 'IUI preparation & insemination record',
  sperm: 'Sperm procedure record', freezing: 'Cryopreservation procedure record', other: 'Procedure details',
}[category.value]))
const sectionGuidance = computed(() => ({
  opu: 'Document follicle aspiration and the oocyte yield received by the laboratory.',
  transfer: 'Document embryo selection, catheter procedure, and transfer outcome.',
  iui: 'Capture semen preparation and post-wash parameters together with insemination details.',
  sperm: 'Document collection or retrieval, preparation, quality, and disposition.',
  freezing: 'Document the freezing method, specimen quality, and final disposition.',
  other: 'Capture procedure-specific observations and results.',
}[category.value]))

const FIELD_LIBRARY: Record<string, Field[]> = {
  opu: [
    { key: 'folliclesAspirated', label: 'Follicles Aspirated', type: 'number' }, { key: 'oocytesRetrieved', label: 'Total Oocytes Retrieved', type: 'number' },
    { key: 'mii', label: 'MII (Mature)', type: 'number' }, { key: 'mi', label: 'MI', type: 'number' }, { key: 'gv', label: 'GV', type: 'number' },
    { key: 'degenerate', label: 'Degenerated / Abnormal', type: 'number' }, { key: 'aspirationMethod', label: 'Aspiration Method / Needle', type: 'text' },
    { key: 'laboratoryDisposition', label: 'Laboratory Disposition', type: 'textarea', placeholder: 'ICSI, IVF insemination, vitrification, discard, or observation' },
  ],
  transfer: [
    { key: 'transferType', label: 'Transfer Type', type: 'select', options: ['Fresh', 'Frozen (FET)', 'Donor embryo'] },
    { key: 'embryosTransferred', label: 'Embryos Transferred', type: 'number' }, { key: 'embryoGrades', label: 'Embryo Grade(s)', type: 'text', placeholder: 'e.g. 4AA, 3AB' },
    { key: 'developmentDay', label: 'Embryo Day', type: 'select', options: ['Day 2', 'Day 3', 'Day 5', 'Day 6', 'Day 7'] },
    { key: 'catheter', label: 'Catheter / Device', type: 'text' }, { key: 'ultrasoundGuidance', label: 'Ultrasound Guidance', type: 'select', options: ['Yes', 'No'] },
    { key: 'transferDifficulty', label: 'Transfer Difficulty', type: 'select', options: ['Easy', 'Moderate', 'Difficult'] }, { key: 'catheterCheck', label: 'Post-transfer Catheter Check', type: 'select', options: ['Clear', 'Retained embryo — re-transfer performed', 'Other'] },
  ],
  iui: [
    { key: 'sampleSource', label: 'Sample Source', type: 'select', options: ['Partner', 'Donor', 'Frozen partner sample', 'Frozen donor sample'] },
    { key: 'preparationMethod', label: 'Preparation Method', type: 'select', options: ['Density gradient', 'Swim-up', 'Wash', 'Other'] },
    { key: 'preWashVolume', label: 'Pre-wash Volume (mL)', type: 'number' }, { key: 'preWashConcentration', label: 'Pre-wash Concentration (million/mL)', type: 'number' },
    { key: 'postWashVolume', label: 'Post-wash Volume (mL)', type: 'number' }, { key: 'postWashConcentration', label: 'Post-wash Concentration (million/mL)', type: 'number' },
    { key: 'postWashMotility', label: 'Post-wash Progressive Motility (%)', type: 'number' }, { key: 'totalMotileCount', label: 'Total Motile Sperm Count (million)', type: 'number' },
    { key: 'catheter', label: 'IUI Catheter', type: 'text' }, { key: 'inseminationDifficulty', label: 'Insemination Difficulty', type: 'select', options: ['Easy', 'Moderate', 'Difficult'] },
  ],
  sperm: [
    { key: 'collectionMethod', label: 'Collection / Retrieval Method', type: 'select', options: ['Ejaculate', 'TESA', 'TESE', 'PESA', 'MESA', 'Micro-TESE', 'Thaw'] },
    { key: 'volume', label: 'Volume (mL)', type: 'number' }, { key: 'concentration', label: 'Concentration (million/mL)', type: 'number' },
    { key: 'progressiveMotility', label: 'Progressive Motility (%)', type: 'number' }, { key: 'viability', label: 'Viability (%)', type: 'number' },
    { key: 'preparationMethod', label: 'Preparation Method', type: 'text' }, { key: 'disposition', label: 'Final Disposition', type: 'textarea', placeholder: 'Used fresh, frozen, discarded, or sent for another procedure' },
  ],
  freezing: [
    { key: 'specimenType', label: 'Specimen Type', type: 'select', options: ['Embryo', 'Oocyte', 'Sperm'] },
    { key: 'numberFrozen', label: 'Number Frozen', type: 'number' }, { key: 'storageUnits', label: 'Number of Straws / Vials / Cryotops', type: 'number' },
    { key: 'freezeMethod', label: 'Method', type: 'select', options: ['Vitrification', 'Slow freezing', 'Other'] }, { key: 'cryoprotectantKit', label: 'Cryoprotectant / Kit & Lot', type: 'text' },
    { key: 'qualityBeforeFreeze', label: 'Quality / Grade Before Freezing', type: 'text' }, { key: 'disposition', label: 'Disposition Notes', type: 'textarea' },
  ],
  other: [
    { key: 'indication', label: 'Indication', type: 'textarea' }, { key: 'method', label: 'Method / Protocol', type: 'textarea' }, { key: 'findings', label: 'Findings', type: 'textarea' },
  ],
}
const fields = computed(() => FIELD_LIBRARY[category.value] || FIELD_LIBRARY.other)

function reset() {
  Object.assign(common, { identityVerified: false, consentVerified: false, witnessCheck: false, timeOutCompleted: false, clinician: '', embryologist: '', witness: '', startedAt: '', completedAt: '', location: props.schedule?.location || '' })
  for (const key of Object.keys(details)) delete details[key]
  Object.assign(outcome, { result: 'Completed as planned', complications: 'None', notes: '', followUp: '' })
  savedStatus.value = 'Draft'; documentedByName.value = ''; documentedAt.value = ''
}

watch(() => [props.modelValue, props.schedule?.id], async ([open]) => {
  if (!open || !props.schedule?.id) return
  reset()
  const { data } = await supabase.from('fertility_procedure_reports').select('*, profiles:documented_by(full_name)').eq('schedule_id', props.schedule.id).maybeSingle()
  if (!data) return
  Object.assign(common, data.documentation?.common || {})
  Object.assign(details, data.documentation?.details || {})
  Object.assign(outcome, data.documentation?.outcome || {})
  savedStatus.value = data.status
  documentedByName.value = data.profiles?.full_name || ''
  documentedAt.value = data.documented_at || data.updated_at
}, { immediate: true })

function validateComplete() {
  if (!common.identityVerified || !common.consentVerified || !common.timeOutCompleted) return 'Complete patient identity, consent, and team time-out checks before signing.'
  if (!common.embryologist.trim()) return 'Enter the embryologist or laboratory scientist responsible.'
  if (!outcome.notes.trim()) return 'Enter the procedure findings and outcome notes before signing.'
  return ''
}

async function save(status: 'Draft' | 'Completed') {
  if (!props.schedule?.id) return
  if (status === 'Completed') {
    const error = validateComplete()
    if (error) return toast(error, 'warn')
  }
  saving.value = true
  const payload = { common: { ...common }, details: { ...details }, outcome: { ...outcome } }
  try {
    await queueOrRun(`${props.schedule.procedure} report ${status === 'Completed' ? 'completed' : 'saved as draft'}`, {
      kind: 'rpc', rpcName: 'save_fertility_procedure_report',
      payload: { p_schedule_id: props.schedule.id, p_documentation: payload, p_status: status },
    }, () => emit('saved'))
    savedStatus.value = status
    if (status === 'Completed') emit('update:modelValue', false)
  } finally { saving.value = false }
}

function requestStorage() {
  emit('store-specimen', props.schedule)
  emit('update:modelValue', false)
}
</script>

<style scoped>
.report-banner { display:grid; grid-template-columns:1.2fr 1fr auto; align-items:center; gap:12px; margin-bottom:15px; padding:12px 14px; border-radius:var(--radius-sm); background:var(--blue-50); }.report-banner div { display:flex; flex-direction:column; gap:3px; }.report-banner span { color:var(--text-500); font-size:9.5px; font-weight:700; letter-spacing:.04em; }.report-banner b { font-size:12px; }
.report-section { padding:15px 0; border-top:1px solid var(--border); }.report-section:first-of-type { border-top:0; }.section-title { display:flex; align-items:flex-start; gap:10px; margin-bottom:12px; }.section-title > span { width:24px; height:24px; display:grid; place-items:center; flex:0 0 24px; border-radius:7px; background:var(--blue-600); color:#fff; font-size:11px; font-weight:800; }.section-title div { display:flex; flex-direction:column; gap:2px; }.section-title b { font-size:13px; }.section-title small { color:var(--text-500); font-size:10.5px; }
.check-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; }.check-grid label { display:flex; align-items:center; gap:8px; padding:9px 10px; border:1px solid var(--border); border-radius:7px; font-size:11.5px; }
.dynamic-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:10px; }.dynamic-grid .wide { grid-column:1 / -1; }.signed-note { margin-top:9px; color:var(--text-500); font-size:10.5px; }
@media (max-width:700px) { .report-banner,.dynamic-grid,.check-grid { grid-template-columns:1fr; }.dynamic-grid .wide { grid-column:auto; } }
</style>
