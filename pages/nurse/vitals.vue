<template>
  <div class="vitals-page">
    <div class="page-header">
      <div><h1>Patient Vitals</h1><div class="desc">Record complete observations and first-line fertility intake for women and men.</div></div>
      <div v-if="patients.length" class="page-actions"><select v-model="patientId" class="input patient-select"><option v-for="item in patients" :key="item.patient_id" :value="item.patient_id">{{ item.full_name }} — {{ item.patient_id }}</option></select></div>
    </div>

    <div v-if="loading" class="card card-pad"><span class="cell-muted">Loading accessible patients…</span></div>
    <div v-else-if="loadError" class="card card-pad"><EmptyState icon="alert" title="Vitals page could not be loaded" :description="loadError" /></div>
    <EmptyState v-else-if="!patients.length" icon="user" title="No patients available" description="A patient must be registered and under active clinical care before nursing observations can be recorded." />

    <div v-else-if="patient" class="vitals-layout">
      <section class="card vitals-form">
        <div class="form-section-head"><div><span class="section-kicker">1 · Core observations</span><h2>Vital signs &amp; measurements</h2></div><Badge tone="blue">{{ patient.sex === 'F' || patient.sex === 'Female' ? 'Female' : patient.sex === 'M' || patient.sex === 'Male' ? 'Male' : 'General' }} intake</Badge></div>
        <div class="form-grid-3">
          <div class="field"><label>BP systolic (mmHg)</label><input v-model="form.bpSystolic" class="input" type="number" min="40" max="300" placeholder="120" /></div>
          <div class="field"><label>BP diastolic (mmHg)</label><input v-model="form.bpDiastolic" class="input" type="number" min="20" max="200" placeholder="80" /></div>
          <div class="field"><label>Pulse (bpm)</label><input v-model="form.pulse" class="input" type="number" min="20" max="250" placeholder="76" /></div>
          <div class="field"><label>Respiratory rate (/min)</label><input v-model="form.respiratoryRate" class="input" type="number" min="1" max="100" placeholder="16" /></div>
          <div class="field"><label>Temperature (°C)</label><input v-model="form.temperature" class="input" type="number" min="30" max="45" step="0.1" placeholder="36.8" /></div>
          <div class="field"><label>SpO₂ (%)</label><input v-model="form.spo2" class="input" type="number" min="50" max="100" placeholder="98" /></div>
          <div class="field"><label>Height (cm)</label><input v-model="form.height" class="input" type="number" min="40" max="260" step="0.1" placeholder="165" /></div>
          <div class="field"><label>Weight (kg)</label><input v-model="form.weight" class="input" type="number" min="2" max="500" step="0.1" placeholder="62" /></div>
          <div class="field"><label>BMI</label><div class="derived-value">{{ bmi || 'Calculated automatically' }}</div></div>
          <div class="field"><label>Waist circumference (cm)</label><input v-model="form.waist" class="input" type="number" min="20" max="250" step="0.1" /></div>
          <div class="field"><label>Pain score (0–10)</label><input v-model="form.painScore" class="input" type="number" min="0" max="10" /></div>
          <div class="field"><label>Random blood glucose (mmol/L)</label><input v-model="form.bloodGlucose" class="input" type="number" min="0" max="60" step="0.1" /></div>
        </div>

        <hr class="hr" />
        <div class="form-section-head"><div><span class="section-kicker">2 · Visit context</span><h2>Triage &amp; medical intake</h2></div></div>
        <div class="form-row"><div class="field"><label>Visit type</label><select v-model="form.visitType" class="input"><option>Initial fertility intake</option><option>Cycle monitoring</option><option>Procedure visit</option><option>Follow-up</option><option>General clinical visit</option><option>Emergency / urgent review</option></select></div><div class="field"><label>General condition</label><select v-model="form.condition" class="input"><option>Stable</option><option>Needs Review</option></select></div></div>
        <div class="field"><label>Chief complaint / reason for visit</label><textarea v-model="form.chiefComplaint" class="input" rows="2" placeholder="Patient's main concern in their own words…" /></div>
        <div class="form-row"><div class="field"><label>Known allergies reported today</label><input v-model="form.allergies" class="input" placeholder="Medicines, latex, food, or none known" /></div><div class="field"><label>Chronic conditions reported</label><input v-model="form.conditions" class="input" placeholder="Hypertension, diabetes, asthma…" /></div></div>
        <div class="field"><label>Current medicines and supplements</label><textarea v-model="form.currentMedications" class="input" rows="2" placeholder="Name, dose, route, and frequency where known…" /></div>
        <div class="form-row"><div class="field"><label>Smoking / nicotine</label><select v-model="form.smoking" class="input"><option>Not asked</option><option>Never</option><option>Former</option><option>Current</option></select></div><div class="field"><label>Alcohol use</label><select v-model="form.alcohol" class="input"><option>Not asked</option><option>None</option><option>Occasional</option><option>Regular</option></select></div></div>

        <hr class="hr" />
        <div class="form-section-head"><div><span class="section-kicker">3 · Fertility context</span><h2>Reproductive intake</h2></div><span class="cell-muted">Reported history—not a diagnosis</span></div>
        <div class="form-row"><div class="field"><label>Trying to conceive for (months)</label><input v-model="form.tryingMonths" class="input" type="number" min="0" max="600" /></div><div class="field"><label>Previous fertility treatment</label><select v-model="form.priorTreatment" class="input"><option>Not asked</option><option>None</option><option>Ovulation induction</option><option>IUI</option><option>IVF / ICSI</option><option>Other</option></select></div></div>
        <template v-if="isFemale">
          <div class="form-grid-3"><div class="field"><label>Last menstrual period</label><input v-model="form.lmpDate" class="input" type="date" /></div><div class="field"><label>Current cycle day</label><input v-model="form.cycleDay" class="input" type="number" min="1" max="120" /></div><div class="field"><label>Pregnancy status</label><select v-model="form.pregnancyStatus" class="input"><option>Unknown / not tested</option><option>Not pregnant</option><option>Possible pregnancy</option><option>Confirmed pregnancy</option></select></div><div class="field"><label>Previous pregnancies</label><input v-model="form.gravida" class="input" type="number" min="0" max="30" /></div><div class="field"><label>Live births</label><input v-model="form.parity" class="input" type="number" min="0" max="30" /></div></div>
        </template>
        <template v-else-if="isMale">
          <div class="form-row"><div class="field"><label>Previous conception / fertility history</label><textarea v-model="form.maleFertilityHistory" class="input" rows="2" placeholder="Prior conceptions, semen analysis, surgery, infection, or treatment…" /></div><div class="field"><label>Current testosterone / anabolic steroid use</label><select v-model="form.androgenUse" class="input"><option>Not asked</option><option>No</option><option>Yes</option><option>Previously used</option></select></div></div>
        </template>
        <div class="field"><label>Additional reproductive history</label><textarea v-model="form.reproductiveNotes" class="input" rows="3" placeholder="Cycle pattern, prior outcomes, relevant surgery, treatment history, or partner context…" /></div>
        <div class="field"><label>Nursing observations / escalation notes</label><textarea v-model="form.notes" class="input" rows="3" placeholder="Appearance, alertness, mobility, symptoms, precautions, or clinician escalation…" /></div>

        <div class="form-actions"><button class="btn btn-secondary" @click="resetForm">Clear</button><button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save vitals to patient record</button></div>
      </section>

      <aside class="card patient-context">
        <div class="patient-summary"><Avatar :name="patient.full_name" :size="48" /><div><b>{{ patient.full_name }}</b><span>{{ patient.patient_id }}</span></div></div>
        <div class="context-grid"><div><small>Age</small><b>{{ computeAge(patient.dob) }}</b></div><div><small>Sex</small><b>{{ patient.sex || '—' }}</b></div><div><small>Blood group</small><b>{{ patient.blood_group || '—' }}</b></div><div><small>Status</small><StatusBadge :status="patient.status" /></div></div>
        <hr class="hr" />
        <div class="flex-between"><b style="font-size:12.5px;">Recent observations</b><Badge tone="blue">{{ recentVisits.length }}</Badge></div>
        <div v-if="recentVisits.length" class="recent-list"><div v-for="visit in recentVisits" :key="visit.id" class="recent-item"><div class="flex-between"><b>{{ fmtDate(visit.visit_date) }}</b><StatusBadge :status="visit.condition || 'Recorded'" /></div><p>{{ vitalSummary(visit) }}</p><small>{{ visit.visit_type || 'Nursing observation' }}</small></div></div>
        <p v-else class="empty-copy">No nursing observations recorded yet.</p>
      </aside>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { computeAge, fmtDate } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient(); const profile = useProfile(); const route = useRoute(); const { queueOrRun } = useSyncQueue(); const { toast } = useToast()
