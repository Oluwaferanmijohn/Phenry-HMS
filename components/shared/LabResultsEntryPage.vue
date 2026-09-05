<template>
  <div v-if="!patients.length">
    <div class="page-header"><div><h1>Enter Lab Results</h1><div class="desc">Record assay values for patient monitoring.</div></div></div>
    <EmptyState icon="user" title="No patients registered yet" description="Results can't be entered until at least one patient exists in the system. Ask Reception to register a patient first." />
  </div>
  <div v-else-if="!templates.length">
    <div class="page-header"><div><h1>Enter Lab Results</h1><div class="desc">Record assay values for patient monitoring.</div></div></div>
    <EmptyState icon="flask" title="No lab test templates yet" description="Create at least one test template before results can be recorded." />
    <div style="text-align:center; margin-top:-8px;">
      <NuxtLink :to="`/${role}/templates`" class="btn btn-primary"><Icon name="plus" :size="13" /> Create a Template</NuxtLink>
    </div>
  </div>
  <div v-else-if="patient && template">
    <div class="page-header">
      <div><h1>Enter Lab Results</h1><div class="desc">Record assay values for patient monitoring.</div></div>
      <div class="page-actions"><button class="btn btn-secondary" @click="showExternal = true"><Icon name="upload" :size="14" /> Upload External Result for {{ patient.first_name }}</button></div>
    </div>
    <div v-if="activeOrder" class="card card-pad" style="margin-bottom:16px; border-color:var(--blue-500); background:var(--blue-50);">
      <div class="flex-between" style="align-items:flex-start; gap:16px;">
        <div>
          <div class="flex gap-8" style="flex-wrap:wrap; margin-bottom:6px;">
            <Badge tone="blue">Consultation Order</Badge>
            <StatusBadge :status="activeOrder.status" />
          </div>
          <b style="font-size:13px;">Requested tests: {{ activeOrder.tests.join(', ') }}</b>
          <div class="cell-muted" style="margin-top:4px;">Ordered {{ fmtDate(activeOrder.created_at) }} by {{ roleLabel(activeOrder.ordered_by_role) }}. Enter and save a result for each requested test, then complete the order.</div>
        </div>
        <div class="flex gap-8" style="flex-shrink:0; flex-wrap:wrap; justify-content:flex-end;">
          <button class="btn btn-secondary btn-sm" @click="returnToWorklist"><Icon name="chevron-left" :size="12" /> Back to Worklist</button>
          <button
            v-if="activeOrder.status !== 'Completed' && activeOrder.status !== 'Cancelled'"
            class="btn btn-success btn-sm"
            :disabled="completingOrder"
            @click="completeOrder"
          ><Icon name="check-circle" :size="12" /> Complete Order</button>
        </div>
      </div>
    </div>
    <div v-else-if="orderContextError" class="card card-pad" style="margin-bottom:16px; border-color:var(--amber-500);">
      <div style="font-size:12.5px;"><b>Order unavailable.</b> {{ orderContextError }} You can still enter a result by selecting the patient and template below.</div>
    </div>
    <div class="grid grid-main-side">
      <div class="card card-pad">
        <div v-if="editingResultId" class="edit-result-banner">
          <div><Badge tone="amber">Amending Result</Badge><b>{{ template?.name }}</b><span>The original author and amendment history remain on the report.</span></div>
          <button class="btn btn-secondary btn-sm" @click="resetForm"><Icon name="x-circle" :size="12" /> Stop Editing</button>
        </div>
        <div class="form-row">
          <div class="field"><label>Target Patient ID</label><select v-model="patientId" class="input" :disabled="Boolean(activeOrder)" @change="loadPatient(patientId)"><option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option></select></div>
          <div class="field"><label>Select Test Template</label><select v-model="templateId" class="input"><option v-for="t in templates" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
        </div>
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="flask" :size="12" /> {{ template.name }} Results</b>
        <div class="field" style="margin:8px 0 10px; max-width:200px;"><label>Collection Date</label><input v-model="collectedOn" class="input" type="date" /></div>
        <div class="scroll-x">
          <table class="data-table">
            <thead><tr><th>Test Parameter</th><th>Reference Range</th><th>Patient Result</th></tr></thead>
            <tbody>
              <tr v-for="(v, i) in template.variables" :key="i">
                <td class="cell-strong">{{ v.name }}</td>
                <td class="cell-muted">{{ v.ref }} {{ v.unit }}</td>
                <td><input v-model="values[i]" class="input" placeholder="Enter value" style="max-width:160px;" /></td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="field" style="margin-top:14px;"><label>Add Lab Remarks</label><textarea v-model="remarks" class="input" rows="3" placeholder="Enter any technical observations, sample quality notes, or context for flagged results…" /></div>
        <div v-if="editingResultId" class="field amendment-field"><label>Reason for Amendment <span style="color:var(--red-600);">*</span></label><textarea v-model="amendmentReason" class="input" rows="2" placeholder="State exactly why this finalized result is being changed." /><div class="hint">This reason, your name, and the amendment time will appear on the report.</div></div>
        <div class="flex-between" style="margin-top:14px;">
          <button class="btn btn-secondary" @click="resetForm">Cancel</button>
          <button class="btn btn-primary" :disabled="submitting" @click="save"><Icon :name="editingResultId ? 'edit' : 'file'" :size="13" /> {{ editingResultId ? 'Save Audited Amendment' : 'Save Results & Attach to Patient File' }}</button>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="file" :size="15" /> On File for {{ patient.first_name }}</h3></div>
        <div class="card-body tight">
          <p v-if="!onFile.length" class="muted" style="font-size:12px; padding:16px 20px;">No results on file yet.</p>
          <button v-for="r in onFile" :key="r.id" type="button" class="list-row history-result-row" @click="openHistoryResult(r)">
            <div><div class="main-txt">{{ r.title || r.lab_templates?.name || 'Lab Result' }}</div><div class="sub-txt">{{ fmtDate(r.collected_on) }} · {{ r.entered_by_name }}<span v-if="r.amended_at"> · Amended</span></div></div>
            <div class="history-result-actions">
              <Badge v-if="r.external" tone="purple">External</Badge>
              <Badge v-else-if="flaggedCount(r) > 0" tone="red">⚠ {{ flaggedCount(r) }} abnormal</Badge>
              <Icon :name="r.external ? 'download' : 'eye'" :size="14" />
            </div>
          </button>
        </div>
      </div>
    </div>
    <ExternalUploadModal v-model="showExternal" :preselected-patient-id="patientId" @uploaded="loadOnFile" />
    <LabResultReportModal v-model="showReport" :result-id="selectedResultId" editable @edit="startEdit" />
  </div>
  <div v-else class="card card-pad" style="text-align:center; color:var(--text-500); font-size:13px;">
    Loading…
  </div>
