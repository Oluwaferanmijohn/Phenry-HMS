<template>
  <div>
    <div class="page-header">
      <div><h1>Surgery &amp; Procedure Scheduling</h1><div class="desc">Theatre bookings, recovery allocation, and procedure reports.</div></div>
      <div v-if="allowSchedule" class="page-actions"><button class="btn btn-primary" @click="showSchedule = true"><Icon name="plus" :size="14" /> Schedule Procedure</button></div>
    </div>
    <div class="card">
      <table class="data-table">
        <thead><tr><th>Date</th><th>Time</th><th>Patient</th><th>Procedure</th><th>Assigned Provider</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="s in list" :key="s.id">
            <td class="cell-muted">{{ fmtDate(s.date) }}</td>
            <td>{{ formatTime12(s.time) }}</td>
            <td class="cell-strong">{{ s.patient_name }}</td>
            <td class="cell-strong">{{ s.procedure }}</td>
            <td class="cell-muted">{{ s.provider_name || 'Unassigned' }}</td>
            <td><StatusBadge :status="s.status" /></td>
            <td style="text-align:right;"><button class="btn btn-secondary btn-sm" @click="openReport(s.id)"><Icon name="file" :size="12" /> Procedure Report</button></td>
          </tr>
        </tbody>
      </table>
      <div v-if="!list.length" style="padding:20px;"><EmptyState icon="siren" title="Nothing scheduled" description="Procedures scheduled from Consultation or here will appear on this list." /></div>
    </div>

    <ScheduleProcedureModal v-model="showSchedule" @scheduled="load" />
    <OperativeReportModal v-model="showReportModal" :surgery-id="activeSurgeryId" @saved="load" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'

defineProps<{ allowSchedule?: boolean }>()

const supabase = useSupabaseClient()
const list = ref<any[]>([])
const showSchedule = ref(false)
const showReportModal = ref(false)
const activeSurgeryId = ref('')

async function load() {
  const { data } = await supabase
    .from('surgery_schedule')
    .select('*, patient_names(full_name), profiles:assigned_provider_id(full_name)')
    .order('date', { ascending: true })
    .order('time', { ascending: true })
  list.value = (data || []).map((s: any) => ({ ...s, patient_name: s.patient_names?.full_name || 'Unknown', provider_name: s.profiles?.full_name }))
}
await useAsyncData('surgery-page', load)

function openReport(id: string) {
  activeSurgeryId.value = id
  showReportModal.value = true
}
</script>