const patients = ref<any[]>([]); const patientId = ref(''); const patient = ref<any>(null); const recentVisits = ref<any[]>([]); const loading = ref(true); const loadError = ref(''); const saving = ref(false)
const blank = () => ({ bpSystolic: '', bpDiastolic: '', pulse: '', respiratoryRate: '', temperature: '', spo2: '', height: '', weight: '', waist: '', painScore: '', bloodGlucose: '', visitType: 'Initial fertility intake', condition: 'Stable', chiefComplaint: '', allergies: '', conditions: '', currentMedications: '', smoking: 'Not asked', alcohol: 'Not asked', tryingMonths: '', priorTreatment: 'Not asked', lmpDate: '', cycleDay: '', pregnancyStatus: 'Unknown / not tested', gravida: '', parity: '', maleFertilityHistory: '', androgenUse: 'Not asked', reproductiveNotes: '', notes: '' })
const form = reactive(blank())
const isFemale = computed(() => ['F', 'Female'].includes(patient.value?.sex)); const isMale = computed(() => ['M', 'Male'].includes(patient.value?.sex))
const bmi = computed(() => { const height = Number(form.height), weight = Number(form.weight); return height && weight ? (weight / (height / 100) ** 2).toFixed(1) : '' })
function numberOrNull(value: string) { return value === '' ? null : Number(value) }
function resetForm() { Object.assign(form, blank()) }
function validRange(value: string, min: number, max: number) { return value === '' || (Number.isFinite(Number(value)) && Number(value) >= min && Number(value) <= max) }
function vitalSummary(visit: any) { return [visit.bp_systolic != null && visit.bp_diastolic != null ? `BP ${visit.bp_systolic}/${visit.bp_diastolic}` : '', visit.pulse_bpm != null ? `Pulse ${visit.pulse_bpm}` : '', visit.temperature_c != null ? `${visit.temperature_c}°C` : '', visit.spo2_pct != null ? `SpO₂ ${visit.spo2_pct}%` : '', visit.weight_kg != null ? `${visit.weight_kg} kg` : ''].filter(Boolean).join(' · ') || 'Clinical intake recorded' }

