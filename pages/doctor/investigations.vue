<template>
  <div v-if="directoryStatus === 'pending' || loadingPatient">
    <div class="page-header"><div><h1>Women’s Imaging &amp; Ultrasound</h1><div class="desc">Loading accessible patient information…</div></div></div>
    <div class="card card-pad"><div class="cell-muted">Loading imaging workspace…</div></div>
  </div>

  <div v-else-if="directoryError || loadError">
    <div class="page-header"><div><h1>Women’s Imaging &amp; Ultrasound</h1><div class="desc">The workspace could not be opened.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="alert" title="Investigation data could not be loaded" description="A temporary connection or permission error prevented the imaging workspace from loading." />
      <div style="margin-top:12px; text-align:center;"><button class="btn btn-secondary btn-sm" @click="retryInvestigations">Try Again</button></div>
    </div>
  </div>

  <div v-else-if="!patient">
    <div class="page-header"><div><h1>Women’s Imaging &amp; Ultrasound</h1><div class="desc">Select an accessible patient to review or record imaging.</div></div></div>
    <div class="card card-pad">
      <EmptyState icon="user" title="No accessible patients" description="No patient is currently assigned to this doctor or present in today’s permitted waiting-room scope." />
    </div>
  </div>

  <div v-else>
    <div class="page-header">
      <div>
        <h1>Women’s Imaging &amp; Ultrasound</h1>
        <div class="desc">Structured IVF, gynecologic and peri-operative imaging reports.</div>
      </div>
      <div class="page-actions">
        <select class="input" :value="patient.patient_id" aria-label="Select patient" @change="switchPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} · {{ p.patient_id }}</option>
        </select>
        <button class="btn btn-secondary" @click="showPatientInfo = true"><Icon name="user" :size="13" /> Patient Information</button>
        <button class="btn btn-secondary" @click="openTemplateManager"><Icon name="clipboard" :size="13" /> Templates</button>
        <button class="btn btn-primary" :disabled="!templates.length" @click="openNewStudy()"><Icon name="plus" :size="13" /> New Imaging Study</button>
      </div>
    </div>

    <div class="grid grid-4" style="gap:12px; margin-bottom:16px;">
      <div class="card card-pad">
        <div class="muted" style="font-size:10.5px;">PATIENT</div>
        <div style="font-weight:700; margin-top:3px;">{{ patient.full_name }}</div>
        <div class="cell-muted mono">{{ patient.patient_id }}</div>
      </div>
      <div class="card card-pad">
        <div class="muted" style="font-size:10.5px;">AGE</div>
        <div style="font-weight:700; margin-top:3px;">{{ computeAge(patient.dob) }} years</div>
        <div class="cell-muted">{{ patient.sex || 'Sex not recorded' }}</div>
      </div>
      <div class="card card-pad">
        <div class="muted" style="font-size:10.5px;">ACTIVE CYCLE</div>
        <div style="font-weight:700; margin-top:3px;">{{ cycle ? `${cycle.type || 'Treatment'} · Day ${cycle.cycle_day}` : 'None' }}</div>
        <div class="cell-muted">{{ cycle?.stage || 'A study can still be recorded' }}</div>
      </div>
      <div class="card card-pad">
        <div class="muted" style="font-size:10.5px;">IMAGING HISTORY</div>
        <div style="font-weight:700; margin-top:3px;">{{ studies.length }} report{{ studies.length === 1 ? '' : 's' }}</div>
        <div class="cell-muted">{{ finalizedCount }} signed off · {{ draftCount }} draft</div>
      </div>
    </div>

    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header">
          <div>
            <h3><Icon name="activity" :size="15" /> Imaging History</h3>
            <div class="cell-muted" style="margin-top:3px;">Drafts stay in this clinical workspace; signed reports also appear in Patient Information.</div>
          </div>
          <select v-model="historyFilter" class="input" style="width:auto; min-width:145px;">
            <option value="All">All reports</option>
            <option value="Finalized">Finalized</option>
            <option value="Draft">Drafts</option>
          </select>
        </div>

        <table v-if="filteredStudies.length" class="data-table">
          <thead><tr><th>Study</th><th>Category</th><th>Date</th><th>Approach</th><th>Reported by</th><th>Status</th><th></th></tr></thead>
          <tbody>
            <tr v-for="study in filteredStudies" :key="study.id" class="clickable" @click="openStudy(study)">
              <td><div class="cell-strong">{{ study.study_type }}</div><div class="cell-muted">{{ study.indication || 'No indication recorded' }}</div></td>
              <td class="cell-muted">{{ study.category }}</td>
              <td class="cell-muted">{{ formatDateTime(study.performed_at) }}</td>
              <td class="cell-muted">{{ study.approach || '—' }}</td>
              <td class="cell-muted">{{ study.performed_by_name || 'Not recorded' }}</td>
              <td><StatusBadge :status="study.status" /></td>
              <td style="text-align:right;"><Icon :name="study.status === 'Draft' ? 'edit' : 'eye'" :size="14" /></td>
            </tr>
          </tbody>
        </table>
        <div v-else style="padding:24px;">
          <EmptyState icon="activity" :title="studies.length ? 'No reports in this filter' : 'No imaging studies yet'" :description="studies.length ? 'Choose a different report status.' : 'Start with a clinic template to record this patient’s first imaging study.'" />
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card card-pad">
          <div class="flex-between">
            <b style="font-size:13px;"><Icon name="clipboard" :size="13" /> Quick Templates</b>
            <span class="link" @click="openTemplateManager">Manage</span>
          </div>
          <div style="display:flex; flex-direction:column; gap:7px; margin-top:10px;">
            <button v-for="template in templates.slice(0, 6)" :key="template.id" class="template-button" @click="openNewStudy(template.id)">
              <span><b>{{ template.name }}</b><small>{{ template.category }}</small></span>
              <Icon name="chevron-right" :size="12" />
            </button>
          </div>
        </div>

        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="shield" :size="13" /> Report safeguards</b>
          <ul class="safety-list">
            <li>Templates contain field structure only—not patient findings.</li>
            <li>An impression is required before finalization.</li>
            <li>Finalized reports appear in Patient Information.</li>
            <li>The system does not calculate viability or O-RADS classification.</li>
          </ul>
        </div>
      </div>
    </div>

    <PatientDetailModal
      v-model="showPatientInfo"
      :patient="patient"
      :cycle="cycle"
      :consultations="pastConsultations"
      :lab-results="pastLabResults"
      :caps="{}"
      @open-spouse="$router.push(`/doctor/patients?patient=${$event}&linkedFrom=${patient.patient_id}`)"
    />

    <Modal v-model="showStudyEditor" :title="studyEditorTitle" wide>
      <div class="report-banner">
        <div><b>{{ patient.full_name }}</b><div class="cell-muted mono">{{ patient.patient_id }}</div></div>
        <Badge v-if="studyDraft.saveMode === 'Amended'" tone="amber">Amendment</Badge>
      </div>

      <div class="form-row">
        <div class="field">
          <label>Report Template *</label>
          <select v-model="studyDraft.templateId" class="input" :disabled="!!studyDraft.id" @change="applySelectedTemplate(true)">
            <optgroup v-for="group in templateGroups" :key="group.category" :label="group.category">
              <option v-for="template in group.templates" :key="template.id" :value="template.id">{{ template.name }}</option>
            </optgroup>
          </select>
        </div>
        <div class="field"><label>Examination date and time *</label><input v-model="studyDraft.performedAt" class="input" type="datetime-local" /></div>
      </div>
      <div class="form-row">
        <div class="field"><label>Study type *</label><input v-model="studyDraft.studyType" class="input" maxlength="120" /></div>
        <div class="field">
          <label>Approach</label>
          <select v-model="studyDraft.approach" class="input">
            <option value="">Not recorded</option>
            <option v-for="approach in approaches" :key="approach" :value="approach">{{ approach }}</option>
          </select>
        </div>
      </div>
      <div class="field"><label>Clinical indication</label><textarea v-model="studyDraft.indication" class="input" rows="2" maxlength="4000" placeholder="Reason for examination, relevant symptoms and clinical question" /></div>
      <div class="form-row">
        <div class="field"><label>Last menstrual period</label><input v-model="studyDraft.lmp" class="input" type="date" /></div>
        <div class="field"><label>Cycle day</label><input v-model="studyDraft.cycleDay" class="input" type="number" min="1" max="100" /></div>
      </div>
      <div class="field"><label>Technique</label><textarea v-model="studyDraft.technique" class="input" rows="2" maxlength="4000" placeholder="Transducer/approach, limitations, procedure details or deviations" /></div>

      <div v-for="section in studyFieldSections" :key="section.name" class="report-section">
        <h4>{{ section.name }}</h4>
        <div class="grid grid-2" style="gap:12px;">
          <div v-for="field in section.fields" :key="field.key" class="field" :style="field.type === 'textarea' ? 'grid-column:1 / -1;' : ''">
            <label>{{ field.label }}<span v-if="field.required"> *</span><span v-if="field.unit"> ({{ field.unit }})</span></label>
            <textarea v-if="field.type === 'textarea'" :value="textFinding(field.key)" class="input" rows="3" @input="setTextFinding(field.key, $event)" />
            <select v-else-if="field.type === 'select'" :value="textFinding(field.key)" class="input" @change="setTextFinding(field.key, $event)">
              <option value="">Select…</option>
              <option v-for="option in field.options || []" :key="option" :value="option">{{ option }}</option>
            </select>
            <label v-else-if="field.type === 'checkbox'" class="check-row"><input :checked="studyDraft.findings[field.key] === true" type="checkbox" @change="setCheckboxFinding(field.key, $event)" /> Yes</label>
            <input v-else :value="textFinding(field.key)" class="input" :type="field.type" :step="field.type === 'number' ? 'any' : undefined" @input="setTextFinding(field.key, $event)" />
          </div>
        </div>
      </div>

      <div class="report-section">
        <h4>Conclusion</h4>
        <div class="field"><label>Impression <span v-if="studyDraft.saveMode !== 'Draft'">*</span></label><textarea v-model="studyDraft.impression" class="input" rows="4" maxlength="8000" placeholder="Clinician’s interpretation of the examination" /></div>
        <div class="field"><label>Recommendations / follow-up</label><textarea v-model="studyDraft.recommendations" class="input" rows="3" maxlength="4000" /></div>
        <div class="field"><label>Image, accession or PACS reference</label><input v-model="studyDraft.imageReference" class="input" maxlength="500" placeholder="Reference only; no image is uploaded by this form" /></div>
        <div v-if="studyDraft.saveMode === 'Amended'" class="field"><label>Reason for amendment *</label><textarea v-model="studyDraft.amendmentReason" class="input" rows="2" maxlength="1000" placeholder="Explain why the signed report is being changed" /></div>
      </div>

      <p v-if="saveError" class="form-error"><Icon name="alert" :size="12" /> {{ saveError }}</p>
      <template #footer>
        <button class="btn btn-secondary" @click="showStudyEditor = false">Cancel</button>
        <button v-if="studyDraft.saveMode !== 'Amended'" class="btn btn-secondary" :disabled="savingStudy" @click="submitStudy('Draft')">Save Draft</button>
        <button class="btn btn-primary" :disabled="savingStudy" @click="submitStudy(studyDraft.saveMode === 'Amended' ? 'Amended' : 'Final')">
          <Icon name="check-circle" :size="13" /> {{ studyDraft.saveMode === 'Amended' ? 'Save Amendment' : 'Finalize Report' }}
        </button>
      </template>
    </Modal>

    <Modal v-model="showStudyDetail" :title="selectedStudy?.study_type || 'Imaging Report'" wide>
      <template v-if="selectedStudy">
        <div class="report-banner">
          <div><b>{{ patient.full_name }}</b><div class="cell-muted mono">{{ patient.patient_id }}</div></div>
          <StatusBadge :status="selectedStudy.status" />
        </div>
        <div class="grid grid-4" style="gap:10px; margin-bottom:14px;">
          <div><div class="muted report-label">DATE</div><div class="report-value">{{ formatDateTime(selectedStudy.performed_at) }}</div></div>
          <div><div class="muted report-label">APPROACH</div><div class="report-value">{{ selectedStudy.approach || '—' }}</div></div>
          <div><div class="muted report-label">REPORTED BY</div><div class="report-value">{{ selectedStudy.performed_by_name || 'Not recorded' }}</div></div>
          <div><div class="muted report-label">CYCLE DAY</div><div class="report-value">{{ selectedStudy.cycle_day || '—' }}</div></div>
        </div>
        <div v-if="selectedStudy.indication" class="report-section"><h4>Clinical indication</h4><p>{{ selectedStudy.indication }}</p></div>
        <div v-if="selectedStudy.technique" class="report-section"><h4>Technique</h4><p>{{ selectedStudy.technique }}</p></div>
        <div v-for="section in reportFindingSections(selectedStudy)" :key="section.name" class="report-section">
          <h4>{{ section.name }}</h4>
          <table class="data-table compact-table"><tbody><tr v-for="row in section.rows" :key="row.key"><td class="cell-strong">{{ row.label }}</td><td>{{ row.value }}<span v-if="row.unit"> {{ row.unit }}</span></td></tr></tbody></table>
        </div>
        <div class="report-section"><h4>Impression</h4><p>{{ selectedStudy.impression || 'No impression recorded.' }}</p></div>
        <div v-if="selectedStudy.recommendations" class="report-section"><h4>Recommendations / follow-up</h4><p>{{ selectedStudy.recommendations }}</p></div>
        <div v-if="selectedStudy.amendment_reason" class="report-section"><h4>Reason for amendment</h4><p>{{ selectedStudy.amendment_reason }}</p></div>
        <div v-if="selectedStudy.image_reference" class="report-section"><h4>Image / accession reference</h4><p class="mono">{{ selectedStudy.image_reference }}</p></div>
      </template>
      <template #footer>
        <button class="btn btn-secondary" @click="showStudyDetail = false">Close</button>
        <button v-if="selectedStudy && canAmend(selectedStudy)" class="btn btn-primary" @click="startAmendment"><Icon name="edit" :size="13" /> Amend Report</button>
      </template>
    </Modal>

    <Modal v-model="showTemplates" :title="templateMode === 'list' ? 'Imaging Report Templates' : templateDraft.id ? 'Edit Custom Template' : 'New Custom Template'" wide>
      <template v-if="templateMode === 'list'">
        <div class="flex-between" style="margin-bottom:12px;">
          <p class="cell-muted">Templates save reusable field structure only. Findings are always entered separately for each patient.</p>
          <button class="btn btn-primary btn-sm" @click="newTemplate"><Icon name="plus" :size="12" /> New Template</button>
        </div>
        <div style="display:flex; flex-direction:column; gap:8px;">
          <div v-for="template in templates" :key="template.id" class="template-list-row">
            <div><div class="main-txt">{{ template.name }} <Badge :tone="template.system_template ? 'blue' : 'gray'">{{ template.system_template ? 'System' : 'Custom' }}</Badge></div><div class="sub-txt">{{ template.category }} · {{ template.fields.length }} fields{{ template.description ? ' · ' + template.description : '' }}</div></div>
            <button v-if="canEditTemplate(template)" class="btn btn-secondary btn-sm" @click="editTemplate(template)"><Icon name="edit" :size="12" /> Edit</button>
          </div>
        </div>
      </template>
      <template v-else>
        <div class="form-row">
          <div class="field"><label>Template name *</label><input v-model="templateDraft.name" class="input" maxlength="120" /></div>
          <div class="field"><label>Category *</label><input v-model="templateDraft.category" class="input" list="imaging-categories" maxlength="80" /></div>
        </div>
        <datalist id="imaging-categories"><option value="IVF Monitoring" /><option value="Pelvic / Gynecologic" /><option value="Uterine Cavity / Procedure" /><option value="Peri-operative" /><option value="Early Pregnancy" /></datalist>
        <div class="field"><label>Study type *</label><input v-model="templateDraft.studyType" class="input" maxlength="120" /></div>
        <div class="field"><label>Description</label><textarea v-model="templateDraft.description" class="input" rows="2" maxlength="1000" /></div>

        <div class="flex-between" style="margin:16px 0 8px;"><b>Report fields</b><button class="btn btn-secondary btn-sm" @click="addTemplateField"><Icon name="plus" :size="12" /> Add Field</button></div>
        <div v-for="(field, index) in templateDraft.fields" :key="index" class="field-builder-row">
          <div class="grid grid-4" style="gap:8px; flex:1;">
            <div class="field"><label>Section</label><input v-model="field.section" class="input" maxlength="80" /></div>
            <div class="field"><label>Label</label><input v-model="field.label" class="input" maxlength="120" /></div>
            <div class="field"><label>Field key</label><input v-model="field.key" class="input mono" maxlength="64" /></div>
            <div class="field"><label>Type</label><select v-model="field.type" class="input"><option v-for="type in fieldTypes" :key="type.value" :value="type.value">{{ type.label }}</option></select></div>
          </div>
          <div class="flex gap-8" style="align-items:flex-end; margin-top:8px;">
            <div class="field" style="width:100px;"><label>Unit</label><input v-model="field.unit" class="input" maxlength="30" /></div>
            <div v-if="field.type === 'select'" class="field" style="min-width:210px;"><label>Options (comma-separated)</label><input :value="(field.options || []).join(', ')" class="input" @input="setFieldOptions(field, ($event.target as HTMLInputElement).value)" /></div>
            <label class="check-row" style="padding-bottom:9px;"><input v-model="field.required" type="checkbox" /> Required</label>
            <button class="btn btn-secondary btn-sm" title="Remove field" @click="removeTemplateField(index)"><Icon name="trash" :size="12" /></button>
          </div>
        </div>
        <p v-if="templateError" class="form-error"><Icon name="alert" :size="12" /> {{ templateError }}</p>
      </template>
      <template #footer>
        <template v-if="templateMode === 'list'"><button class="btn btn-secondary" @click="showTemplates = false">Close</button></template>
        <template v-else>
          <button class="btn btn-secondary" @click="templateMode = 'list'">Back</button>
          <button class="btn btn-primary" :disabled="savingTemplate" @click="submitTemplate"><Icon name="check-circle" :size="13" /> Save Template</button>
        </template>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { computeAge } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'
