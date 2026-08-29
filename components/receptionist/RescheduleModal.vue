<template>
  <Modal :model-value="modelValue" title="Reschedule Appointment" @update:model-value="$emit('update:modelValue', $event)">
    <p class="muted" style="font-size:12.5px; margin-bottom:14px;" v-if="appointment">
      {{ appointment.patient_name }} · {{ appointment.type }} · currently {{ fmtDate(appointment.date) }} at {{ formatTime12(appointment.time) }}
    </p>
    <div class="form-row">
      <div class="field"><label>New Date</label><input v-model="newDate" class="input" type="date" /></div>
      <div class="field"><label>New Time</label><input v-model="newTime" class="input" type="time" /></div>
    </div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="submitting" @click="submit">Confirm New Time</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; appointment: any | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; rescheduled: [any] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const newDate = ref('')
const newTime = ref('')
const submitting = ref(false)

watch(
  () => props.appointment,
  (a) => {
    if (a) {
      newDate.value = a.date
      newTime.value = String(a.time).slice(0, 5)
    }
  },
  { immediate: true }
)

async function submit() {
  if (!props.appointment) return
  submitting.value = true
  const targetAppointmentId = props.appointment.id
  const targetPatientName = props.appointment.patient_name
  const targetDate = newDate.value
  const targetTime = newTime.value
  await queueOrRun(
    `${targetPatientName}'s visit moved to ${fmtDate(targetDate)} ${formatTime12(targetTime)}`,
    { table: 'appointments', kind: 'update', payload: { date: targetDate, time: targetTime, status: 'Scheduled' }, match: { id: targetAppointmentId } },
    () => { emit('rescheduled', { id: targetAppointmentId, date: targetDate, time: targetTime, status: 'Scheduled' }) }
  )
  submitting.value = false
  emit('update:modelValue', false)
}
</script>
