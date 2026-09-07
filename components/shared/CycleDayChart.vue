<template>
  <section class="cycle-chart card">
    <header class="chart-header">
      <div>
        <div class="eyebrow">Shared digital treatment record</div>
        <h3><Icon name="calendar" :size="16" /> Fertility Cycle Chart</h3>
        <p>{{ cycleInfo.protocol || 'Patient-specific protocol' }} · Dates and instructions are editable by Doctor, Matron, and Nurse.</p>
      </div>
      <div class="chart-actions">
        <button class="btn btn-secondary btn-sm" :disabled="!rows.length" @click="printChart"><Icon name="printer" :size="12" /> Print / Save PDF</button>
        <button v-if="canEdit && !rows.length" class="btn btn-primary btn-sm" @click="initialize"><Icon name="plus" :size="12" /> Use Standard Buserelin Chart</button>
        <button v-if="canEdit && rows.length" class="btn btn-secondary btn-sm" @click="openTemplateForm"><Icon name="layers" :size="12" /> Save as Template</button>
        <button v-if="canEdit && rows.length" class="btn btn-secondary btn-sm" @click="addDay"><Icon name="plus" :size="12" /> Add Another Day</button>
      </div>
    </header>

    <div v-if="migrationError" class="migration-warning"><Icon name="alert" :size="14" /> {{ migrationError }}</div>

    <div v-if="todayRow" class="today-card">
      <div class="today-icon"><Icon name="activity" :size="18" /></div>
      <div class="today-copy">
        <span>Today · {{ phaseLabel(todayRow.phase_key) }} Day {{ todayRow.phase_day }}</span>
        <b>{{ todayRow.medication || 'No medication instruction entered' }}</b>
        <small v-if="todayRow.milestone">{{ todayRow.milestone }}</small>
      </div>
      <StatusBadge :status="todayRow.action_status" />
    </div>

    <div v-if="rows.length" class="chart-legend">
      <span><i class="legend-dot planned" /> Planned instruction</span>
      <span><i class="legend-dot done" /> Administered/completed</span>
      <span><i class="legend-dot attention" /> Held, missed, or changed</span>
      <span class="legend-help">Day numbers restart when Stimulation begins.</span>
    </div>

    <div v-for="group in phaseGroups" :key="group.key" class="phase-section">
      <div class="phase-heading">
        <div><span class="phase-number">{{ group.key === 'down_regulation' ? '1' : group.key === 'stimulation' ? '2' : '•' }}</span><div><b>{{ group.label }}</b><small>{{ group.description }}</small></div></div>
        <Badge :tone="group.key === 'down_regulation' ? 'purple' : 'blue'">{{ group.rows.length }} days</Badge>
      </div>

      <div class="chart-scroll">
        <table class="cycle-table">
          <thead><tr><th>Day &amp; Date</th><th>Planned Medication / Instructions</th><th>Scan / Procedure</th><th>Status</th><th>Administration &amp; Signature</th><th>Clinical Notes</th><th v-if="canEdit" /></tr></thead>
          <tbody>
            <tr v-for="row in group.rows" :key="row.id" :class="{ 'today-row': row.date === today }">
              <td class="day-cell" data-label="Day & Date"><b>Day {{ row.phase_day }}</b><input v-if="canEdit" v-model="row.date" class="input date-input" type="date" /><span v-else>{{ fmtDate(row.date) }}</span><small>{{ weekday(row.date) }}</small></td>
              <td data-label="Planned Medication / Instructions">
                <textarea v-if="canEdit" v-model="row.medication" class="input compact-area" rows="2" placeholder="Drug, dose, route and time" />
                <div v-else class="instruction-text">{{ row.medication || 'No instruction recorded' }}</div>
                <div v-if="row.change_reason" class="change-note"><Icon name="edit" :size="10" /> Changed: {{ row.change_reason }}</div>
              </td>
              <td data-label="Scan / Procedure"><input v-if="canEdit" v-model="row.milestone" class="input" placeholder="Scan / collection / transfer" /><span v-else>{{ row.milestone || '—' }}</span></td>
              <td data-label="Status">
                <select v-if="canEdit" v-model="row.action_status" class="input status-select"><option v-for="status in STATUSES" :key="status">{{ status }}</option></select>
                <StatusBadge v-else :status="row.action_status" />
              </td>
              <td class="administration-cell" data-label="Administration & Signature">
                <template v-if="canEdit">
                  <textarea v-model="row.actual_medication" class="input compact-area" rows="2" placeholder="What was actually given" />
                  <button v-if="!row.medication_administered" class="btn btn-success btn-sm give-button" @click="markAdministered(row)"><Icon name="check-circle" :size="11" /> Mark Given</button>
                  <div v-else class="signed-chip"><Icon name="check-circle" :size="11" /> {{ signatureName(row) }}<small>{{ formatSignedAt(row.administered_at) }}</small></div>
                </template>
                <template v-else>
                  <div v-if="row.actual_medication" class="actual-text">{{ row.actual_medication }}</div>
                  <div v-if="row.medication_administered" class="signed-chip"><Icon name="check-circle" :size="11" /> {{ signatureName(row) }}<small>{{ formatSignedAt(row.administered_at) }}</small></div>
                  <span v-else class="cell-muted">Not yet administered</span>
                </template>
              </td>
              <td data-label="Clinical Notes">
                <textarea v-if="canEdit" v-model="row.note" class="input compact-area" rows="2" placeholder="Observation, symptoms, reason held…" />
                <span v-else class="note-text">{{ row.note || '—' }}</span>
                <input v-if="canEdit && planChanged(row)" v-model="row._pendingReason" class="input reason-input" placeholder="Reason for changing the plan (required)" />
              </td>
              <td v-if="canEdit" class="save-cell" data-label="Action"><button class="btn btn-primary btn-sm" @click="save(row)">Save Day</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div v-if="!rows.length" class="empty-chart">
      <EmptyState icon="calendar" title="No cycle chart yet" :description="canEdit ? 'Start with the hospital Standard Buserelin chart. You can then adjust every day for this patient.' : 'The clinical team has not published the daily cycle chart yet.'" />
    </div>

    <article class="cycle-print-target">
      <header class="print-header">
        <div class="print-brand">
          <img v-if="logoUrl" :src="logoUrl" alt="Hospital logo" />
          <div v-else class="print-logo-fallback">{{ clinicInitial }}</div>
          <div><h1>{{ clinic.clinic_name || clinic.company_name || 'Fertility Centre' }}</h1><p>{{ clinicAddress }}</p><p>{{ clinicContacts }}</p></div>
        </div>
        <div class="print-title"><span>Patient Treatment Record</span><h2>Standard Cycle Chart</h2><b>{{ cycleInfo.protocol || 'Individual Protocol' }}</b></div>
      </header>
      <section class="print-patient-grid">
        <div><span>Patient</span><b>{{ resolvedPatientName }}</b></div><div><span>Patient ID</span><b>{{ resolvedPatientId }}</b></div>
        <div><span>Cycle</span><b>{{ cycleInfo.type || 'Fertility Cycle' }} · No. {{ cycleInfo.cycle_number || '—' }}</b></div><div><span>Start date</span><b>{{ fmtDate(startDate) }}</b></div>
      </section>
      <section v-for="(group, groupIndex) in phaseGroups" :key="`print-${group.key}`" class="print-phase" :class="{ first: groupIndex === 0 }">
        <div class="print-phase-title"><h3>{{ group.label }}</h3><span>{{ group.description }}</span></div>
        <table class="print-table"><thead><tr><th>Date</th><th>Day</th><th>Medication / Instructions</th><th>Scan / Procedure</th><th>Status / Signature</th></tr></thead>
          <tbody><tr v-for="row in group.rows" :key="`print-${row.id}`"><td>{{ printDate(row.date) }}<small>{{ weekday(row.date) }}</small></td><td><b>Day {{ row.phase_day }}</b></td><td>{{ row.medication || '—' }}<small v-if="row.actual_medication && row.actual_medication !== row.medication">Given: {{ row.actual_medication }}</small><small v-if="row.change_reason">Changed: {{ row.change_reason }}</small></td><td>{{ row.milestone || '—' }}</td><td><b>{{ row.action_status }}</b><small v-if="row.medication_administered">{{ signatureName(row) }} · {{ formatSignedAt(row.administered_at) }}</small></td></tr></tbody>
        </table>
      </section>
      <footer class="print-footer"><span>Generated {{ new Date().toLocaleString('en-GB') }}</span><span>This is the patient's current digital cycle plan. Follow the latest instruction issued by the clinical team.</span></footer>
    </article>

    <Modal v-model="showTemplateForm" title="Save Reusable Cycle Template">
      <div class="template-safety">
        <Icon name="shield" :size="16" />
        <span>Only the planned days, medication instructions and procedures are saved. This patient's administration records, signatures and clinical notes are excluded.</span>
      </div>
      <div class="field">
        <label>Template Name</label>
        <input v-model="templateName" class="input" maxlength="100" placeholder="e.g. Antagonist IVF Standard Plan" />
      </div>
      <div class="field">
        <label>Description <span class="label-optional">optional</span></label>
        <textarea v-model="templateDescription" class="input" rows="3" placeholder="When should the team use this plan?" />
      </div>
      <template #footer>
        <button class="btn btn-secondary" @click="showTemplateForm = false">Cancel</button>
        <button class="btn btn-primary" :disabled="savingTemplate || templateName.trim().length < 3" @click="saveAsTemplate">
          <Icon name="check-circle" :size="13" /> {{ savingTemplate ? 'Saving…' : 'Save Template' }}
        </button>
      </template>
    </Modal>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { nextPhaseCycleDay } from '~/composables/useIvfProtocol'
