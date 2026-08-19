<template>
  <div>
    <div class="page-header"><div><h1>Master Appointment Schedule</h1><div class="desc">Full clinic calendar, next 3 days</div></div></div>
    <div class="grid" style="grid-template-columns:1fr; gap:16px;">
      <div v-for="day in days" :key="day.dateStr" class="card">
        <div class="card-header"><h3><Icon name="calendar" :size="15" /> {{ day.label }}</h3><Badge tone="blue">{{ day.appts.length }} booked</Badge></div>
        <div class="card-body tight">
          <div v-if="!day.appts.length" style="padding:16px 20px;" class="muted">No appointments booked.</div>
          <div v-for="a in day.appts" :key="a.id" class="list-row">
            <div style="width:60px; flex-shrink:0; font-size:12px; font-weight:700;">{{ formatTime12(a.time) }}</div>
            <div><div class="main-txt">{{ a.patient_name }}</div><div class="sub-txt">{{ a.type }} · {{ a.room || 'Room TBC' }}</div></div>
            <div class="side flex gap-8">
              <StatusBadge :status="a.status" />
              <button class="btn btn-secondary btn-sm" @click="openReschedule(a)"><Icon name="edit" :size="12" /> Move</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <RescheduleModal v-model="showReschedule" :appointment="activeAppt" @rescheduled="load" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { formatTime12 } from '~/composables/useFormat'

const supabase = useSupabaseClient()

function dateStrOffset(n: number) {
  const d = new Date()
  d.setDate(d.getDate() + n)
  return d.toISOString().slice(0, 10)
}

const dateStrs = [0, 1, 2].map(dateStrOffset)
const days = ref(
  dateStrs.map((dateStr) => ({
    dateStr,
    label: new Date(dateStr + 'T00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }),
    appts: [] as any[],
  }))
)

const showReschedule = ref(false)
const activeAppt = ref<any>(null)

async function load() {
  const { data } = await supabase
    .from('appointments')
    .select('*, patient_names(full_name)')
    .in('date', dateStrs)
    .order('time', { ascending: true })

  const flattened = (data || []).map((a: any) => ({ ...a, patient_name: a.patient_names?.full_name || 'Unknown' }))
  days.value = days.value.map((d) => ({ ...d, appts: flattened.filter((a) => a.date === d.dateStr) }))
}
await useAsyncData('receptionist-schedule', load)

function openReschedule(a: any) {
  activeAppt.value = a
  showReschedule.value = true
}
</script>
