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
    <div class="grid grid-main-side">
      <div class="card card-pad">
        <div class="form-row">
          <div class="field"><label>Target Patient ID</label><select v-model="patientId" class="input" @change="loadPatient(patientId)"><option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option></select></div>
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
        <div class="flex-between" style="margin-top:14px;">
          <button class="btn btn-secondary" @click="resetForm">Cancel</button>
          <button class="btn btn-primary" :disabled="submitting" @click="save"><Icon name="file" :size="13" /> Save Results &amp; Attach to Patient File</button>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="file" :size="15" /> On File for {{ patient.first_name }}</h3></div>
        <div class="card-body tight">
          <p v-if="!onFile.length" class="muted" style="font-size:12px; padding:16px 20px;">No results on file yet.</p>
          <div v-for="r in onFile" :key="r.id" class="list-row">
            <div><div class="main-txt">{{ r.title || r.lab_templates?.name }}</div><div class="sub-txt">{{ fmtDate(r.collected_on) }} · {{ r.entered_by_name }}</div></div>
            <Badge v-if="r.external" tone="purple">External</Badge>
          </div>
        </div>
      </div>
    </div>
    <ExternalUploadModal v-model="showExternal" :preselected-patient-id="patientId" @uploaded="loadOnFile" />
  </div>
  <div v-else class="card card-pad" style="text-align:center; color:var(--text-500); font-size:13px;">
    Loading…
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const route = useRoute()

const patients = ref<any[]>([])
const templates = ref<any[]>([])
const patient = ref<any>(null)
const template = ref<any>(null)
const patientId = ref('')
const templateId = ref('')
const collectedOn = ref(new Date().toISOString().slice(0, 10))
const values = ref<string[]>([])
const remarks = ref('')
const onFile = ref<any[]>([])
const showExternal = ref(false)
const submitting = ref(false)

async function loadPatient(id: string) {
  const { data } = await supabase.from('patient_names').select('*').eq('patient_id', id).single()
  patient.value = data
  await loadOnFile()
}
async function loadOnFile() {
  const { data } = await supabase.from('lab_results').select('*, lab_templates(name), profiles:entered_by_profile_id(full_name)').eq('patient_id', patientId.value).order('collected_on', { ascending: false })
  onFile.value = (data || []).map((r: any) => ({ ...r, entered_by_name: r.profiles?.full_name || (r.external ? 'External Upload' : 'Staff') }))
}

watch(templateId, (id) => {
  template.value = templates.value.find((t) => t.id === id)
  values.value = template.value ? new Array(template.value.variables.length).fill('') : []
})

await useAsyncData(`lab-results-init-${props.role}`, async () => {
  const [patientsRes, templatesRes] = await Promise.all([
    supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
    supabase.from('lab_templates').select('*').order('name', { ascending: true }),
  ])
  patients.value = patientsRes.data || []
  templates.value = templatesRes.data || []
  patientId.value = (route.query.patient as string) || patients.value[0]?.patient_id || ''
  templateId.value = templates.value[0]?.id || ''
  if (patientId.value) await loadPatient(patientId.value)
  return true
})

function resetForm() {
  remarks.value = ''
  values.value = template.value ? new Array(template.value.variables.length).fill('') : []
}

async function save() {
  if (!template.value || !patient.value) return
  submitting.value = true
  const valuesPayload = template.value.variables.map((v: any, i: number) => ({ param: v.name, value: values.value[i] || '—', unit: v.unit, ref: v.ref, flag: false }))

  await queueOrRun(`${template.value.name} results saved for ${patient.value.full_name}`, async () => {
    const { error } = await supabase.from('lab_results').insert({
      patient_id: patientId.value,
      template_id: templateId.value,
      entered_by_profile_id: profile.value!.id,
      collected_on: collectedOn.value,
      values: valuesPayload,
      remarks: remarks.value,
    })
    if (error) throw error
    await loadOnFile()
  })
  submitting.value = false
  resetForm()
}
</script>