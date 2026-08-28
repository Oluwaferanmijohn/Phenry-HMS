<template>
  <div>
    <div class="page-header"><div><h1>Clinical Hub</h1><div class="desc">Floor-wide operational overview.</div></div></div>
    <div class="grid grid-3" style="margin-bottom:18px;">
      <StatCard icon="layers" label="Active IVF Cycles" :value="activeCycles" trend="Steady volume" />
      <StatCard icon="siren" label="Pending Surgeries" :value="surgeries.length" :trend="surgeries[0] ? 'Next: ' + formatTime12(surgeries[0].time) : 'None scheduled'" />
      <StatCard icon="bed" label="Available Recovery Beds" :value="`${freeBeds} / ${beds.length}`" :trend="freeBeds < 3 ? 'Running low' : 'Healthy capacity'" :trend-tone="freeBeds < 3 ? 'down' : 'up'" />
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="calendar" :size="15" /> Procedure &amp; Surgery Schedule</h3><span class="link" @click="$router.push('/matron/surgery')">View full</span></div>
        <table class="data-table">
          <thead><tr><th>Time</th><th>Patient</th><th>Procedure</th><th>Assigned Dr.</th><th>Status</th></tr></thead>
          <tbody>
            <tr v-for="s in surgeries" :key="s.id">
              <td>{{ formatTime12(s.time) }}</td>
              <td class="cell-strong">{{ s.patient_name }}</td>
              <td class="cell-strong">{{ s.procedure }}</td>
              <td class="cell-muted">{{ s.provider_name || 'Unassigned' }}</td>
              <td><StatusBadge :status="s.status" /></td>
            </tr>
          </tbody>
        </table>
      </div>
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card">
          <div class="card-header"><h3><Icon name="users" :size="15" /> Today's Duty</h3><span class="link" @click="$router.push('/matron/staffing')">Manage</span></div>
          <div class="card-body tight">
            <div v-for="s in dutyRows" :key="s.label" class="list-row">
              <span class="shift-chip" :class="s.cls">{{ s.label }}</span>
              <div style="margin-left:8px;">
                <span v-if="s.names.length">{{ s.names.join(', ') }}</span>
                <span v-else class="cell-muted">Unassigned</span>
              </div>
            </div>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="bed" :size="15" /> Recovery Beds</h3><span style="font-size:11px; display:flex; gap:8px;"><span style="color:var(--green-600);">● Free</span><span style="color:var(--amber-600);">● Reserved</span><span style="color:var(--red-600);">● Occupied</span></span></div>
          <div class="card-body">
            <div class="grid grid-4" style="gap:8px;">
              <div
                v-for="b in beds"
                :key="b.id"
                class="card-pad"
                style="text-align:center; padding:10px 4px;"
                :style="{ border: `1.5px solid ${bedColor(b).border}`, borderRadius: 'var(--radius-sm)', background: bedColor(b).bg }"
              >
                <div style="font-size:11px; font-weight:700;">{{ b.id }}</div>
                <div style="font-size:9.5px; color:var(--text-500);">{{ b.status === 'Free' ? 'Free' : b.patient_name }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { formatTime12 } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const activeCycles = ref(0)
const surgeries = ref<any[]>([])
const beds = ref<any[]>([])
const dutyRows = ref<{ label: string; cls: string; names: string[] }[]>([])

await useAsyncData('matron-overview', async () => {
  const todayStr = new Date().toISOString().slice(0, 10)
  const [cyclesRes, surgeryRes, bedsRes, rosterRes] = await Promise.all([
    supabase.from('cycles').select('id', { count: 'exact', head: true }).eq('status', 'Active'),
    supabase.from('surgery_schedule').select('*, patient_names(full_name), profiles:assigned_provider_id(full_name)').gte('date', todayStr).order('date', { ascending: true }).order('time', { ascending: true }),
    supabase.from('recovery_beds').select('*, patient_names:occupied_by_patient_id(full_name)').order('id', { ascending: true }),
    supabase.from('duty_roster').select('*').eq('date', todayStr).maybeSingle(),
  ])
  activeCycles.value = cyclesRes.count || 0
  surgeries.value = (surgeryRes.data || []).map((s: any) => ({ ...s, patient_name: s.patient_names?.full_name || 'Unknown', provider_name: s.profiles?.full_name }))
  beds.value = (bedsRes.data || []).map((b: any) => ({ ...b, patient_name: b.patient_names?.full_name }))
  dutyRows.value = [
    { label: 'Morning', cls: 'shift-am', names: rosterRes.data?.morning || [] },
    { label: 'Afternoon', cls: 'shift-pm', names: rosterRes.data?.afternoon || [] },
    { label: 'Night', cls: 'shift-ni', names: rosterRes.data?.night || [] },
  ]
  return true
})

function bedColor(b: any) {
  if (b.status === 'Free') return { border: 'var(--green-500)', bg: 'var(--green-50)' }
  if (b.status === 'Reserved') return { border: 'var(--amber-500)', bg: 'var(--amber-50)' }
  return { border: 'var(--red-500)', bg: 'var(--red-50)' }
}

// "Available" means physically free right now. A 'Reserved' bed is
// earmarked for a future-dated procedure but nobody's in it yet, so it
// should still count as available capacity today — only 'Occupied' should
// bring this down (see ScheduleProcedureModal.vue for where the distinction
// gets set).
const freeBeds = computed(() => beds.value.filter((b) => b.status !== 'Occupied').length)
</script>
