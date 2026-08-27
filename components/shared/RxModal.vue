<template>
  <Modal :model-value="modelValue" title="Add Medication" @update:model-value="$emit('update:modelValue', $event)">
    <div class="field"><label>Medication</label><input v-model="med" class="input" placeholder="e.g. Ovidrel 250mcg" /></div>
    <div class="field"><label>Sig / Dosage Instructions</label><input v-model="sig" class="input" placeholder="e.g. 1 syringe SubQ tonight" /></div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="!med || submitting" @click="submit"><Icon name="upload" :size="13" /> e-Prescribe to Pharmacy</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ modelValue: boolean; patientId: string; patientName: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; added: [any] }>()

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const med = ref('')
const sig = ref('')
const submitting = ref(false)

async function submit() {
  submitting.value = true
  const targetPatientId = props.patientId
  const targetPatientName = props.patientName
  const prescribedByProfileId = profile.value!.id
  const prescribedByRole = profile.value!.role
  const targetMed = med.value || 'Medication'
  const targetSig = sig.value || 'As directed'
  await queueOrRun(`Prescription sent to pharmacy for ${targetPatientName}`, async () => {
    const { data, error } = await supabase
      .from('prescriptions')
      .insert({
        patient_id: targetPatientId,
        prescribed_by_profile_id: prescribedByProfileId,
        prescribed_by_role: prescribedByRole,
        medication: targetMed,
        sig: targetSig,
      })
      .select()
      .single()
    if (error) throw error
    emit('added', data)
  })
  submitting.value = false
  med.value = ''
  sig.value = ''
  emit('update:modelValue', false)
}
</script>
