<template>
  <div>
    <div class="page-header"><div><h1>My Appointments</h1><div class="desc">Your upcoming schedule.</div></div></div>
    <div class="card">
      <table class="data-table">
        <thead><tr><th>Date</th><th>Time</th><th>Patient</th><th>Type</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="a in appointments" :key="a.id">
            <td class="cell-strong">{{ fmtDate(a.date) }}</td>
            <td class="cell-muted">{{ formatTime12(a.time) }}</td>
            <td>{{ a.patient_name }}</td>
            <td class="cell-muted">{{ a.type }}</td>
            <td><StatusBadge :status="a.status" /></td>
          </tr>
        </tbody>
      </table>
      <div v-if="!appointments.length" style="padding:20px;"><EmptyState icon="calendar" title="Nothing scheduled" description="Your upcoming appointments will appear here." /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const appointments = ref<any[]>([])

await useAsyncData('doctor-appointments', async () => {
  const todayStr = new Date().toISOString().slice(0, 10)
  const { data } = await supabase
    .from('appointments')
    .select('*, patient_names(full_name)')
    .gte('date', todayStr)
    .order('date', { ascending: true })
    .order('time', { ascending: true })
  appointments.value = (data || []).map((a: any) => ({ ...a, patient_name: a.patient_names?.full_name || 'Unknown' }))
  return true
})
</script>
