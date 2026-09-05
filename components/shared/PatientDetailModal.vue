<template>
  <Modal :model-value="modelValue" :title="patientRecord?.full_name || ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="patientRecord">
      <div class="patient-photo-hero">
        <div class="patient-photo">
          <img v-if="patientPhotoUrl" :src="patientPhotoUrl" :alt="`${patientRecord.full_name} patient picture`" />
          <Avatar v-else :name="patientRecord.full_name" :size="68" />
        </div>
        <div class="grid grid-4 patient-hero-facts">
          <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.patient_id }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(patientRecord.dob) }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.blood_group || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="patientRecord.status" /></div>
        </div>
      </div>
      <div class="registration-strip">
        <div><span>Sex</span><b>{{ patientRecord.sex || '—' }}</b></div>
        <div><span>Date of birth</span><b>{{ patientRecord.dob ? fmtDate(patientRecord.dob) : '—' }}</b></div>
        <div><span>Registered</span><b>{{ patientRecord.registered_on ? fmtDate(patientRecord.registered_on) : '—' }}</b></div>
        <div><span>Referral source</span><b>{{ patientRecord.referral_source || '—' }}</b></div>
        <div><span>Assigned doctor</span><b>{{ assignedDoctorName || 'Unassigned' }}</b></div>
        <div><span>Consent</span><b>{{ patientRecord.registration_consent_at || patientRecord.consent_form_url ? 'On file' : 'Not recorded' }}</b></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;">Contact</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);"><Icon name="phone" :size="11" /> {{ patientRecord.phone || '—' }} &nbsp; <Icon name="mail" :size="11" /> {{ patientRecord.email || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700);">{{ patientRecord.address || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700); margin-top:4px;">Emergency: {{ patientRecord.emergency_contact?.name || '—' }} ({{ patientRecord.emergency_contact?.relationship || '—' }}) · {{ patientRecord.emergency_contact?.phone || '—' }}</p>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="clipboard" :size="12" /> Medical History</b>
      <div class="grid grid-3" style="margin-top:8px; gap:10px;">
        <div><div class="muted" style="font-size:10.5px;">ALLERGIES</div><div style="font-weight:600; font-size:12.5px;" :style="{ color: patientRecord.allergies?.length ? 'var(--red-600)' : 'var(--text-900)' }">{{ patientRecord.allergies?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">CHRONIC CONDITIONS</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.chronic_conditions?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">OBSTETRIC HISTORY</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.obstetric_history || '—' }}</div></div>
      </div>
      <div v-if="patientRecord.past_surgeries?.length" style="margin-top:8px;"><div class="muted" style="font-size:10.5px;">PAST SURGERIES</div><div style="font-size:12px;">{{ formatPastSurgeries(patientRecord.past_surgeries) }}</div></div>
      <hr class="hr" />
      <div class="flex-between"><b style="font-size:12.5px;"><Icon name="activity" :size="12" /> Nursing Vitals &amp; Intake</b><Badge v-if="latestNurseVisit" tone="blue">Latest {{ fmtDate(latestNurseVisit.visit_date) }}</Badge></div>
      <div v-if="latestNurseVisit" style="margin-top:9px;">
        <div class="vitals-grid">
          <div><span>Blood pressure</span><b>{{ bloodPressure(latestNurseVisit) }}</b></div><div><span>Pulse</span><b>{{ withUnit(latestNurseVisit.pulse_bpm, 'bpm') }}</b></div><div><span>Respiratory rate</span><b>{{ withUnit(latestNurseVisit.respiratory_rate_bpm, '/min') }}</b></div>
          <div><span>Temperature</span><b>{{ withUnit(latestNurseVisit.temperature_c, '°C') }}</b></div><div><span>SpO₂</span><b>{{ withUnit(latestNurseVisit.spo2_pct, '%') }}</b></div><div><span>Weight</span><b>{{ withUnit(latestNurseVisit.weight_kg, 'kg') }}</b></div>
          <div><span>Height</span><b>{{ withUnit(latestNurseVisit.height_cm, 'cm') }}</b></div><div><span>BMI</span><b>{{ visitBmi(latestNurseVisit) }}</b></div><div><span>Pain</span><b>{{ latestNurseVisit.pain_score != null ? `${latestNurseVisit.pain_score}/10` : '—' }}</b></div>
        </div>
        <p v-if="latestNurseVisit.chief_complaint" class="clinical-copy"><b>Reason for visit:</b> {{ latestNurseVisit.chief_complaint }}</p>
        <div v-if="latestNurseVisit.reproductive_intake && Object.keys(latestNurseVisit.reproductive_intake).length" class="intake-box">
          <b>Fertility context</b><p>{{ reproductiveSummary(latestNurseVisit.reproductive_intake) }}</p>
        </div>
        <div v-if="latestNurseVisit.medical_intake && Object.keys(latestNurseVisit.medical_intake).length" class="intake-box"><b>Reported medical intake</b><p>{{ medicalSummary(latestNurseVisit.medical_intake) }}</p></div>
        <p v-if="latestNurseVisit.nursing_notes" class="clinical-copy"><b>Nursing notes:</b> {{ latestNurseVisit.nursing_notes }}</p>
        <p v-if="latestNurseVisit.post_visit_instructions" class="clinical-copy"><b>Post-visit instructions:</b> {{ latestNurseVisit.post_visit_instructions }}</p>
        <p class="cell-muted" style="margin-top:5px;">Recorded by {{ nurseName(latestNurseVisit.documented_by) }} · {{ latestNurseVisit.visit_type || 'Clinical visit' }}</p>
        <details v-for="visit in nurseVisits" :key="visit.id" class="visit-history-item">
          <summary><span>{{ fmtDate(visit.visit_date) }} · {{ visit.visit_type || 'Nursing visit' }}</span><StatusBadge :status="visit.condition || 'Recorded'" /></summary>
          <p>{{ compactVitalSummary(visit) }}</p>
          <p v-if="visit.chief_complaint"><b>Reason:</b> {{ visit.chief_complaint }}</p>
          <p v-if="visit.nursing_notes"><b>Notes:</b> {{ visit.nursing_notes }}</p>
          <p v-if="visit.post_visit_instructions"><b>Instructions:</b> {{ visit.post_visit_instructions }}</p>
          <p v-if="visit.reproductive_intake && Object.keys(visit.reproductive_intake).length"><b>Fertility:</b> {{ reproductiveSummary(visit.reproductive_intake) }}</p>
          <p v-if="visit.medical_intake && Object.keys(visit.medical_intake).length"><b>Medical intake:</b> {{ medicalSummary(visit.medical_intake) }}</p>
        </details>
      </div>
      <p v-else class="muted" style="font-size:12px; margin-top:7px;">No nursing observations recorded yet.</p>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="layers" :size="12" /> Treatment Cycle</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
        {{ cycle ? `${cycle.type} — ${cycle.stage} (Day ${cycle.cycle_day}) · ${cycle.protocol}` : 'No active treatment cycle.' }}
      </p>
      <p v-if="cycle" class="cell-muted" style="margin-top:4px;"><Icon name="user" :size="11" /> Cycle Manager: {{ cycleManagerName || 'Unassigned' }}</p>
      <div v-if="cycle" style="margin-top:12px;">
        <CycleDayChart :cycle-id="cycle.id" :start-date="cycle.start_date" :can-edit="false" />
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="syringe" :size="12" /> Transfer &amp; Cryopreservation</b>
      <div v-if="embryosTransferredTotal > 0 || cryoStoredCount > 0" class="grid grid-2" style="margin:8px 0; gap:10px;">
        <div><div class="muted" style="font-size:10.5px;">EMBRYOS TRANSFERRED</div><div style="font-weight:700;">{{ embryosTransferredTotal }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">CURRENTLY IN STORAGE</div><div style="font-weight:700;">{{ cryoStoredCount }}</div></div>
      </div>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!transferCryoEvents.length" class="muted" style="font-size:12px;">No transfer or cryo events scheduled.</p>
        <div v-for="e in transferCryoEvents" :key="e.id" class="list-row" style="padding:6px 0;">
          <div><div class="main-txt">{{ e.type }}<span v-if="e.embryos_used != null" class="cell-muted"> — {{ e.embryos_used }} used</span></div><div class="sub-txt">{{ fmtDate(e.scheduled_date) }}{{ e.notes ? ' · ' + e.notes : '' }}</div></div>
          <StatusBadge :status="e.status" />
        </div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="activity" :size="12" /> Surgical Procedures</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!surgeries.length" class="muted" style="font-size:12px;">No procedures scheduled or on record.</p>
        <div v-for="s in surgeries" :key="s.id" class="list-row" style="padding:6px 0;">
          <div><div class="main-txt">{{ s.procedure }}</div><div class="sub-txt">{{ fmtDate(s.date) }}{{ s.time ? ' · ' + s.time : '' }}{{ s.location ? ' · ' + s.location : '' }}</div></div>
          <StatusBadge :status="s.status" />
        </div>
      </div>
      <template v-if="spouseSummary || patientRecord.spouse">
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="user" :size="12" /> Spouse / Partner</b>
        <button v-if="spouseSummary" type="button" class="spouse-detail-link" @click="$emit('open-spouse', spouseSummary.patient_id)">
          <div><b>{{ spouseSummary.full_name }}</b><span>{{ spouseSummary.patient_id }} · {{ spouseSummary.sex || 'Sex not recorded' }} · {{ spouseSummary.blood_group || 'Blood group not recorded' }}</span></div>
          <span class="link">View patient details <Icon name="chevron-right" :size="12" /></span>
        </button>
        <div v-else class="grid grid-3" style="margin-top:8px; gap:10px;">
          <div><div class="muted" style="font-size:10.5px;">NAME</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.spouse.name || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.spouse.bloodGroup || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">SFA RESULT</div><div style="font-weight:600; font-size:12.5px;">{{ patientRecord.spouse.sfa || 'Not on file' }}</div></div>
        </div>
      </template>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="message" :size="12" /> Past Consultations</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:8px;">
        <p v-if="!consultations.length" class="muted" style="font-size:12px;">No past consultations on file.</p>
        <div v-for="c in consultations" :key="c.id" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm);">
          <div class="flex-between"><b style="font-size:12px;">{{ fmtDate(c.date) }} · {{ c.type }}</b><span class="cell-muted">{{ c.provider_name }}</span></div>
          <p style="font-size:12px; color:var(--text-700); margin-top:6px;">{{ c.notes }}</p>
          <p class="cell-muted" style="margin-top:4px;">Dx: {{ c.diagnosis }}</p>
        </div>
      </div>
      <template v-if="canReadImaging">
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="activity" :size="12" /> Imaging &amp; Ultrasound</b>
        <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
          <p v-if="imagingLoadError" style="font-size:12px; color:var(--red-600);">Imaging history could not be loaded. Other patient information is unaffected.</p>
          <p v-else-if="!imagingStudies.length" class="muted" style="font-size:12px;">No finalized imaging reports on file yet.</p>
          <div v-for="study in imagingStudies" :key="study.id" style="border-bottom:1px solid var(--border);">
            <div class="list-row" style="padding:7px 0; cursor:pointer;" @click="toggleImaging(study.id)">
              <div>
                <div class="main-txt">{{ study.study_type }}</div>
                <div class="sub-txt">{{ fmtDate(study.performed_at) }} · {{ study.approach || 'Approach not recorded' }} · {{ study.interpreted_by_name || study.performed_by_name || 'Clinician not recorded' }}</div>
              </div>
              <div class="flex gap-8" style="align-items:center;">
                <StatusBadge :status="study.status" />
                <Icon :name="expandedImaging.has(study.id) ? 'line' : 'plus'" :size="11" />
              </div>
            </div>
            <div v-if="expandedImaging.has(study.id)" style="padding:0 0 12px;">
              <div v-if="study.indication" class="imaging-block"><b>Clinical indication</b><p>{{ study.indication }}</p></div>
              <div v-if="study.technique" class="imaging-block"><b>Technique</b><p>{{ study.technique }}</p></div>
              <div v-for="section in imagingFindingSections(study)" :key="section.name" class="imaging-block">
                <b>{{ section.name }}</b>
                <table class="data-table" style="margin-top:5px;">
                  <tbody>
                    <tr v-for="row in section.rows" :key="row.key">
                      <td class="cell-strong" style="width:42%;">{{ row.label }}</td>
                      <td>{{ row.value }}<span v-if="row.unit"> {{ row.unit }}</span></td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <div class="imaging-block"><b>Impression</b><p>{{ study.impression || 'No impression recorded.' }}</p></div>
              <div v-if="study.recommendations" class="imaging-block"><b>Recommendations / follow-up</b><p>{{ study.recommendations }}</p></div>
              <div v-if="study.amendment_reason" class="imaging-block"><b>Reason for amendment</b><p>{{ study.amendment_reason }}</p></div>
              <div v-if="study.image_reference" class="imaging-block"><b>Image / accession reference</b><p class="mono">{{ study.image_reference }}</p></div>
            </div>
          </div>
        </div>
      </template>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="flask" :size="12" /> Past Tests</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!labResults.length" class="muted" style="font-size:12px;">No lab results on file yet.</p>
        <div v-for="r in labResults" :key="r.id" style="border-bottom:1px solid var(--border);">
          <div class="list-row" style="padding:6px 0; cursor:pointer;" @click="toggleExpanded(r.id)">
            <div><div class="main-txt">{{ r.lab_templates?.name || r.title || 'External Upload' }}</div><div class="sub-txt">{{ fmtDate(r.collected_on) }}</div></div>
            <div class="flex gap-8" style="align-items:center;">
              <Badge v-if="flaggedCount(r) > 0" tone="red">⚠ {{ flaggedCount(r) }} abnormal</Badge>
              <Icon v-if="recordedResultRows(r).length" :name="expanded.has(r.id) ? 'line' : 'plus'" :size="11" />
            </div>
          </div>
          <table v-if="expanded.has(r.id) && recordedResultRows(r).length" class="data-table" style="margin-bottom:8px;">
            <thead><tr><th>Parameter</th><th>Value</th><th>Ref. Range</th></tr></thead>
            <tbody>
              <tr v-for="(v, i) in recordedResultRows(r)" :key="i">
                <td class="cell-strong">{{ v.param }}</td>
                <td :style="{ color: v.flag ? 'var(--red-600)' : 'var(--text-900)', fontWeight: v.flag ? 700 : 500 }">{{ v.value }} {{ v.unit }} {{ v.flag ? '⚠' : '' }}</td>
                <td class="cell-muted">{{ v.ref }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else-if="expanded.has(r.id) && r.remarks" class="cell-muted" style="padding:0 0 8px;">{{ r.remarks }}</p>
        </div>
      </div>
    </template>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button>
      <button v-if="caps.allowExternalUpload" class="btn btn-secondary" @click="$emit('upload-external')"><Icon name="upload" :size="13" /> Upload External Result</button>
      <button v-if="caps.allowConsultation" class="btn btn-primary" @click="$emit('start-consultation')"><Icon name="clipboard" :size="13" /> Start Consultation</button>
      <button v-if="caps.allowVitals" class="btn btn-secondary" @click="$emit('record-vitals')"><Icon name="activity" :size="13" /> Record Vitals</button>
      <button v-if="caps.allowVisitDoc" class="btn btn-primary" @click="$emit('go-to-visit')"><Icon name="clipboard" :size="13" /> Go to Visit Documentation</button>
      <button v-if="caps.allowLabEntry" class="btn btn-primary" @click="$emit('enter-lab-result')"><Icon name="flask" :size="13" /> Enter Lab Result</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'
import { resolveCycleManagerNames } from '~/composables/useCycleManagerNames'
import { useProfile } from '~/composables/useAuth'
import { fetchImagingHistory, type ImagingStudy, type ImagingTemplateField } from '~/composables/useImagingWorkspace'
import { fetchPatientPhotoUrl } from '~/composables/usePatientPhoto'

const props = defineProps<{
  modelValue: boolean
  patient: any | null
  cycle: any | null
  consultations: any[]
  labResults: any[]
  caps: { allowConsultation?: boolean; allowVisitDoc?: boolean; allowVitals?: boolean; allowLabEntry?: boolean; allowExternalUpload?: boolean }
}>()
defineEmits<{ 'update:modelValue': [boolean]; 'upload-external': []; 'start-consultation': []; 'go-to-visit': []; 'record-vitals': []; 'enter-lab-result': []; 'open-spouse': [string] }>()

const expanded = ref<Set<string>>(new Set())
function toggleExpanded(id: string) {
  const next = new Set(expanded.value)
  next.has(id) ? next.delete(id) : next.add(id)
  expanded.value = next
}
function flaggedCount(result: any) {
  return recordedResultRows(result).filter((value: any) => value.flag).length
}
function recordedResultRows(result: any) {
  if (!Array.isArray(result?.values)) return []
  return result.values.filter((entry: any) => {
    const value = entry?.value
    if (value === null || value === undefined) return false
    const normalized = String(value).trim()
    return normalized !== '' && normalized !== '—'
  })
}

// Resolved here rather than requiring every caller to embed
// cycle_manager:cycle_manager_id(...) on their own `cycle` fetch — some did,
// some didn't, which is exactly the kind of inconsistency that made this
// look "assigned" on one screen and "Unassigned" on another. `cycle` only
// needs the plain cycle_manager_id scalar (part of any `select('*')`).
const supabase = useSupabaseClient()
const profile = useProfile()
const patientBio = ref<any>(null)
const spouseSummary = ref<any>(null)
const patientPhotoUrl = ref('')
const patientRecord = computed(() => props.patient ? { ...props.patient, ...(patientBio.value || {}) } : null)
const nurseVisits = ref<any[]>([])
const staffNames = ref<Map<string, string>>(new Map())
const assignedDoctorName = computed(() => {
  const id = patientRecord.value?.assigned_doctor_id
  return id ? staffNames.value.get(id) || '' : ''
})
const latestNurseVisit = computed(() => nurseVisits.value[0] || null)
const canReadImaging = computed(() => [
  'admin_manager', 'doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech',
].includes(profile.value?.role || ''))
const cycleManagerName = ref('')
watch(
  () => props.cycle?.cycle_manager_id,
  async (id) => {
    cycleManagerName.value = id ? (await resolveCycleManagerNames(supabase, [id])).get(id) || '' : ''
  },
  { immediate: true }
)

// Surgery and transfer/cryo events are patient-scoped, not cycle-scoped
// (a patient can have surgical history outside any active cycle), so these
// fetch off patient_id directly rather than depending on `cycle` being
// present. Self-contained here for the same reason cycleManagerName is:
// every caller of this modal (5+ pages) would otherwise need its own copy
// of this fetch, and RLS already scopes what each role can actually see —
// a role without access to one of these tables just gets an empty list
// back, no error, so this is safe to always attempt.
const surgeries = ref<any[]>([])
const transferCryoEvents = ref<any[]>([])
const cryoStoredCount = ref(0)
const imagingStudies = ref<ImagingStudy[]>([])
const imagingLoadError = ref(false)
const expandedImaging = ref<Set<string>>(new Set())
watch(
  () => props.patient?.patient_id,
  async (patientId) => {
    if (!patientId) {
      patientBio.value = null
      spouseSummary.value = null
      patientPhotoUrl.value = ''
      nurseVisits.value = []
      staffNames.value = new Map()
      surgeries.value = []
      transferCryoEvents.value = []
      cryoStoredCount.value = 0
      imagingStudies.value = []
      imagingLoadError.value = false
      expandedImaging.value = new Set()
      return
    }
    imagingLoadError.value = false
    expandedImaging.value = new Set()
    const imagingPromise = canReadImaging.value
      ? fetchImagingHistory(supabase, patientId).catch(() => {
          imagingLoadError.value = true
          return [] as ImagingStudy[]
        })
      : Promise.resolve([] as ImagingStudy[])
    const [bioRes, nurseVisitRes, surgeryRes, transferRes, cryoRes, imagingRes, spouseRes, photoUrl] = await Promise.all([
      supabase.from('bio_details').select('*').eq('patient_id', patientId).maybeSingle(),
      supabase.from('nurse_visits').select('*').eq('patient_id', patientId).order('created_at', { ascending: false }).limit(8),
      supabase.from('surgery_schedule').select('*').eq('patient_id', patientId).order('date', { ascending: false }),
      supabase.from('transfer_cryo_schedule').select('*').eq('patient_id', patientId).order('scheduled_date', { ascending: false }),
      supabase.from('cryo_records').select('straws').eq('patient_id', patientId).eq('asset_type', 'Embryo').eq('status', 'Stored'),
      imagingPromise,
      supabase.rpc('patient_spouse_summary', { p_patient_id: patientId }),
      fetchPatientPhotoUrl(supabase, patientId),
    ])
    patientBio.value = bioRes.data || null
    spouseSummary.value = spouseRes.data || null
    patientPhotoUrl.value = photoUrl
    nurseVisits.value = nurseVisitRes.data || []
    staffNames.value = await resolveCycleManagerNames(supabase, [
      patientBio.value?.assigned_doctor_id,
      ...nurseVisits.value.map((visit) => visit.documented_by),
    ])
    surgeries.value = surgeryRes.data || []
    transferCryoEvents.value = transferRes.data || []
    cryoStoredCount.value = (cryoRes.data || []).reduce((sum: number, r: any) => sum + (r.straws || 0), 0)
    imagingStudies.value = imagingRes
  },
  { immediate: true }
)
const embryosTransferredTotal = computed(() =>
  transferCryoEvents.value.filter((e) => e.status === 'Done' && e.embryos_used != null).reduce((sum, e) => sum + e.embryos_used, 0)
)

function toggleImaging(id: string) {
  const next = new Set(expandedImaging.value)
  next.has(id) ? next.delete(id) : next.add(id)
  expandedImaging.value = next
}

function imagingFindingSections(study: ImagingStudy) {
  const groups = new Map<string, ImagingTemplateField[]>()
  for (const field of study.template_fields || []) {
    if (isEmptyImagingFinding(study.findings?.[field.key])) continue
    const group = groups.get(field.section) || []
    group.push(field)
    groups.set(field.section, group)
  }
  return [...groups.entries()].map(([name, fields]) => ({
    name,
    rows: fields.map(field => ({
      key: field.key,
      label: field.label,
      unit: field.unit,
      value: formatImagingFinding(study.findings[field.key]),
    })),
  }))
}

function isEmptyImagingFinding(value: unknown) {
  return value === undefined || value === null || value === ''
}

function formatImagingFinding(value: string | number | boolean | null | undefined) {
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  return value == null || value === '' ? '—' : String(value)
}

function withUnit(value: unknown, unit: string) {
  return value === null || value === undefined || value === '' ? '—' : `${value} ${unit}`
}

function bloodPressure(visit: any) {
  return visit.bp_systolic != null && visit.bp_diastolic != null ? `${visit.bp_systolic}/${visit.bp_diastolic} mmHg` : '—'
}

function visitBmi(visit: any) {
  const height = Number(visit.height_cm)
  const weight = Number(visit.weight_kg)
  return height && weight ? (weight / (height / 100) ** 2).toFixed(1) : '—'
}

function nurseName(id: string | null | undefined) {
  return id ? staffNames.value.get(id) || 'Nursing staff' : 'Nursing staff'
}

function compactVitalSummary(visit: any) {
  return [bloodPressure(visit), withUnit(visit.pulse_bpm, 'bpm'), withUnit(visit.respiratory_rate_bpm, '/min'), withUnit(visit.temperature_c, '°C'), withUnit(visit.spo2_pct, '%'), withUnit(visit.weight_kg, 'kg')].filter((value) => value !== '—').join(' · ') || 'No numeric observations recorded.'
}

function reproductiveSummary(intake: Record<string, any>) {
  const parts = [
    intake.trying_to_conceive_months != null ? `Trying ${intake.trying_to_conceive_months} months` : '',
    intake.prior_fertility_treatment && intake.prior_fertility_treatment !== 'Not asked' ? `Prior treatment: ${intake.prior_fertility_treatment}` : '',
    intake.lmp_date ? `LMP ${fmtDate(intake.lmp_date)}` : '',
    intake.cycle_day != null ? `Cycle day ${intake.cycle_day}` : '',
    intake.pregnancy_status && intake.pregnancy_status !== 'Not applicable' ? `Pregnancy: ${intake.pregnancy_status}` : '',
    intake.gravida != null ? `Pregnancies ${intake.gravida}` : '',
    intake.parity != null ? `Live births ${intake.parity}` : '',
    intake.androgen_use && !['Not asked', 'Not applicable'].includes(intake.androgen_use) ? `Androgen use: ${intake.androgen_use}` : '',
    intake.male_fertility_history || '',
    intake.notes || '',
  ].filter(Boolean)
  return parts.join(' · ') || 'No additional reproductive details recorded.'
}

function medicalSummary(intake: Record<string, any>) {
  const parts = [
    intake.allergies_reported ? `Allergies: ${intake.allergies_reported}` : '',
    intake.chronic_conditions_reported ? `Conditions: ${intake.chronic_conditions_reported}` : '',
    intake.current_medications ? `Medicines: ${intake.current_medications}` : '',
    intake.smoking_status && intake.smoking_status !== 'Not asked' ? `Smoking: ${intake.smoking_status}` : '',
    intake.alcohol_use && intake.alcohol_use !== 'Not asked' ? `Alcohol: ${intake.alcohol_use}` : '',
  ].filter(Boolean)
  return parts.join(' · ') || 'No additional medical intake recorded.'
}

function formatPastSurgeries(items: any[]) {
  return items.map((item) => typeof item === 'string' ? item : item?.procedure || item?.name || JSON.stringify(item)).join(' · ')
}
</script>

<style scoped>
.imaging-block { margin-top:10px; }
.patient-photo-hero { display:flex; align-items:center; gap:15px; margin-bottom:14px; }
.patient-photo { width:72px; height:72px; flex:0 0 72px; overflow:hidden; border:3px solid #fff; border-radius:50%; background:#fff; box-shadow:0 0 0 1px var(--border); }
.patient-photo img { width:100%; height:100%; object-fit:cover; }
.patient-hero-facts { flex:1; gap:10px; }
.imaging-block > b { font-size:11.5px; }
.imaging-block > p { margin-top:4px; white-space:pre-wrap; font-size:12px; color:var(--text-700); }
.registration-strip { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:8px; padding:10px 12px; border-radius:var(--radius-sm); background:var(--bg); }
.registration-strip div, .vitals-grid div { display:flex; flex-direction:column; gap:3px; }
.registration-strip span, .vitals-grid span { color:var(--text-500); font-size:9.5px; text-transform:uppercase; }
.registration-strip b, .vitals-grid b { font-size:11.5px; }
.vitals-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:8px; }
.vitals-grid div { padding:8px 9px; border:1px solid var(--border); border-radius:7px; }
.intake-box { margin-top:8px; padding:9px 10px; border-radius:7px; background:var(--blue-50); }
.intake-box b, .clinical-copy b { font-size:11px; }.intake-box p, .clinical-copy { margin-top:4px; color:var(--text-700); font-size:11.5px; line-height:1.45; white-space:pre-wrap; }
.visit-history-item { margin-top:8px; padding:8px 10px; border:1px solid var(--border); border-radius:7px; }
.visit-history-item summary { display:flex; align-items:center; justify-content:space-between; gap:8px; cursor:pointer; color:var(--text-700); font-size:11.5px; font-weight:650; }
.visit-history-item p { margin-top:6px; color:var(--text-700); font-size:11.5px; line-height:1.45; white-space:pre-wrap; }
.spouse-detail-link { display:flex; align-items:center; justify-content:space-between; gap:12px; width:100%; margin-top:8px; padding:10px 12px; border:1px solid var(--blue-100); border-radius:var(--radius-sm); background:var(--blue-50); text-align:left; font-family:inherit; }
.spouse-detail-link b, .spouse-detail-link span { display:block; }
.spouse-detail-link b { font-size:12.5px; }
.spouse-detail-link > div > span { margin-top:3px; color:var(--text-500); font-size:10.5px; }
.spouse-detail-link > .link { display:flex; align-items:center; gap:4px; color:var(--blue-600); font-size:11px; font-weight:700; white-space:nowrap; }
@media (max-width:700px) { .patient-photo-hero { align-items:flex-start; }.patient-hero-facts { grid-template-columns:repeat(2,minmax(0,1fr)); }.registration-strip { grid-template-columns:repeat(2,minmax(0,1fr)); }.vitals-grid { grid-template-columns:repeat(2,minmax(0,1fr)); } }
</style>
