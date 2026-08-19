<template>
  <div>
    <div class="page-header"><div><h1>Lab Pipeline Oversight</h1><div class="desc">{{ todayLabel }}</div></div></div>
    <div class="grid grid-3" style="margin-bottom:18px;">
      <StatCard icon="layers" label="Cryo Storage Utilization" :value="`${totalUsed} / ${totalCapacity}`" :trend="utilizationPct + '% full'" />
      <StatCard icon="calendar" label="Today's Procedures" :value="todayProcedures.length" trend="OPU & Transfers" />
      <StatCard icon="thermo" label="Equipment Needing Attention" :value="failingUnits" :trend-tone="failingUnits ? 'down' : 'up'" :trend="failingUnits ? 'Check QC page' : 'All systems normal'" />
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="calendar" :size="15" /> Today's Procedures</h3><span class="link" @click="$router.push('/chief_embryologist/schedule')">View schedule</span></div>
        <table class="data-table">
          <thead><tr><th>Time</th><th>Patient</th><th>Procedure</th><th>Status</th></tr></thead>
          <tbody>
            <tr v-for="p in todayProcedures" :key="p.id">
              <td>{{ formatTime12(p.time) }}</td>
              <td class="cell-strong">{{ p.patient_name }}</td>
              <td class="cell-strong">{{ p.procedure }}</td>
              <td><StatusBadge :status="p.status" /></td>
            </tr>
          </tbody>
        </table>
        <div v-if="!todayProcedures.length" style="padding:20px;"><EmptyState icon="calendar" title="Nothing today" description="OPUs and transfers scheduled today will appear here." /></div>
      </div>
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card card-pad">
          <h3 style="font-size:13.5px;"><Icon name="check-circle" :size="14" /> Pending Verifications</h3>
          <EmptyState icon="check-circle" title="Nothing awaiting sign-off" description="Lab results don't yet track a verification workflow — ask if you want one added." />
        </div>
        <div class="card card-pad">
          <h3 style="font-size:13.5px;"><Icon name="snow" :size="14" /> Cryo Tanks at a Glance</h3>
          <div style="display:flex; flex-direction:column; gap:10px; margin-top:10px;">
            <div v-for="t in tanks" :key="t.id">
              <div class="flex-between" style="font-size:12px; margin-bottom:4px;"><span>{{ t.name }}</span><span class="cell-muted">{{ t.used }}/{{ t.capacity }}</span></div>
              <ProgressBar :pct="(t.used / Math.max(1, t.capacity)) * 100" :tone="t.used / t.capacity > 0.85 ? 'red' : ''" />
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
const todayLabel = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
const todayProcedures = ref<any[]>([])
const tanks = ref<any[]>([])
const failingUnits = ref(0)

await useAsyncData('chief-overview', async () => {
  const todayStr = new Date().toISOString().slice(0, 10)
  const [surgeryRes, tanksRes, incRes] = await Promise.all([
    supabase.from('surgery_schedule').select('*, patient_names(full_name)').eq('date', todayStr).order('time', { ascending: true }),
    supabase.from('cryo_tanks').select('*').order('name', { ascending: true }),
    supabase.from('incubator_logs').select('id', { count: 'exact', head: true }).eq('status', 'Fail'),
  ])
  todayProcedures.value = (surgeryRes.data || []).map((p: any) => ({ ...p, patient_name: p.patient_names?.full_name || 'Unknown' }))
  tanks.value = tanksRes.data || []
  failingUnits.value = incRes.count || 0
  return true
})

const totalUsed = computed(() => tanks.value.reduce((s, t) => s + t.used, 0))
const totalCapacity = computed(() => tanks.value.reduce((s, t) => s + t.capacity, 0))
const utilizationPct = computed(() => (totalCapacity.value ? Math.round((totalUsed.value / totalCapacity.value) * 100) : 0))
</script>