async function loadPatient(id: string) {
  const selected = patients.value.find((item) => item.patient_id === id)
  const [bioResult, visitsResult] = await Promise.all([supabase.from('bio_details').select('*').eq('patient_id', id).maybeSingle(), supabase.from('nurse_visits').select('*').eq('patient_id', id).order('created_at', { ascending: false }).limit(6)])
  if (bioResult.error) throw bioResult.error
  patient.value = { ...selected, ...(bioResult.data || {}) }; recentVisits.value = visitsResult.data || []; resetForm()
}
watch(patientId, (id) => { if (id) void loadPatient(id).catch(() => { loadError.value = 'Patient details could not be loaded. Check your connection and try again.' }) })

try {
  const { data, error } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }); if (error) throw error
  patients.value = data || []; const requested = typeof route.query.patient === 'string' ? route.query.patient : ''; patientId.value = patients.value.some((item) => item.patient_id === requested) ? requested : patients.value[0]?.patient_id || ''
  if (patientId.value) await loadPatient(patientId.value)
} catch { loadError.value = 'The accessible patient list is temporarily unavailable.' } finally { loading.value = false }

async function save() {
  if (!patient.value || !profile.value) return
  const checks: Array<[string, string, number, number]> = [['Systolic pressure', form.bpSystolic, 40, 300], ['Diastolic pressure', form.bpDiastolic, 20, 200], ['Pulse', form.pulse, 20, 250], ['Respiratory rate', form.respiratoryRate, 1, 100], ['Temperature', form.temperature, 30, 45], ['SpO₂', form.spo2, 50, 100], ['Pain score', form.painScore, 0, 10]]
  const invalid = checks.find(([, value, min, max]) => !validRange(value, min, max)); if (invalid) return toast(`${invalid[0]} is outside the accepted entry range`, 'warn')
  if (![form.bpSystolic, form.bpDiastolic, form.pulse, form.respiratoryRate, form.temperature, form.spo2, form.height, form.weight, form.chiefComplaint, form.notes].some((value) => String(value).trim())) return toast('Enter at least one observation or clinical note', 'warn')
  const record = { id: crypto.randomUUID(), patient_id: patient.value.patient_id, documented_by: profile.value.id, visit_date: new Date().toISOString().slice(0, 10), bp_systolic: numberOrNull(form.bpSystolic), bp_diastolic: numberOrNull(form.bpDiastolic), temperature_c: numberOrNull(form.temperature), pulse_bpm: numberOrNull(form.pulse), respiratory_rate_bpm: numberOrNull(form.respiratoryRate), spo2_pct: numberOrNull(form.spo2), height_cm: numberOrNull(form.height), weight_kg: numberOrNull(form.weight), waist_cm: numberOrNull(form.waist), pain_score: numberOrNull(form.painScore), blood_glucose_mmol_l: numberOrNull(form.bloodGlucose), visit_type: form.visitType, chief_complaint: form.chiefComplaint.trim() || null, condition: form.condition, nursing_notes: form.notes.trim() || null, reproductive_intake: { trying_to_conceive_months: numberOrNull(form.tryingMonths), prior_fertility_treatment: form.priorTreatment, lmp_date: isFemale.value ? form.lmpDate || null : null, cycle_day: isFemale.value ? numberOrNull(form.cycleDay) : null, pregnancy_status: isFemale.value ? form.pregnancyStatus : 'Not applicable', gravida: isFemale.value ? numberOrNull(form.gravida) : null, parity: isFemale.value ? numberOrNull(form.parity) : null, male_fertility_history: isMale.value ? form.maleFertilityHistory.trim() || null : null, androgen_use: isMale.value ? form.androgenUse : 'Not applicable', notes: form.reproductiveNotes.trim() || null }, medical_intake: { allergies_reported: form.allergies.trim() || null, chronic_conditions_reported: form.conditions.trim() || null, current_medications: form.currentMedications.trim() || null, smoking_status: form.smoking, alcohol_use: form.alcohol } }
  saving.value = true
  try { await queueOrRun(`Vitals saved for ${patient.value.full_name}`, { table: 'nurse_visits', kind: 'insert', payload: record }); recentVisits.value = [record, ...recentVisits.value].slice(0, 6); resetForm() } finally { saving.value = false }
}
</script>