import { useProfile } from '~/composables/useAuth'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const props = withDefaults(defineProps<{ cycleId: string; startDate: string; canEdit?: boolean; patientName?: string; patientId?: string }>(), { canEdit: false, patientName: '', patientId: '' })
const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const rows = ref<any[]>([])
const cycleInfo = ref<any>({})
const clinic = ref<any>({})
const migrationError = ref('')
const showTemplateForm = ref(false)
const templateName = ref('')
const templateDescription = ref('')
const savingTemplate = ref(false)
const today = new Date().toISOString().slice(0, 10)
const STATUSES = ['Planned', 'Administered', 'Completed', 'Held', 'Missed', 'Changed']

async function load() {
  if (!props.cycleId) return
  migrationError.value = ''
  const [logsRes, cycleRes, clinicRes] = await Promise.all([
    supabase.from('cycle_daily_logs').select('*, administered_by_profile:administered_by(full_name), updated_by_profile:updated_by(full_name)').eq('cycle_id', props.cycleId).order('day'),
    supabase.from('cycles').select('*, patient_names(full_name)').eq('id', props.cycleId).single(),
    supabase.from('clinic_settings').select('*').eq('id', 1).maybeSingle(),
  ])
  if (logsRes.error) {
    migrationError.value = /phase_key|phase_day|action_status|administered_by/i.test(logsRes.error.message)
      ? 'Install the Standard Buserelin cycle-chart database update before using this page.'
      : logsRes.error.message
    rows.value = []
  } else {
    rows.value = (logsRes.data || []).map((row: any) => ({
      ...row,
      _originalMedication: row.medication || null,
      _originalMilestone: row.milestone || null,
      _originalDate: row.date,
      _pendingReason: '',
    }))
  }
  cycleInfo.value = cycleRes.data || {}
  clinic.value = clinicRes.data || {}
}

