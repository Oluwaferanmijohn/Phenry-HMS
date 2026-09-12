<template>
  <div class="card appointments-card">
    <div class="card-header">
      <h3><Icon name="calendar" :size="15" /> Today's Appointments</h3>
      <Badge :tone="waitingCount ? 'amber' : 'green'">{{ waitingCount }} waiting</Badge>
    </div>
    <div class="card-body tight">
      <div v-if="loading" class="queue-message">Loading today's patient queue…</div>
      <div v-else-if="errorMessage" class="queue-message queue-error">{{ errorMessage }}</div>
      <div v-else-if="!appointments.length" style="padding:18px;"><EmptyState icon="calendar" title="No appointments today" description="Patients booked for today will appear here automatically." /></div>
      <div v-for="appointment in appointments" :key="appointment.id" class="list-row">
        <div class="queue-time">{{ formatTime12(appointment.time) }}</div>
        <Avatar :name="appointment.patient_name" :size="30" />
        <div><div class="main-txt">{{ appointment.patient_name }}</div><div class="sub-txt">{{ appointment.type || 'Clinical appointment' }} · {{ appointment.patient_id }}</div></div>
        <div class="side flex gap-8">
          <StatusBadge :status="appointment.status" />
          <NuxtLink :to="actionPath(appointment.patient_id)" class="btn btn-primary btn-sm">{{ actionLabel }}</NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatTime12 } from '~/composables/useFormat'
const props = defineProps<{ role: 'nurse' | 'matron'; limit?: number }>()
const supabase = useSupabaseClient(); const appointments = ref<any[]>([]); const loading = ref(true); const errorMessage = ref('')
const today = (() => { const now = new Date(); return `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}` })()
const waitingCount = computed(() => appointments.value.filter((row) => ['Waiting', 'Confirmed', 'Scheduled'].includes(row.status)).length)
const actionLabel = computed(() => props.role === 'nurse' ? 'Open vitals' : 'Open consult')
function actionPath(patientId: string) { return props.role === 'nurse' ? `/nurse/vitals?patient=${patientId}` : `/matron/consultation?patient=${patientId}` }
await useAsyncData(`${props.role}-today-appointments`, async () => {
  loading.value = true
  const { data, error } = await supabase.from('appointments').select('id,patient_id,date,time,type,status,patient_names(full_name)').eq('date', today).order('time', { ascending: true }).limit(props.limit || 12)
  loading.value = false
  if (error) { errorMessage.value = 'Today’s appointment queue could not be loaded.'; return false }
  appointments.value = (data || []).map((row: any) => ({ ...row, patient_name: row.patient_names?.full_name || 'Unknown patient' }))
  return true
})
</script>
<style scoped>.queue-message{padding:18px;color:var(--text-500);font-size:12px}.queue-error{color:var(--red-600)}.queue-time{width:58px;flex:0 0 58px;font-size:12px;font-weight:750}@media(max-width:650px){.list-row{align-items:flex-start;flex-wrap:wrap}.list-row .side{width:100%;justify-content:flex-end}.queue-time{width:auto;flex-basis:auto}}</style>