<style scoped>
.vitals-page { max-width: 1280px; margin: 0 auto; }.patient-select { min-width: 280px; }.vitals-layout { display: grid; grid-template-columns: minmax(0, 1fr) 300px; gap: 16px; align-items: start; }.vitals-form { padding: 22px 24px; }.form-section-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; margin-bottom: 15px; }.form-section-head h2 { margin-top: 3px; font-size: 16px; }.section-kicker { color: var(--blue-600); font-size: 10px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; }.form-grid-3 { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 12px; }.derived-value { min-height: 36px; display: flex; align-items: center; padding: 8px 11px; border-radius: var(--radius-sm); background: var(--blue-50); color: var(--blue-700); font-size: 12px; font-weight: 700; }.form-actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 20px; padding-top: 16px; border-top: 1px solid var(--border); }.patient-context { padding: 18px; }.patient-summary { display: flex; align-items: center; gap: 11px; }.patient-summary div { display: flex; flex-direction: column; }.patient-summary b { font-size: 13.5px; }.patient-summary span { color: var(--text-500); font-size: 11px; }.context-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 16px; }.context-grid div { display: flex; flex-direction: column; gap: 3px; }.context-grid small { color: var(--text-500); font-size: 10px; text-transform: uppercase; }.context-grid b { font-size: 12px; }.recent-list { display: flex; flex-direction: column; gap: 8px; margin-top: 10px; }.recent-item { padding: 10px; border: 1px solid var(--border); border-radius: 8px; }.recent-item b { font-size: 11.5px; }.recent-item p { margin: 6px 0 3px; color: var(--text-700); font-size: 11px; line-height: 1.45; }.recent-item small, .empty-copy { color: var(--text-500); font-size: 10.5px; }.empty-copy { margin-top: 12px; }
@media (max-width: 950px) { .vitals-layout { grid-template-columns: 1fr; }.patient-context { order: -1; }.form-grid-3 { grid-template-columns: repeat(2, minmax(0, 1fr)); } } @media (max-width: 600px) { .form-grid-3 { grid-template-columns: 1fr; }.vitals-form { padding: 17px; } }
</style>