watch(() => props.cycleId, () => { void load() }, { immediate: true })

const phaseGroups = computed(() => {
  const definitions = [
    { key: 'down_regulation', label: 'Down-Regulation Phase', description: 'Preparation and suppression before ovarian stimulation.' },
    { key: 'stimulation', label: 'Stimulation Phase', description: 'Stimulation medicines, monitoring scans, trigger and egg collection.' },
    { key: 'procedure', label: 'Procedure Phase', description: 'Procedure-specific instructions and follow-up.' },
    { key: 'other', label: 'Additional Days', description: 'Extra patient-specific treatment days.' },
  ]
  return definitions.map((definition) => ({ ...definition, rows: rows.value.filter((row) => row.phase_key === definition.key) })).filter((group) => group.rows.length)
})
const todayRow = computed(() => rows.value.find((row) => row.date === today))
const resolvedPatientName = computed(() => props.patientName || cycleInfo.value.patient_names?.full_name || profile.value?.full_name || 'Patient')
const resolvedPatientId = computed(() => props.patientId || cycleInfo.value.patient_id || profile.value?.patient_id || 'Not recorded')
const clinicInitial = computed(() => String(clinic.value.clinic_name || clinic.value.company_name || 'F').charAt(0).toUpperCase())
const clinicAddress = computed(() => [clinic.value.company_address, clinic.value.city, clinic.value.state, clinic.value.country].filter(Boolean).join(', '))
const clinicContacts = computed(() => [[clinic.value.company_phone, clinic.value.company_phone_alt].filter(Boolean).join(' / '), clinic.value.company_email].filter(Boolean).join(' | '))
const logoUrl = computed(() => {
  const path = clinic.value.logo_url
  if (!path) return ''
  return /^https?:\/\//i.test(path) ? path : supabase.storage.from('clinic-assets').getPublicUrl(path).data.publicUrl
})