import { useToast } from '~/composables/useToast'
import { fetchClinicalPatientContext, fetchClinicalPatientDirectory } from '~/composables/useClinicalPatientAccess'
import {
  fetchImagingWorkspace,
  saveImagingStudy,
  saveImagingTemplate,
  type ImagingStudy,
  type ImagingTemplate,
  type ImagingTemplateField,
} from '~/composables/useImagingWorkspace'

const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const route = useRoute()
const router = useRouter()

const patients = ref<any[]>([])
const patient = ref<any>(null)
const cycle = ref<any>(null)
const pastConsultations = ref<any[]>([])
const pastLabResults = ref<any[]>([])
const templates = ref<ImagingTemplate[]>([])
const studies = ref<ImagingStudy[]>([])
const loadingPatient = ref(false)
const loadError = ref('')
const showPatientInfo = ref(false)
const historyFilter = ref<'All' | 'Finalized' | 'Draft'>('All')

const finalizedCount = computed(() => studies.value.filter(study => study.status !== 'Draft').length)
const draftCount = computed(() => studies.value.filter(study => study.status === 'Draft').length)
const filteredStudies = computed(() => studies.value.filter((study) => {
  if (historyFilter.value === 'Draft') return study.status === 'Draft'
  if (historyFilter.value === 'Finalized') return study.status !== 'Draft'
  return true
}))

