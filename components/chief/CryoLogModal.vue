<template>
  <Modal :model-value="modelValue" :title="record ? 'Edit Cryostorage Record' : 'Store Frozen Specimen'" wide @update:model-value="$emit('update:modelValue', $event)">
    <div class="cryo-form-intro">
      <Icon name="snow" :size="18" />
      <div><b>Exact storage traceability</b><p>Document the specimen, container label, tank, canister, cane, goblet or jar, and final position.</p></div>
    </div>

    <div class="form-row">
      <div class="field">
        <label>Patient</label>
        <select v-model="patientId" class="input" :disabled="!!preselectedPatientId || !!record">
          <option value="">Select patient…</option>
          <option v-for="patient in patients" :key="patient.patient_id" :value="patient.patient_id">{{ patient.full_name }} — {{ patient.patient_id }}</option>
        </select>
      </div>
      <div class="field"><label>Specimen Type</label><select v-model="assetType" class="input"><option>Embryo</option><option>Oocyte</option><option>Sperm</option></select></div>
    </div>

    <div class="form-row">
      <div class="field"><label>Number of Storage Units</label><input v-model.number="units" class="input" type="number" min="1" /></div>
      <div class="field"><label>Storage Unit</label><select v-model="storageUnitType" class="input"><option>Straw</option><option>Vial</option><option>Cryotop</option><option>High-security straw</option><option>Other</option></select></div>
      <div class="field"><label>Specimens per Unit</label><input v-model.number="perUnit" class="input" type="number" min="1" placeholder="Optional" /></div>
    </div>
    <div class="form-row">
      <div class="field"><label>Freezing Date</label><input v-model="freezingDate" class="input" type="date" /></div>
      <div class="field"><label>Freezing / Vitrification Method</label><input v-model="freezeMethod" class="input" placeholder="e.g. Vitrification, slow freezing" /></div>
      <div class="field"><label>Quality / Grade</label><input v-model="specimenQuality" class="input" placeholder="e.g. 4AA, MII, post-thaw motility" /></div>
    </div>

    <div class="storage-location">
      <div class="location-title"><Icon name="target" :size="14" /><b>Storage Location</b><span>All marked fields are required for retrieval safety.</span></div>
      <div class="form-row">
        <div class="field"><label>Tank *</label><select v-model="tankId" class="input"><option value="">Select tank…</option><option v-for="tank in tanks" :key="tank.id" :value="tank.id">{{ tank.name }} — {{ tank.used }}/{{ tank.capacity }} used</option></select></div>
        <div class="field"><label>Canister *</label><input v-model="canister" class="input" placeholder="e.g. C-04" /></div>
        <div class="field"><label>Rack</label><input v-model="rack" class="input" placeholder="e.g. Rack B" /></div>
      </div>
      <div class="form-row">
        <div class="field"><label>Cane *</label><input v-model="cane" class="input" placeholder="e.g. Cane 12" /></div>
        <div class="field"><label>Goblet / Jar *</label><input v-model="goblet" class="input" placeholder="e.g. Goblet G-7" /></div>
        <div class="field"><label>Position *</label><input v-model="position" class="input" placeholder="e.g. Slot 4 / Level 2" /></div>
      </div>
      <div class="field"><label>Container / Specimen Label *</label><input v-model="containerLabel" class="input mono" placeholder="Exact label printed on the straw, vial, Cryotop, or jar" /></div>
    </div>

    <div class="form-row">
      <div class="field"><label>Witnessed By</label><select v-model="witnessedBy" class="input"><option value="">Not recorded</option><option v-for="staff in labStaff" :key="staff.id" :value="staff.id">{{ staff.full_name }}</option></select></div>
      <div class="field"><label>Notes</label><textarea v-model="notes" class="input" rows="2" placeholder="Consent, freezing observations, or special handling instructions" /></div>
    </div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="submitting" @click="submit"><Icon name="snow" :size="13" /> {{ submitting ? 'Saving…' : record ? 'Update Location' : 'Store Specimen' }}</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const props = defineProps<{
  modelValue: boolean
  tanks: any[]
  record?: any | null
  preselectedPatientId?: string
  sourceProcedureId?: string
  defaultAssetType?: 'Embryo' | 'Oocyte' | 'Sperm'
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; logged: [] }>()
const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()