function phaseLabel(key: string) { return key === 'down_regulation' ? 'Down-Regulation' : key === 'stimulation' ? 'Stimulation' : 'Treatment' }
function weekday(value: string) { return new Date(`${value}T00:00:00`).toLocaleDateString('en-GB', { weekday: 'short' }) }
function printDate(value: string) { return new Date(`${value}T00:00:00`).toLocaleDateString('en-GB', { day: '2-digit', month: '2-digit', year: 'numeric' }) }
function formatSignedAt(value: string | null) { return value ? new Date(value).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'Electronic signature' }
function signatureName(row: any) { return row.administered_by_profile?.full_name || row.updated_by_profile?.full_name || profile.value?.full_name || 'Authorized clinical staff' }
function planChanged(row: any) {
  return String(row.medication || '').trim() !== String(row._originalMedication || '').trim()
    || String(row.milestone || '').trim() !== String(row._originalMilestone || '').trim()
    || row.date !== row._originalDate
}

async function initialize() {
  try {
    await queueOrRun('Standard Buserelin cycle chart initialized', { kind: 'rpc', rpcName: 'initialize_standard_buserelin_cycle', payload: { p_cycle_id: props.cycleId } }, () => void load())
  } catch (error: any) {
    if (/initialize_standard_buserelin_cycle|schema cache/i.test(error?.message || '')) migrationError.value = 'Install the Standard Buserelin cycle-chart database update before initializing this chart.'
  }
}

async function addDay() {
  const row = nextPhaseCycleDay(props.cycleId, props.startDate, rows.value)
  await queueOrRun(`Cycle ${phaseLabel(row.phase_key)} Day ${row.phase_day} added`, { table: 'cycle_daily_logs', kind: 'insert', payload: { ...row, updated_by: profile.value?.id || null } }, () => rows.value.push(row))
}

function openTemplateForm() {
  templateName.value = `${cycleInfo.value.protocol || cycleInfo.value.type || 'Fertility Cycle'} Template`
  templateDescription.value = ''
  showTemplateForm.value = true
}

async function saveAsTemplate() {
  const name = templateName.value.trim()
  if (name.length < 3) return
  savingTemplate.value = true
  try {
    await queueOrRun(`Cycle template "${name}" saved`, {
      kind: 'rpc',
      rpcName: 'save_cycle_as_template',
      payload: {
        p_cycle_id: props.cycleId,
        p_name: name,
        p_description: templateDescription.value.trim() || null,
      },
    })
    showTemplateForm.value = false
    toast('Cycle template saved. It is now available when starting another patient’s cycle.', 'success')
  } catch (error: any) {
    const message = String(error?.message || '')
    if (/save_cycle_as_template|cycle_templates|schema cache/i.test(message)) {
      migrationError.value = 'Run the reusable cycle-template SQL update before saving templates.'
    }
    toast(message || 'The cycle template could not be saved.', 'warn')
  } finally {
    savingTemplate.value = false
  }
}

