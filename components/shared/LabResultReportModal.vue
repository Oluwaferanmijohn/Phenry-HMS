<template>
  <Modal :model-value="modelValue" title="Laboratory Result" wide @update:model-value="$emit('update:modelValue', $event)">
    <div v-if="loading" class="report-state">Loading report...</div>
    <div v-else-if="error" class="report-state report-error">
      <Icon name="alert" :size="20" />
      <b>Report could not be loaded</b>
      <span>{{ error }}</span>
    </div>
    <article v-else-if="context" class="lab-result-print-target">
      <header class="report-header">
        <div class="report-brand">
          <img v-if="logoUrl" :src="logoUrl" alt="Hospital logo" class="report-logo" />
          <div v-else class="report-logo-fallback">{{ clinicInitial }}</div>
          <div>
            <h2>{{ clinic.clinic_name || clinic.company_name || 'Medical Laboratory' }}</h2>
            <p v-if="clinic.clinic_tagline" class="report-tagline">{{ clinic.clinic_tagline }}</p>
            <p v-if="clinic.company_name && clinic.company_name !== clinic.clinic_name">{{ clinic.company_name }}</p>
            <p v-if="clinicAddress">{{ clinicAddress }}</p>
            <p v-if="clinicContacts">{{ clinicContacts }}</p>
            <p v-if="clinic.company_website">{{ clinic.company_website }}</p>
          </div>
        </div>
        <div class="report-title">
          <span>Laboratory Medicine</span>
          <h1>Laboratory Result</h1>
          <b>REPORT #{{ reportNumber }}</b>
        </div>
      </header>

      <section class="report-patient-grid">
        <div><span>Patient</span><b>{{ patient.full_name }}</b></div>
        <div><span>Patient ID</span><b>{{ patient.patient_id }}</b></div>
        <div><span>Date of birth / Age</span><b>{{ birthAndAge }}</b></div>
        <div><span>Sex</span><b>{{ patient.sex || 'Not recorded' }}</b></div>
        <div><span>Collected</span><b>{{ fmtDateTime(result.collected_on) }}</b></div>
        <div><span>Reported</span><b>{{ fmtDateTime(result.created_at) }}</b></div>
      </section>

      <section class="report-test-heading">
        <div>
          <span>Investigation</span>
          <h3>{{ result.template_name || result.title || 'Laboratory Result' }}</h3>
        </div>
        <div class="report-status" :class="{ amended: result.amended_at }">{{ result.amended_at ? 'AMENDED' : 'FINAL' }}</div>
      </section>

      <table v-if="resultRows.length" class="report-table">
        <thead><tr><th>Test parameter</th><th>Result</th><th>Unit</th><th>Reference range</th><th>Flag</th></tr></thead>
        <tbody>
          <tr v-for="(row, index) in resultRows" :key="`${row.param}-${index}`" :class="{ abnormal: row.flag }">
            <td>{{ row.param }}</td>
            <td class="report-value">{{ row.value }}</td>
            <td>{{ row.unit || '-' }}</td>
            <td>{{ row.ref || '-' }}</td>
            <td><b v-if="row.flag">Abnormal</b><span v-else>-</span></td>
          </tr>
        </tbody>
      </table>
      <div v-else class="report-empty-values">No structured result values were recorded for this attachment.</div>

      <section v-if="result.remarks" class="report-note">
        <span>Laboratory remarks</span>
        <p>{{ result.remarks }}</p>
      </section>
      <section v-if="result.amendment_reason" class="report-amendment">
        <span>Amendment record</span>
        <p>{{ result.amendment_reason }}</p>
        <small>Amended {{ fmtDateTime(result.amended_at) }} by {{ result.amended_by_name || 'Authorized laboratory staff' }}</small>
      </section>

      <footer class="report-footer">
        <div>
          <span>Entered by</span>
          <b>{{ result.entered_by_name || (result.external ? 'External laboratory' : 'Authorized laboratory staff') }}</b>
          <small>{{ fmtDateTime(result.created_at) }}</small>
        </div>
        <div class="report-validation">
          <span>{{ clinic.laboratory_director_name ? 'Laboratory Director' : 'Result status' }}</span>
          <b>{{ clinic.laboratory_director_name || (result.amended_at ? 'Final - Amended' : 'Final') }}</b>
          <small>{{ clinic.laboratory_director_title || 'Electronically generated laboratory report' }}</small>
        </div>
      </footer>
      <div v-if="officialIdentifiers" class="report-identifiers">{{ officialIdentifiers }}</div>
      <p class="report-disclaimer">{{ clinic.report_footer || "Results must be interpreted by a qualified healthcare professional together with the patient's clinical findings. This report contains confidential medical information." }}</p>
    </article>

    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button>
      <button v-if="editable && context && !result.external" class="btn btn-secondary" @click="$emit('edit', context)"><Icon name="edit" :size="13" /> Edit Result</button>
      <button v-if="context" class="btn btn-primary" @click="printReport"><Icon name="printer" :size="13" /> Print / Save PDF</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { computeAge } from '~/composables/useFormat'