const patients = ref<any[]>([])
const labStaff = ref<any[]>([])
const patientId = ref('')
const assetType = ref<'Embryo' | 'Oocyte' | 'Sperm'>('Embryo')
const units = ref<number | string>(1)
const perUnit = ref<number | string>('')
const storageUnitType = ref('Straw')
const freezingDate = ref(new Date().toISOString().slice(0, 10))
const tankId = ref('')
const canister = ref('')
const rack = ref('')
const cane = ref('')
const goblet = ref('')
const position = ref('')
const containerLabel = ref('')
const freezeMethod = ref('')
const specimenQuality = ref('')
const witnessedBy = ref('')
const notes = ref('')
const submitting = ref(false)

function resetFromRecord() {
  const record = props.record
  patientId.value = props.preselectedPatientId || record?.patient_id || patients.value[0]?.patient_id || ''
  assetType.value = props.defaultAssetType || record?.asset_type || 'Embryo'
  units.value = record?.straws ?? 1
  perUnit.value = record?.per_straw ?? ''
  storageUnitType.value = record?.storage_unit_type || 'Straw'
  freezingDate.value = record?.freezing_date || new Date().toISOString().slice(0, 10)
  tankId.value = record?.tank_id || ''
  canister.value = record?.canister || ''
  rack.value = record?.rack || ''
  cane.value = record?.cane || ''
  goblet.value = record?.goblet || ''
  position.value = record?.position || ''
  containerLabel.value = record?.container_label || ''
  freezeMethod.value = record?.freeze_method || ''
  specimenQuality.value = record?.specimen_quality || ''
  witnessedBy.value = record?.witnessed_by || ''
  notes.value = record?.notes || ''
}

watch(
  () => [props.modelValue, props.record?.id, props.preselectedPatientId],
  async ([open]) => {
    if (!open) return
    if (!patients.value.length || !labStaff.value.length) {
      const [patientRes, staffRes] = await Promise.all([
        supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
        supabase.from('profiles').select('id, full_name').in('role', ['chief_embryologist', 'lab_tech']).eq('active', true).order('full_name'),
      ])
      patients.value = patientRes.data || []
      labStaff.value = staffRes.data || []
    }
    resetFromRecord()
  },
  { immediate: true },
)

async function submit() {
  if (!patientId.value) return toast('Select the patient.', 'warn')
  if (!tankId.value || !canister.value.trim() || !cane.value.trim() || !goblet.value.trim() || !position.value.trim() || !containerLabel.value.trim()) {
    return toast('Tank, canister, cane, goblet/jar, position, and container label are required.', 'warn')
  }
  if (Number(units.value) < 1) return toast('Enter at least one storage unit.', 'warn')

  submitting.value = true
  try {
    await queueOrRun(`${assetType.value} cryostorage record saved`, {
      kind: 'rpc',
      rpcName: 'save_cryo_specimen',
      payload: {
        p_patient_id: patientId.value,
        p_asset_type: assetType.value,
        p_units: Number(units.value),
        p_per_unit: perUnit.value === '' ? null : Number(perUnit.value),
        p_freezing_date: freezingDate.value,
        p_tank_id: tankId.value,
        p_canister: canister.value,
        p_rack: rack.value,
        p_cane: cane.value,
        p_goblet: goblet.value,
        p_position: position.value,
        p_container_label: containerLabel.value,
        p_storage_unit_type: storageUnitType.value,
        p_freeze_method: freezeMethod.value,
        p_specimen_quality: specimenQuality.value,
        p_source_procedure_id: props.sourceProcedureId || props.record?.source_procedure_id || null,
        p_witnessed_by: witnessedBy.value || null,
        p_notes: notes.value,
        p_record_id: props.record?.id || null,
      },
    }, () => emit('logged'))
    emit('update:modelValue', false)
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.cryo-form-intro { display:flex; align-items:flex-start; gap:10px; margin-bottom:14px; padding:11px 12px; border-radius:var(--radius-sm); background:var(--blue-50); color:var(--blue-700); }
.cryo-form-intro b { font-size:12.5px; }.cryo-form-intro p { margin-top:3px; font-size:11px; color:var(--text-600); }
.storage-location { margin:4px 0 13px; padding:14px; border:1px solid var(--blue-100); border-radius:var(--radius-sm); background:var(--bg); }
.location-title { display:flex; align-items:center; gap:7px; margin-bottom:11px; }.location-title b { font-size:12.5px; }.location-title span { color:var(--text-500); font-size:10.5px; }
</style>