</template>

<script setup lang="ts">
import { nextTick, ref, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'
import { computeFlag } from '~/composables/useLabFlag'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const route = useRoute()
const router = useRouter()

const patients = ref<any[]>([])
const templates = ref<any[]>([])
const patient = ref<any>(null)
const template = ref<any>(null)
const activeOrder = ref<any>(null)
const orderContextError = ref('')
const patientId = ref('')
const templateId = ref('')
const collectedOn = ref(new Date().toISOString().slice(0, 10))
const values = ref<string[]>([])
const remarks = ref('')
const onFile = ref<any[]>([])
const showExternal = ref(route.query.external === '1')
const submitting = ref(false)
const completingOrder = ref(false)
const showReport = ref(false)
const selectedResultId = ref('')
const editingResultId = ref('')
const editingUpdatedAt = ref('')
const amendmentReason = ref('')

async function loadPatient(id: string) {
  const { data } = await supabase.from('patient_names').select('*').eq('patient_id', id).single()
  patient.value = data
  // Whatever was typed in for the previous patient must not survive the
  // switch — otherwise it sits in the form and gets saved under the new
  // patient's record if Save is clicked without noticing.
  resetForm()
  await loadOnFile()
}
async function loadOnFile() {
  const { data } = await supabase.from('lab_results').select('*, lab_templates(name), profiles:entered_by_profile_id(full_name)').eq('patient_id', patientId.value).order('collected_on', { ascending: false })
  onFile.value = (data || []).map((r: any) => ({ ...r, entered_by_name: r.profiles?.full_name || (r.external ? 'External Upload' : 'Staff') }))
}

watch(templateId, (id) => {
  template.value = templates.value.find((t) => t.id === id)
  values.value = template.value ? new Array(template.value.variables.length).fill('') : []
  remarks.value = ''
})

const requestedOrderId = typeof route.query.order === 'string' ? route.query.order : ''
const requestedPatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
const labResultsInitKey = `lab-results-init-${profile.value?.id || 'anonymous'}-${props.role}-${requestedOrderId || requestedPatientId || 'manual'}`

await useAsyncData(labResultsInitKey, async () => {
  const [patientsRes, templatesRes, orderRes] = await Promise.all([
    supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
    supabase.from('lab_templates').select('*').order('name', { ascending: true }),
    requestedOrderId
      ? supabase.from('lab_test_orders').select('id, patient_id, tests, status, created_at, ordered_by_role').eq('id', requestedOrderId).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
  ])
  patients.value = patientsRes.data || []
  templates.value = templatesRes.data || []

  if (requestedOrderId) {
    const order = orderRes.data
    if (orderRes.error || !order) {
      orderContextError.value = 'The selected order may have been removed or is no longer accessible.'
    } else if (!patients.value.some((entry) => entry.patient_id === order.patient_id)) {
      orderContextError.value = 'Its patient is not available to this account.'
    } else {
      activeOrder.value = order
    }
  }

  const initialPatientId = activeOrder.value?.patient_id || requestedPatientId
  patientId.value = patients.value.some((entry) => entry.patient_id === initialPatientId)
    ? initialPatientId
    : patients.value[0]?.patient_id || ''
  templateId.value = findMatchingTemplate(activeOrder.value?.tests || [])?.id || templates.value[0]?.id || ''
  if (patientId.value) await loadPatient(patientId.value)
  return true
}, {
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

function normalizedName(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()
}

function findMatchingTemplate(orderedTests: string[]) {
  return templates.value.find((candidate) => orderedTests.some((orderedTest) => {
    const templateName = normalizedName(candidate.name)
    const orderName = normalizedName(orderedTest)
    if (templateName.includes(orderName) || orderName.includes(templateName)) return true

    const templateTokens = new Set(templateName.split(' ').filter((token) => token.length > 1 && token !== 'test'))
    const orderTokens = new Set(orderName.split(' ').filter((token) => token.length > 1 && token !== 'test'))
    const sharedTokens = [...templateTokens].filter((token) => orderTokens.has(token)).length
    return sharedTokens >= Math.min(2, templateTokens.size, orderTokens.size)
  }))
}

function roleLabel(role: string) {
  return role.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function returnToWorklist() {
  router.push(`/${props.role}/worklist`)
}

async function completeOrder() {
  if (!activeOrder.value || activeOrder.value.status === 'Completed' || activeOrder.value.status === 'Cancelled') return
  completingOrder.value = true
  const targetOrderId = activeOrder.value.id
  try {
    await queueOrRun(
      `Lab order completed for ${patient.value.full_name}`,
      { table: 'lab_test_orders', kind: 'update', payload: { status: 'Completed' }, match: { id: targetOrderId } },
      () => { if (activeOrder.value?.id === targetOrderId) activeOrder.value.status = 'Completed' },
    )
    await router.push(`/${props.role}/worklist`)
  } finally {
    completingOrder.value = false
  }
}

function flaggedCount(result: any) {
  return Array.isArray(result.values) ? result.values.filter((v: any) => v.flag).length : 0
}

function resetForm() {
  remarks.value = ''
  values.value = template.value ? new Array(template.value.variables.length).fill('') : []
  editingResultId.value = ''
  editingUpdatedAt.value = ''
  amendmentReason.value = ''
}

async function openHistoryResult(result: any) {
  if (result.external && result.external_file_url) {
    const { data, error } = await supabase.storage.from('lab-external-results').createSignedUrl(result.external_file_url, 60)
    if (error || !data?.signedUrl) return toast("Couldn't open this external result. Please try again.", 'warn')
    window.open(data.signedUrl, '_blank')
    return
  }
  selectedResultId.value = result.id
  showReport.value = true
}

async function startEdit(reportContext: any) {
  const result = reportContext?.result
  const targetTemplate = templates.value.find((entry) => entry.id === result?.template_id)
  if (!result || !targetTemplate) {
    toast('This result cannot be edited because its template is no longer available.', 'warn')
    return
  }
  showReport.value = false
  templateId.value = targetTemplate.id
  await nextTick()
  template.value = targetTemplate
  values.value = targetTemplate.variables.map((variable: any) => {
    const saved = Array.isArray(result.values)
      ? result.values.find((entry: any) => String(entry.param || '').trim().toLowerCase() === String(variable.name || '').trim().toLowerCase())
      : null
    return saved?.value == null ? '' : String(saved.value)
  })
  collectedOn.value = String(result.collected_on || '').slice(0, 10) || new Date().toISOString().slice(0, 10)
  remarks.value = result.remarks || ''
  editingResultId.value = result.id
  editingUpdatedAt.value = result.updated_at || ''
  amendmentReason.value = ''
  if (import.meta.client) window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function save() {
  if (!template.value || !patient.value) return
  const valuesPayload = template.value.variables.flatMap((v: any, i: number) => {
    const enteredValue = String(values.value[i] ?? '').trim()
    if (!enteredValue) return []
    return [{ param: v.name, value: enteredValue, unit: v.unit, ref: v.ref, flag: computeFlag(enteredValue, v.ref) }]
  })
  if (!valuesPayload.length) return toast('Enter at least one result value before saving.', 'warn')
  if (editingResultId.value && !amendmentReason.value.trim()) return toast('Enter a reason for this amendment before saving.', 'warn')
  const targetPatientId = patientId.value
  const targetPatientName = patient.value.full_name
  const targetTemplateId = templateId.value
  const targetTemplateName = template.value.name
  const targetCollectedOn = collectedOn.value
  const targetRemarks = remarks.value
  const enteredByProfileId = profile.value!.id
  const targetResultId = editingResultId.value
  const targetUpdatedAt = editingUpdatedAt.value
  const targetAmendmentReason = amendmentReason.value.trim()

  submitting.value = true
  try {
    if (targetResultId) {
      await queueOrRun(
        `${targetTemplateName} amendment saved for ${targetPatientName}`,
        {
          table: 'lab_results',
          kind: 'update',
          match: { id: targetResultId },
          expectedUpdatedAt: targetUpdatedAt || undefined,
          payload: {
            collected_on: targetCollectedOn,
            values: valuesPayload,
            remarks: targetRemarks,
            amended_at: new Date().toISOString(),
            amended_by_profile_id: enteredByProfileId,
            amendment_reason: targetAmendmentReason,
          },
        },
        () => { if (patientId.value === targetPatientId) loadOnFile() },
      )
    } else {
      await queueOrRun(
        `${targetTemplateName} results saved for ${targetPatientName}`,
        {
          table: 'lab_results',
          kind: 'insert',
          payload: {
            patient_id: targetPatientId,
            template_id: targetTemplateId,
            entered_by_profile_id: enteredByProfileId,
            collected_on: targetCollectedOn,
            values: valuesPayload,
            remarks: targetRemarks,
          },
        },
        () => { if (patientId.value === targetPatientId) loadOnFile() },
      )
    }
    resetForm()
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.edit-result-banner { display:flex; justify-content:space-between; align-items:flex-start; gap:14px; margin-bottom:16px; padding:12px 14px; border:1px solid var(--amber-500); border-radius:var(--radius-sm); background:var(--amber-50); }
.edit-result-banner > div { display:flex; flex-wrap:wrap; align-items:center; gap:8px; }
.edit-result-banner b { font-size:12.5px; }
.edit-result-banner span { width:100%; color:var(--text-700); font-size:11.5px; }
.amendment-field { padding:12px; border:1px solid var(--amber-500); border-radius:var(--radius-sm); background:var(--amber-50); }
.history-result-row { width:100%; border:0; background:transparent; text-align:left; font-family:inherit; cursor:pointer; }
.history-result-row:hover { background:var(--bg); }
.history-result-actions { margin-left:auto; display:flex; align-items:center; gap:8px; color:var(--text-400); }
</style>