async function markAdministered(row: any) {
  row.medication_administered = true
  row.action_status = 'Administered'
  row.actual_medication = row.actual_medication || row.medication
  row.administered_by = profile.value?.id || null
  row.administered_at = new Date().toISOString()
  await save(row)
}

async function save(row: any) {
  const changedPlan = planChanged(row)
  if (changedPlan && !String(row._pendingReason || '').trim()) return toast('Enter the reason for changing this treatment plan.', 'warn')
  if (changedPlan && !['Administered', 'Completed'].includes(row.action_status)) row.action_status = 'Changed'
  if (['Administered', 'Completed'].includes(row.action_status) && !row.administered_at) {
    row.medication_administered = true
    row.administered_by = profile.value?.id || null
    row.administered_at = new Date().toISOString()
    row.actual_medication = row.actual_medication || row.medication
  }
  const payload = {
    date: row.date, phase: phaseLabel(row.phase_key), phase_key: row.phase_key, phase_day: Number(row.phase_day),
    medication: String(row.medication || '').trim() || null, milestone: String(row.milestone || '').trim() || null,
    action_status: row.action_status, actual_medication: String(row.actual_medication || '').trim() || null,
    medication_administered: Boolean(row.medication_administered), vitals_logged: Boolean(row.vitals_logged),
    administered_by: row.administered_by || null, administered_at: row.administered_at || null,
    note: String(row.note || '').trim() || null, change_reason: changedPlan ? String(row._pendingReason || '').trim() : String(row.change_reason || '').trim() || null,
    updated_by: profile.value?.id || null,
  }
  await queueOrRun(`Cycle ${phaseLabel(row.phase_key)} Day ${row.phase_day} saved`, { table: 'cycle_daily_logs', kind: 'update', payload, match: { id: row.id }, expectedUpdatedAt: row.updated_at }, () => Object.assign(row, payload, { _originalMedication: payload.medication, _originalMilestone: payload.milestone, _originalDate: payload.date, _pendingReason: '', updated_at: new Date().toISOString(), administered_by_profile: row.administered_by_profile || (profile.value ? { full_name: profile.value.full_name } : null), updated_by_profile: profile.value ? { full_name: profile.value.full_name } : null }))
}

async function printChart() {
  if (!rows.value.length || !import.meta.client) return
  await nextTick()
  document.body.classList.add('cycle-chart-printing')
  const originalTitle = document.title
  document.title = `${resolvedPatientId.value} - Cycle Chart`
  try { window.print() } finally { document.title = originalTitle; document.body.classList.remove('cycle-chart-printing') }
}
</script>