const props = withDefaults(defineProps<{ modelValue: boolean; resultId: string; editable?: boolean }>(), { editable: false })
defineEmits<{ 'update:modelValue': [boolean]; edit: [any] }>()

const supabase = useSupabaseClient()
const context = ref<any>(null)
const loading = ref(false)
const error = ref('')

const clinic = computed(() => context.value?.clinic || {})
const patient = computed(() => context.value?.patient || {})
const result = computed(() => context.value?.result || {})
const clinicInitial = computed(() => String(clinic.value.clinic_name || clinic.value.company_name || 'M').charAt(0).toUpperCase())
const reportNumber = computed(() => String(result.value.id || '').replaceAll('-', '').slice(0, 12).toUpperCase() || 'PENDING')
const logoUrl = computed(() => {
  const path = clinic.value.logo_url
  if (!path) return ''
  if (/^https?:\/\//i.test(path)) return path
  return supabase.storage.from('clinic-assets').getPublicUrl(path).data.publicUrl
})
const clinicAddress = computed(() => [clinic.value.company_address, clinic.value.city, clinic.value.state, clinic.value.postal_code, clinic.value.country].filter(Boolean).join(', '))
const clinicContacts = computed(() => {
  const phones = [clinic.value.company_phone, clinic.value.company_phone_alt].filter(Boolean).join(' / ')
  return [phones ? `Tel: ${phones}` : '', clinic.value.company_email].filter(Boolean).join(' | ')
})
const officialIdentifiers = computed(() => [
  clinic.value.registration_number ? `Facility Reg: ${clinic.value.registration_number}` : '',
  clinic.value.laboratory_license_number ? `Laboratory Licence: ${clinic.value.laboratory_license_number}` : '',
  clinic.value.tax_identification_number ? `TIN: ${clinic.value.tax_identification_number}` : '',
].filter(Boolean).join(' | '))
const birthAndAge = computed(() => patient.value.dob ? `${fmtDateOnly(patient.value.dob)} / ${computeAge(patient.value.dob)}` : 'Not recorded')
const resultRows = computed(() => Array.isArray(result.value.values)
  ? result.value.values.filter((row: any) => row?.value !== null && row?.value !== undefined && !['', '—'].includes(String(row.value).trim()))
  : [])

watch(
  () => [props.modelValue, props.resultId] as const,
  ([open, id]) => { if (open && id) void loadReport() },
  { immediate: true },
)

async function loadReport() {
  loading.value = true
  error.value = ''
  context.value = null
  const { data, error: rpcError } = await supabase.rpc('lab_result_report_context', { p_result_id: props.resultId })
  loading.value = false
  if (rpcError || !data) {
    error.value = rpcError?.message?.includes('lab_result_report_context')
      ? 'The laboratory report database update has not been installed yet.'
      : rpcError?.message || 'Please try again.'
    return
  }
  context.value = data
}

function fmtDateOnly(value: string) {
  if (!value) return 'Not recorded'
  return new Date(`${value}T00:00:00`).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

function fmtDateTime(value: string) {
  if (!value) return 'Not recorded'
  return new Date(value).toLocaleString('en-GB', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

async function printReport() {
  if (!context.value || !import.meta.client) return
  await nextTick()
  document.body.classList.add('lab-result-printing')
  const originalTitle = document.title
  document.title = `${patient.value.patient_id || 'Patient'} - ${result.value.template_name || 'Lab Result'}`
  try {
    window.print()
  } finally {
    document.title = originalTitle
    document.body.classList.remove('lab-result-printing')
  }
}
</script>

<style scoped>
.report-state { min-height:260px; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:8px; color:var(--text-500); text-align:center; }
.report-error { color:var(--red-600); }
.lab-result-print-target { color:#172033; background:#fff; border:1px solid #dbe3ec; border-radius:14px; overflow:hidden; font-family:Inter, Arial, sans-serif; }
.report-header { display:flex; justify-content:space-between; gap:24px; padding:28px 30px 24px; border-top:7px solid #116da4; border-bottom:1px solid #dbe3ec; }
.report-brand { display:flex; align-items:flex-start; gap:14px; min-width:0; }
.report-logo, .report-logo-fallback { width:64px; height:64px; flex:0 0 64px; border-radius:12px; object-fit:contain; border:1px solid #dbe3ec; background:#fff; }
.report-logo-fallback { display:flex; align-items:center; justify-content:center; background:#eaf5fb; color:#116da4; font-size:28px; font-weight:800; }
.report-brand h2 { font-size:18px; line-height:1.2; margin:2px 0 5px; color:#0d4164; }
.report-brand p { font-size:10.5px; line-height:1.45; color:#526273; margin:1px 0; white-space:pre-line; }
.report-brand .report-tagline { color:#116da4; font-style:italic; margin-bottom:3px; }
.report-title { text-align:right; flex-shrink:0; }
.report-title span, .report-test-heading span, .report-note span, .report-amendment span, .report-footer span { display:block; text-transform:uppercase; letter-spacing:.1em; font-size:9px; font-weight:800; color:#647789; }
.report-title h1 { font-size:21px; margin:5px 0 8px; color:#152b3a; }
.report-title b { font-size:9.5px; padding:5px 8px; border-radius:5px; color:#116da4; background:#eaf5fb; letter-spacing:.06em; }
.report-patient-grid { display:grid; grid-template-columns:2fr 1.2fr 1.4fr; gap:0; margin:22px 30px; border:1px solid #dbe3ec; border-radius:9px; overflow:hidden; }
.report-patient-grid div { padding:10px 12px; border-right:1px solid #e7edf3; border-bottom:1px solid #e7edf3; }
.report-patient-grid div:nth-child(3n) { border-right:0; }
.report-patient-grid div:nth-last-child(-n+3) { border-bottom:0; }
.report-patient-grid span { display:block; text-transform:uppercase; font-size:8.5px; font-weight:700; letter-spacing:.07em; color:#728292; margin-bottom:4px; }
.report-patient-grid b { font-size:11px; color:#1c2d3b; }
.report-test-heading { display:flex; justify-content:space-between; align-items:end; gap:16px; margin:0 30px 10px; }
.report-test-heading h3 { font-size:15px; margin:4px 0 0; color:#123d58; }
.report-status { color:#08795a; background:#e8f7f1; padding:6px 10px; border-radius:999px; font-size:9px; font-weight:800; letter-spacing:.08em; }
.report-status.amended { color:#9a5b09; background:#fff4dd; }
.report-table { width:calc(100% - 60px); margin:0 30px 18px; border-collapse:collapse; font-size:10.5px; }
.report-table th { background:#103f5d; color:#fff; padding:9px 10px; text-align:left; text-transform:uppercase; letter-spacing:.06em; font-size:8.5px; }
.report-table td { padding:9px 10px; border-bottom:1px solid #e3e9ef; }
.report-table tbody tr:nth-child(even) { background:#f7fafc; }
.report-table tr.abnormal { background:#fff2f1 !important; color:#a42d2d; }
.report-value { font-weight:800; color:#153e58; }
.report-empty-values { margin:0 30px 18px; padding:14px; border-radius:8px; background:#f7fafc; color:#647789; font-size:11px; }
.report-note, .report-amendment { margin:0 30px 14px; padding:12px 14px; border-left:3px solid #4aa2cf; background:#f2f8fb; }
.report-amendment { border-left-color:#d9922e; background:#fff8ec; }
.report-note p, .report-amendment p { margin:5px 0 0; font-size:10.5px; line-height:1.5; white-space:pre-line; }
.report-amendment small { display:block; margin-top:6px; color:#6f5b3e; font-size:9px; }
.report-footer { display:grid; grid-template-columns:1fr 1fr; gap:20px; margin:25px 30px 0; padding:18px 0 22px; border-top:1px solid #dbe3ec; }
.report-footer b { display:block; margin-top:5px; font-size:11px; color:#163d55; }
.report-footer small { display:block; margin-top:3px; font-size:9px; color:#728292; }
.report-validation { text-align:right; }
.report-identifiers { padding:7px 30px; border-top:1px solid #dbe3ec; text-align:center; color:#647789; font-size:8px; }
.report-disclaimer { background:#103f5d; color:#dceaf2; padding:12px 30px; font-size:8.5px; line-height:1.45; margin:0; }
@media (max-width:700px) {
  .report-header { flex-direction:column; }
  .report-title { text-align:left; }
  .report-patient-grid { grid-template-columns:1fr 1fr; }
  .report-patient-grid div { border:0; border-bottom:1px solid #e7edf3; }
}
</style>

<style>
@media print {
  @page { size:A4; margin:10mm; }
  body.lab-result-printing * { visibility:hidden !important; }
  body.lab-result-printing .lab-result-print-target,
  body.lab-result-printing .lab-result-print-target * { visibility:visible !important; }
  body.lab-result-printing .lab-result-print-target {
    position:absolute !important; left:0 !important; top:0 !important; width:100% !important;
    border:0 !important; border-radius:0 !important; box-shadow:none !important;
  }
  body.lab-result-printing .modal-overlay { position:static !important; display:block !important; padding:0 !important; background:none !important; backdrop-filter:none !important; }
  body.lab-result-printing .modal { max-width:none !important; max-height:none !important; overflow:visible !important; box-shadow:none !important; }
  body.lab-result-printing .modal-head, body.lab-result-printing .modal-foot { display:none !important; }
  body.lab-result-printing .modal-body { padding:0 !important; }
  body.lab-result-printing { background:#fff !important; }
}
</style>
