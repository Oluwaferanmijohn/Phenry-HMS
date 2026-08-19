<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Waiting Room Overview</h1>
        <div class="desc">{{ todayLabel }} · Front Desk</div>
      </div>
      <div class="page-actions">
        <button class="btn btn-primary" @click="$router.push('/receptionist/register')"><Icon name="plus" :size="14" /> New Patient</button>
      </div>
    </div>

    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="calendar" :size="15" /> Today's Schedule</h3><span class="link">{{ today.length }} appointments</span></div>
        <div class="card-body tight">
          <div v-if="!today.length" style="padding:20px;">
            <EmptyState icon="calendar" title="Nothing on the books today" description="Appointments booked for today will appear here." />
          </div>
          <div v-for="a in today" :key="a.id" class="list-row">
            <div style="width:52px; flex-shrink:0; font-size:12px; font-weight:700; color:var(--text-700);">{{ formatTime12(a.time) }}</div>
            <div
              style="width:3px; height:32px; border-radius:2px; flex-shrink:0;"
              :style="{ background: a.status === 'Completed' ? 'var(--green-500)' : a.status === 'Waiting' ? 'var(--amber-500)' : 'var(--blue-500)' }"
            />
            <div><div class="main-txt">{{ a.type }}</div><div class="sub-txt">{{ a.patient_name }} · {{ a.room || 'Room TBC' }}</div></div>
            <div class="side flex gap-8">
              <StatusBadge :status="a.status" />
              <button v-if="a.status !== 'Completed'" class="btn btn-secondary btn-sm" @click="openReschedule(a)">Reschedule</button>
            </div>
          </div>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:18px;">
        <div class="card card-pad">
          <h3 style="font-size:13.5px;">Quick Actions</h3>
          <div style="display:flex; flex-direction:column; gap:8px; margin-top:12px;">
            <button class="btn btn-primary btn-block" @click="$router.push('/receptionist/register')"><Icon name="user" :size="14" /> Register New Patient</button>
            <button class="btn btn-secondary btn-block" @click="$router.push('/receptionist/book')"><Icon name="calendar" :size="14" /> Schedule an Appointment</button>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="users" :size="15" /> Waiting Room Queue</h3><Badge tone="amber">{{ waiting.length }} Waiting</Badge></div>
          <div class="card-body tight">
            <div v-if="!waiting.length" style="padding:20px;">
              <EmptyState icon="users" title="No Active Patients in Waiting Room" description="Patient flow is currently clear. Incoming patients checked in at reception will appear here automatically." />
            </div>
            <div v-for="a in waiting" :key="a.id" class="list-row">
              <Avatar :name="a.patient_name" :size="30" />
              <div><div class="main-txt">{{ a.patient_name }}</div><div class="sub-txt">{{ a.type }} · Arr. {{ formatTime12(a.time) }}</div></div>
              <div class="side">
                <select class="input" style="font-size:11.5px; padding:4px 8px;" :value="a.status" @change="setStatus(a, ($event.target as HTMLSelectElement).value)">
                  <option>Waiting</option>
                  <option>In Room</option>
                  <option>Completed</option>
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <RescheduleModal v-model="showReschedule" :appointment="activeAppt" @rescheduled="onRescheduled" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { formatTime12 } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const todayStr = new Date().toISOString().slice(0, 10)
const todayLabel = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })

const today = ref<any[]>([])
const showReschedule = ref(false)
const activeAppt = ref<any>(null)

async function load() {
  const { data } = await supabase
    .from('appointments')
    .select('*, patient_names(full_name)')
    .eq('date', todayStr)
    .order('time', { ascending: true })
  today.value = (data || []).map((a: any) => ({ ...a, patient_name: a.patient_names?.full_name || 'Unknown' }))
}
await useAsyncData('receptionist-overview', load)

const waiting = computed(() => today.value.filter((a) => a.status === 'Waiting'))

async function setStatus(a: any, status: string) {
  await queueOrRun(`${a.patient_name} marked ${status}`, async () => {
    const { error } = await supabase.from('appointments').update({ status }).eq('id', a.id)
    if (error) throw error
    a.status = status
  })
}

function openReschedule(a: any) {
  activeAppt.value = a
  showReschedule.value = true
}

function onRescheduled(updated: any) {
  const idx = today.value.findIndex((a) => a.id === updated.id)
  // Moved off today's date entirely — drop from this list; otherwise patch in place.
  if (updated.date !== todayStr) {
    if (idx !== -1) today.value.splice(idx, 1)
  } else if (idx !== -1) {
    today.value[idx] = { ...today.value[idx], ...updated }
    today.value.sort((a, b) => a.time.localeCompare(b.time))
  }
}
</script>