<style scoped>
.cycle-chart{margin-top:14px;overflow:hidden}.chart-header{display:flex;justify-content:space-between;gap:18px;padding:16px 18px;border-bottom:1px solid var(--border);background:linear-gradient(135deg,#f7fbff,#fff)}.eyebrow{text-transform:uppercase;letter-spacing:.08em;font-size:9px;font-weight:800;color:var(--blue-600);margin-bottom:4px}.chart-header h3{display:flex;align-items:center;gap:7px;font-size:15px}.chart-header p{margin-top:5px;font-size:11.5px;color:var(--text-500)}.chart-actions{display:flex;align-items:flex-start;gap:7px;flex-wrap:wrap;justify-content:flex-end}.migration-warning{display:flex;align-items:center;gap:7px;padding:10px 16px;background:var(--amber-50);color:var(--amber-700);font-size:11.5px}.today-card{display:flex;align-items:center;gap:12px;margin:14px 16px;padding:12px 14px;border:1px solid var(--blue-200);border-radius:10px;background:var(--blue-50)}.today-icon{width:36px;height:36px;display:grid;place-items:center;border-radius:9px;background:#fff;color:var(--blue-600)}.today-copy{display:flex;flex:1;flex-direction:column;gap:3px}.today-copy span{font-size:10px;text-transform:uppercase;font-weight:800;color:var(--blue-600)}.today-copy b{font-size:13px}.today-copy small{color:var(--text-500)}.chart-legend{display:flex;align-items:center;gap:14px;flex-wrap:wrap;padding:0 16px 12px;font-size:10.5px;color:var(--text-500)}.chart-legend span{display:flex;align-items:center;gap:5px}.legend-dot{width:7px;height:7px;border-radius:50%}.legend-dot.planned{background:var(--blue-400)}.legend-dot.done{background:var(--green-500)}.legend-dot.attention{background:var(--amber-500)}.legend-help{margin-left:auto}.phase-section{border-top:1px solid var(--border)}.phase-heading{display:flex;align-items:center;justify-content:space-between;padding:12px 16px;background:var(--bg)}.phase-heading>div{display:flex;align-items:center;gap:9px}.phase-number{width:25px;height:25px;display:grid;place-items:center;border-radius:8px;background:var(--blue-600);color:#fff;font-size:11px;font-weight:800}.phase-heading b,.phase-heading small{display:block}.phase-heading b{font-size:12.5px}.phase-heading small{margin-top:2px;color:var(--text-500);font-size:10.5px}.chart-scroll{overflow-x:auto}.cycle-table{width:100%;min-width:1120px;border-collapse:collapse;font-size:11px}.cycle-table th{padding:8px 10px;background:#f8fafc;border-bottom:1px solid var(--border);text-align:left;text-transform:uppercase;letter-spacing:.04em;font-size:8.5px;color:var(--text-500)}.cycle-table td{padding:8px 10px;border-bottom:1px solid var(--border);vertical-align:top}.cycle-table tr.today-row{background:#f4faff}.day-cell{min-width:115px}.day-cell b,.day-cell span,.day-cell small{display:block}.day-cell span{margin-top:3px}.day-cell small{color:var(--text-500);margin-top:2px}.date-input{margin-top:5px;min-width:112px;padding:6px;font-size:10px}.compact-area{min-width:190px;resize:vertical;font-size:11px}.status-select{min-width:118px;font-size:10.5px}.administration-cell{min-width:180px}.give-button{margin-top:5px}.signed-chip{display:flex;align-items:center;gap:4px;color:var(--green-700);font-size:10.5px;font-weight:700}.signed-chip small{display:block;margin-left:3px;color:var(--text-500);font-weight:400}.actual-text{margin-bottom:5px;font-weight:600}.reason-input{margin-top:6px;min-width:190px;font-size:10.5px;border-color:var(--amber-400)}.change-note{display:flex;gap:4px;margin-top:5px;color:var(--amber-700);font-size:9.5px}.instruction-text,.note-text{white-space:pre-wrap;line-height:1.45}.save-cell{width:74px}.empty-chart{padding:20px}.cycle-print-target{display:none}.template-safety{display:flex;align-items:flex-start;gap:9px;margin-bottom:16px;padding:11px 12px;border:1px solid var(--green-200);border-radius:9px;background:var(--green-50);color:var(--green-800);font-size:11.5px;line-height:1.45}.label-optional{color:var(--text-400);font-weight:400}
@media(max-width:700px){.chart-header{flex-direction:column;padding:14px}.chart-actions{justify-content:flex-start}.chart-actions .btn{flex:1 1 calc(50% - 5px);justify-content:center}.today-card{align-items:flex-start;margin:10px}.legend-help{width:100%;margin-left:0}.phase-heading{align-items:flex-start;gap:8px;padding:11px 12px}.phase-heading small{max-width:220px}.chart-scroll{overflow:visible;padding:10px;background:#f5f8fb}.cycle-table{display:block;min-width:0}.cycle-table thead{display:none}.cycle-table tbody{display:grid;gap:10px}.cycle-table tr{display:block;border:1px solid var(--border);border-radius:10px;background:#fff;overflow:hidden;box-shadow:0 1px 2px rgba(16,24,40,.04)}.cycle-table tr.today-row{border-color:var(--blue-300);background:#fff}.cycle-table td{display:block;padding:10px 12px;border-bottom:1px solid var(--border)}.cycle-table td:last-child{border-bottom:0}.cycle-table td::before{content:attr(data-label);display:block;margin-bottom:6px;color:var(--text-500);font-size:8.5px;font-weight:800;letter-spacing:.06em;text-transform:uppercase}.day-cell,.administration-cell,.save-cell{width:auto;min-width:0}.cycle-table .input,.compact-area,.status-select,.reason-input,.date-input{width:100%;min-width:0}.save-cell .btn{width:100%;justify-content:center}}
</style>

<style>
@media print {
  @page{size:A4 landscape;margin:8mm}
  body.cycle-chart-printing *{visibility:hidden!important}
  body.cycle-chart-printing .cycle-print-target,body.cycle-chart-printing .cycle-print-target *{visibility:visible!important}
  body.cycle-chart-printing .cycle-print-target{display:block!important;position:absolute!important;left:0!important;top:0!important;width:100%!important;color:#152637!important;background:#fff!important;font-family:Arial,sans-serif!important}
  body.cycle-chart-printing .modal-overlay{position:static!important;display:block!important;padding:0!important;background:none!important;backdrop-filter:none!important}
  body.cycle-chart-printing .modal{max-width:none!important;max-height:none!important;overflow:visible!important;box-shadow:none!important}
  body.cycle-chart-printing .modal-head,body.cycle-chart-printing .modal-foot{display:none!important}
  body.cycle-chart-printing .modal-body{padding:0!important;overflow:visible!important}
  .print-header{display:flex;justify-content:space-between;gap:18px;padding:0 0 10px;border-bottom:3px solid #176c9d}.print-brand{display:flex;gap:10px;align-items:flex-start}.print-brand img,.print-logo-fallback{width:48px;height:48px;object-fit:contain;border:1px solid #dbe3ec;border-radius:7px}.print-logo-fallback{display:grid;place-items:center;background:#eaf5fb;color:#176c9d;font-size:22px;font-weight:800}.print-brand h1{font-size:16px;color:#124667;margin:1px 0 4px}.print-brand p{font-size:8px;color:#5f7080;margin:1px 0}.print-title{text-align:right}.print-title span{font-size:7.5px;text-transform:uppercase;letter-spacing:.1em;color:#607585}.print-title h2{font-size:17px;margin:4px 0}.print-title b{font-size:8px;color:#176c9d;background:#eaf5fb;padding:4px 6px;border-radius:4px}.print-patient-grid{display:grid;grid-template-columns:1.5fr 1fr 1.2fr 1fr;border:1px solid #d8e1e8;margin:9px 0}.print-patient-grid div{padding:6px 8px;border-right:1px solid #d8e1e8}.print-patient-grid div:last-child{border:0}.print-patient-grid span{display:block;text-transform:uppercase;font-size:6.5px;letter-spacing:.07em;color:#718190;margin-bottom:2px}.print-patient-grid b{font-size:8.5px}.print-phase{break-before:page}.print-phase.first{break-before:auto}.print-phase-title{display:flex;align-items:end;justify-content:space-between;padding:5px 7px;background:#153f59;color:#fff}.print-phase-title h3{font-size:10px;margin:0}.print-phase-title span{font-size:7px;color:#d6e7f1}.print-table{width:100%;border-collapse:collapse;table-layout:fixed;font-size:7.3px}.print-table th{padding:4px 5px;background:#eaf2f7;color:#24495e;text-align:left;text-transform:uppercase;font-size:6.3px;border:1px solid #bfcdd7}.print-table td{padding:3.5px 5px;border:1px solid #cbd6de;vertical-align:top;line-height:1.25}.print-table th:nth-child(1){width:11%}.print-table th:nth-child(2){width:7%}.print-table th:nth-child(3){width:42%}.print-table th:nth-child(4){width:18%}.print-table th:nth-child(5){width:22%}.print-table td small{display:block;margin-top:2px;color:#536b7b;font-size:6.3px}.print-footer{display:flex;justify-content:space-between;gap:20px;margin-top:7px;padding-top:5px;border-top:1px solid #ccd7df;color:#657987;font-size:6.5px}
}
</style>