const templateGroups = computed(() => {
  const groups = new Map<string, ImagingTemplate[]>()
  for (const template of templates.value) {
    const group = groups.get(template.category) || []
    group.push(template)
    groups.set(template.category, group)
  }
  return [...groups.entries()].map(([category, groupedTemplates]) => ({ category, templates: groupedTemplates }))
})

async function loadPatient(patientId: string) {
  if (!patients.value.some(entry => entry.patient_id === patientId)) return
  loadingPatient.value = true
  loadError.value = ''
  try {
    const [context, workspace] = await Promise.all([
      fetchClinicalPatientContext(supabase, patientId),
      fetchImagingWorkspace(supabase, patientId),
    ])
    if (!context.patient) throw new Error('Patient context is unavailable')
    patient.value = context.patient
    cycle.value = context.cycle
    pastConsultations.value = context.pastConsultations
    pastLabResults.value = context.pastLabResults
    templates.value = workspace.templates
    studies.value = workspace.studies
  } catch (error) {
    patient.value = null
    cycle.value = null
    pastConsultations.value = []
    pastLabResults.value = []
    templates.value = []
    studies.value = []
    loadError.value = errorMessage(error, 'Patient imaging context could not be loaded.')
  } finally {
    loadingPatient.value = false
  }
}

const investigationDirectoryKey = `doctor-investigation-directory-${profile.value?.id || 'anonymous'}`
const {
  data: directoryData,
  error: directoryError,
  status: directoryStatus,
  refresh: refreshDirectory,
} = await useAsyncData<any[]>(investigationDirectoryKey, async () => {
  const directory = await fetchClinicalPatientDirectory(supabase)
  return directory.patients
}, {
  default: () => [],
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

patients.value = directoryData.value || []
const requestedPatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
const initialPatientId = patients.value.some(entry => entry.patient_id === requestedPatientId)
  ? requestedPatientId
  : patients.value[0]?.patient_id
if (initialPatientId) await loadPatient(initialPatientId)

function switchPatient(patientId: string) {
  void router.replace({ query: { ...route.query, patient: patientId } })
  void loadPatient(patientId)
}

async function retryInvestigations() {
  loadError.value = ''
  await refreshDirectory()
  patients.value = directoryData.value || []
  if (directoryError.value) return
  const routePatientId = typeof route.query.patient === 'string' ? route.query.patient : ''
  const nextPatientId = patients.value.some(entry => entry.patient_id === routePatientId)
    ? routePatientId
    : patients.value[0]?.patient_id
  if (nextPatientId) await loadPatient(nextPatientId)
}

watch(
  () => route.query.patient,
  (patientId) => {
    if (typeof patientId === 'string' && patientId !== patient.value?.patient_id && patients.value.some(entry => entry.patient_id === patientId)) {
      void loadPatient(patientId)
    }
  },
)

const approaches = ['Transvaginal', 'Transabdominal', 'Combined', 'Transrectal', 'Transperineal', 'Intraoperative', 'Other']
const showStudyEditor = ref(false)
const savingStudy = ref(false)
const saveError = ref('')

function localDateTime() {
  const now = new Date()
  return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}

const studyDraft = reactive({
  id: null as string | null,
  templateId: '',
  category: '',
  studyType: '',
  indication: '',
  approach: '',
  performedAt: '',
  lmp: '',
  cycleDay: '' as string | number,
  technique: '',
  findings: {} as Record<string, string | number | boolean | null>,
  impression: '',
  recommendations: '',
  imageReference: '',
  amendmentReason: '',
  saveMode: 'Draft' as 'Draft' | 'Amended',
})

const selectedTemplate = computed(() => templates.value.find(template => template.id === studyDraft.templateId) || null)
const studyFieldSections = computed(() => groupTemplateFields(selectedTemplate.value?.fields || []))
const studyEditorTitle = computed(() => studyDraft.saveMode === 'Amended' ? 'Amend Imaging Report' : studyDraft.id ? 'Edit Imaging Draft' : 'New Imaging Study')

function openNewStudy(templateId?: string) {
  const selectedId = templateId || templates.value[0]?.id || ''
  Object.assign(studyDraft, {
    id: null,
    templateId: selectedId,
    category: '',
    studyType: '',
    indication: '',
    approach: '',
    performedAt: localDateTime(),
    lmp: '',
    cycleDay: cycle.value?.cycle_day || '',
    technique: '',
    findings: {},
    impression: '',
    recommendations: '',
    imageReference: '',
    amendmentReason: '',
    saveMode: 'Draft',
  })
  applySelectedTemplate(false)
  saveError.value = ''
  showStudyEditor.value = true
}

function applySelectedTemplate(clearFindings: boolean) {
  const template = selectedTemplate.value
  if (!template) return
  studyDraft.category = template.category
  studyDraft.studyType = template.study_type
  if (clearFindings) studyDraft.findings = {}
}

function editDraft(study: ImagingStudy, asAmendment = false) {
  Object.assign(studyDraft, {
    id: study.id,
    templateId: study.template_id,
    category: study.category,
    studyType: study.study_type,
    indication: study.indication || '',
    approach: study.approach || '',
    performedAt: toLocalInput(study.performed_at),
    lmp: study.lmp || '',
    cycleDay: study.cycle_day || '',
    technique: study.technique || '',
    findings: { ...(study.findings || {}) },
    impression: study.impression || '',
    recommendations: study.recommendations || '',
    imageReference: study.image_reference || '',
    amendmentReason: '',
    saveMode: asAmendment ? 'Amended' : 'Draft',
  })
  saveError.value = ''
  showStudyEditor.value = true
}

async function submitStudy(status: 'Draft' | 'Final' | 'Amended') {
  saveError.value = ''
  if (!patient.value || !selectedTemplate.value || !studyDraft.performedAt) {
    saveError.value = 'Template and examination date/time are required.'
    return
  }
  if (status !== 'Draft' && !studyDraft.impression.trim()) {
    saveError.value = 'Enter an impression before finalizing the report.'
    return
  }
  if (status === 'Amended' && !studyDraft.amendmentReason.trim()) {
    saveError.value = 'Enter a reason for amending the signed report.'
    return
  }
  if (status !== 'Draft') {
    const missing = selectedTemplate.value.fields.filter(field => field.required && isEmptyFinding(studyDraft.findings[field.key]))
    if (missing.length) {
      saveError.value = `Complete required finding${missing.length === 1 ? '' : 's'}: ${missing.map(field => field.label).join(', ')}.`
      return
    }
  }

  const findings: Record<string, string | number | boolean | null> = {}
  for (const field of selectedTemplate.value.fields) {
    const value = studyDraft.findings[field.key]
    if (!isEmptyFinding(value)) findings[field.key] = value
  }

  savingStudy.value = true
  try {
    await saveImagingStudy(supabase, {
      id: studyDraft.id,
      patientId: patient.value.patient_id,
      cycleId: cycle.value?.id || null,
      templateId: selectedTemplate.value.id,
      category: studyDraft.category,
      studyType: studyDraft.studyType,
      indication: studyDraft.indication,
      approach: studyDraft.approach || null,
      performedAt: new Date(studyDraft.performedAt).toISOString(),
      lmp: studyDraft.lmp || null,
      cycleDay: studyDraft.cycleDay === '' ? null : Number(studyDraft.cycleDay),
      technique: studyDraft.technique,
      findings,
      impression: studyDraft.impression,
      recommendations: studyDraft.recommendations,
      imageReference: studyDraft.imageReference,
      amendmentReason: studyDraft.amendmentReason,
      status,
    })
    const workspace = await fetchImagingWorkspace(supabase, patient.value.patient_id)
    templates.value = workspace.templates
    studies.value = workspace.studies
    showStudyEditor.value = false
    toast(status === 'Draft' ? 'Imaging draft saved.' : status === 'Amended' ? 'Imaging report amended.' : 'Imaging report finalized.', 'success')
  } catch (error) {
    saveError.value = errorMessage(error, 'The imaging report could not be saved.')
  } finally {
    savingStudy.value = false
  }
}

const showStudyDetail = ref(false)
const selectedStudy = ref<ImagingStudy | null>(null)
function openStudy(study: ImagingStudy) {
  if (study.status === 'Draft') return editDraft(study)
  selectedStudy.value = study
  showStudyDetail.value = true
}
function canAmend(study: ImagingStudy) {
  return profile.value?.role === 'matron' || study.performed_by_profile_id === profile.value?.id
}
function startAmendment() {
  if (!selectedStudy.value) return
  const study = selectedStudy.value
  showStudyDetail.value = false
  editDraft(study, true)
}

const showTemplates = ref(false)
const templateMode = ref<'list' | 'edit'>('list')
const savingTemplate = ref(false)
const templateError = ref('')
const templateDraft = reactive({
  id: null as string | null,
  name: '',
  category: '',
  studyType: '',
  description: '',
  fields: [] as ImagingTemplateField[],
})
const fieldTypes = [
  { value: 'text', label: 'Short text' },
  { value: 'textarea', label: 'Long text' },
  { value: 'number', label: 'Number' },
  { value: 'select', label: 'Choice list' },
  { value: 'checkbox', label: 'Yes / no' },
  { value: 'date', label: 'Date' },
] as const

function openTemplateManager() {
  templateMode.value = 'list'
  templateError.value = ''
  showTemplates.value = true
}
function newTemplate() {
  Object.assign(templateDraft, { id: null, name: '', category: '', studyType: '', description: '', fields: [] })
  addTemplateField()
  templateError.value = ''
  templateMode.value = 'edit'
}
function editTemplate(template: ImagingTemplate) {
  Object.assign(templateDraft, {
    id: template.id,
    name: template.name,
    category: template.category,
    studyType: template.study_type,
    description: template.description || '',
    fields: template.fields.map(field => ({ ...field, options: field.options ? [...field.options] : undefined })),
  })
  templateError.value = ''
  templateMode.value = 'edit'
}
function canEditTemplate(template: ImagingTemplate) {
  return !template.system_template && (profile.value?.role === 'matron' || template.created_by_profile_id === profile.value?.id)
}
function addTemplateField() {
  const suffix = `${Date.now()}_${templateDraft.fields.length}`
  templateDraft.fields.push({ key: `field_${suffix}`, label: '', section: 'Findings', type: 'text', unit: '', required: false })
}
function removeTemplateField(index: number) {
  templateDraft.fields.splice(index, 1)
}
function setFieldOptions(field: ImagingTemplateField, value: string) {
  field.options = value.split(',').map(option => option.trim()).filter(Boolean)
}
async function submitTemplate() {
  templateError.value = ''
  if (!templateDraft.name.trim() || !templateDraft.category.trim() || !templateDraft.studyType.trim() || !templateDraft.fields.length) {
    templateError.value = 'Name, category, study type and at least one field are required.'
    return
  }
  const badField = templateDraft.fields.find(field => !field.section.trim() || !field.label.trim() || !/^[a-z][a-z0-9_]{0,63}$/.test(field.key))
  if (badField) {
    templateError.value = 'Every field needs a section, label and a lowercase key containing only letters, numbers and underscores.'
    return
  }
  if (new Set(templateDraft.fields.map(field => field.key)).size !== templateDraft.fields.length) {
    templateError.value = 'Field keys must be unique.'
    return
  }
  const badSelect = templateDraft.fields.find(field => field.type === 'select' && !field.options?.length)
  if (badSelect) {
    templateError.value = `Add at least one option for ${badSelect.label}.`
    return
  }

  savingTemplate.value = true
  try {
    await saveImagingTemplate(supabase, {
      id: templateDraft.id,
      name: templateDraft.name,
      category: templateDraft.category,
      studyType: templateDraft.studyType,
      description: templateDraft.description,
      fields: templateDraft.fields.map(field => {
        const clean: ImagingTemplateField = { key: field.key, label: field.label, section: field.section, type: field.type }
        if (field.unit?.trim()) clean.unit = field.unit.trim()
        if (field.type === 'select') clean.options = field.options
        if (field.required) clean.required = true
        return clean
      }),
    })
    const workspace = await fetchImagingWorkspace(supabase, patient.value.patient_id)
    templates.value = workspace.templates
    studies.value = workspace.studies
    templateMode.value = 'list'
    toast('Imaging template saved.', 'success')
  } catch (error) {
    templateError.value = errorMessage(error, 'The template could not be saved.')
  } finally {
    savingTemplate.value = false
  }
}

function groupTemplateFields(fields: ImagingTemplateField[]) {
  const groups = new Map<string, ImagingTemplateField[]>()
  for (const field of fields) {
    const group = groups.get(field.section) || []
    group.push(field)
    groups.set(field.section, group)
  }
  return [...groups.entries()].map(([name, groupedFields]) => ({ name, fields: groupedFields }))
}

function reportFindingSections(study: ImagingStudy) {
  return groupTemplateFields(study.template_fields || []).map(section => ({
    name: section.name,
    rows: section.fields
      .filter(field => !isEmptyFinding(study.findings?.[field.key]))
      .map(field => ({ key: field.key, label: field.label, unit: field.unit, value: formatFinding(study.findings[field.key]) })),
  })).filter(section => section.rows.length)
}

function textFinding(key: string) {
  const value = studyDraft.findings[key]
  return typeof value === 'string' || typeof value === 'number' ? value : ''
}
function setTextFinding(key: string, event: Event) {
  studyDraft.findings[key] = (event.target as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value
}
function setCheckboxFinding(key: string, event: Event) {
  studyDraft.findings[key] = (event.target as HTMLInputElement).checked
}

function formatFinding(value: string | number | boolean | null | undefined) {
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  return value == null || value === '' ? '—' : String(value)
}
function isEmptyFinding(value: unknown) {
  return value === undefined || value === null || value === ''
}
function toLocalInput(value: string) {
  const date = new Date(value)
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}
function formatDateTime(value: string) {
  if (!value) return '—'
  return new Intl.DateTimeFormat('en-NG', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}
function errorMessage(error: unknown, fallback: string) {
  if (error && typeof error === 'object' && 'message' in error && typeof error.message === 'string') return error.message
  return fallback
}
</script>

<style scoped>
.template-button {
  display:flex; align-items:center; justify-content:space-between; gap:10px; width:100%;
  padding:9px 10px; border:1px solid var(--border); border-radius:var(--radius-sm);
  background:var(--card); color:var(--text-900); text-align:left; cursor:pointer;
}
.template-button:hover { border-color:var(--blue-500); background:var(--blue-50); }
.template-button b { display:block; font-size:11.5px; }
.template-button small { display:block; margin-top:2px; color:var(--text-500); font-size:10.5px; }
.safety-list { margin:9px 0 0; padding-left:17px; color:var(--text-700); font-size:11.5px; line-height:1.55; }
.report-banner { display:flex; justify-content:space-between; align-items:center; padding:10px 12px; margin-bottom:14px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--blue-50); }
.report-section { margin-top:16px; padding-top:14px; border-top:1px solid var(--border); }
.report-section h4 { margin:0 0 10px; font-size:12px; color:var(--text-900); }
.report-section p { white-space:pre-wrap; font-size:12.5px; color:var(--text-700); }
.report-label { font-size:10px; }
.report-value { margin-top:3px; font-size:12px; font-weight:600; }
.compact-table td:first-child { width:42%; }
.template-list-row { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:10px 12px; border:1px solid var(--border); border-radius:var(--radius-sm); }
.field-builder-row { padding:12px; margin-bottom:10px; border:1px solid var(--border); border-radius:var(--radius-sm); background:var(--bg); }
.check-row { display:flex; align-items:center; gap:7px; font-size:12px; color:var(--text-700); }
.form-error { margin-top:12px; color:var(--red-600); font-size:12px; }
@media (max-width: 800px) {
  .grid-4, .grid-2 { grid-template-columns:1fr !important; }
  .field-builder-row .grid-4 { grid-template-columns:1fr !important; }
}
</style>
