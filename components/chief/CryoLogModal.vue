<template>
  <Modal :model-value="modelValue" title="Log Cryopreservation Record" @update:model-value="$emit('update:modelValue', $event)">
    <div class="field">
      <label>Patient</label>
      <select v-model="patientId" class="input"><option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option></select>
    </div>
    <div class="form-row">
      <div class="field"><label>Asset Type</label><select v-model="assetType" class="input"><option>Embryo</option><option>Oocyte</option><option>Sperm</option></select></div>
      <div class="field"><label>Number of Straws</label><input v-model.number="straws" class="input" type="number" /></div>
    </div>
    <div class="form-row">
      <div class="field"><label>Freezing Date</label><input v-model="freezingDate" class="input" type="date" /></div>
      <div class="field"><label>Storage Tank</label><select v-model="tankId" class="input"><option value="">Select tank…</option><option v-for="t in tanks" :key="t.id" :value="t.id">{{ t.name }}</option></select></div>
    </div>
    <div class="form-row">
      <div class="field"><label>Canister</label><input v-model="canister" class="input" placeholder="e.g. C-4" /></div>
      <div class="field"><label>Position</label><input v-model="position" class="input" placeholder="e.g. 4-1" /></div>
    </div>
    <div class="field"><label>Notes</label><textarea v-model="notes" class="input" rows="2" /></div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="!patientId || submitting" @click="submit"><Icon name="snow" :size="13" /> Log Record</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ modelValue: boolean; tanks: any[] }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; logged: [] }>()

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const patients = ref<any[]>([])
const patientId = ref('')
const assetType = ref('Embryo')
const straws = ref(1)
const freezingDate = ref(new Date().toISOString().slice(0, 10))
const tankId = ref('')
const canister = ref('')
const position = ref('')
const notes = ref('')
const submitting = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open || patients.value.length) return
    const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
    patients.value = data || []
    patientId.value = patients.value[0]?.patient_id || ''
  }
)

async function submit() {
  if (!patientId.value) return
  submitting.value = true
  const targetPatientId = patientId.value
  const targetAssetType = assetType.value
  const targetStraws = straws.value
  const targetFreezingDate = freezingDate.value
  const targetTankId = tankId.value || null
  const targetCanister = canister.value
  const targetPosition = position.value
  const targetNotes = notes.value
  const loggedBy = profile.value!.id
  const targetTank = targetTankId ? props.tanks.find((t) => t.id === targetTankId) : null
  await queueOrRun('Cryo record logged', [
    {
      table: 'cryo_records',
      kind: 'insert',
      payload: {
        patient_id: targetPatientId,
        asset_type: targetAssetType,
        straws: targetStraws,
        freezing_date: targetFreezingDate,
        tank_id: targetTankId,
        canister: targetCanister,
        position: targetPosition,
        notes: targetNotes,
        logged_by: loggedBy,
      },
    },
    ...(targetTank ? [{ table: 'cryo_tanks', kind: 'update' as const, payload: { used: targetTank.used + targetStraws }, match: { id: targetTankId } }] : []),
  ])
  submitting.value = false
  emit('logged')
  emit('update:modelValue', false)
}
</script>
