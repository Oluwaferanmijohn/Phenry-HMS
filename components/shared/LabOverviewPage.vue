<template>
  <div>
    <div class="page-header">
      <div><h1>{{ role === 'chief_embryologist' ? 'Lab Pipeline Oversight' : 'Laboratory Dashboard' }}</h1><div class="desc">{{ todayLabel }}</div></div>
      <button class="btn btn-primary" @click="$router.push(`/${role}/schedule`)"><Icon name="calendar" :size="13" /> Open Procedure Workspace</button>
    </div>

    <div class="grid grid-3" style="margin-bottom:18px;">
      <StatCard icon="layers" label="Cryo Storage Utilization" :value="`${totalUsed} / ${totalCapacity}`" :trend="utilizationPct + '% full'" />
      <StatCard icon="calendar" label="Today's Procedures" :value="todayProcedures.length" trend="OPU, IUI, transfers & freezing" />
      <StatCard icon="thermo" label="Equipment Needing Attention" :value="failingUnits" :trend-tone="failingUnits ? 'down' : 'up'" :trend="failingUnits ? 'Check QC page' : 'All systems normal'" />
    </div>

    <div class="quick-actions card card-pad">
      <button class="quick-action" @click="$router.push(`/${role}/results`)"><Icon name="flask" :size="16" /><span><b>Enter Lab Results</b><small>Open ordered tests and previous results</small></span></button>
      <button class="quick-action" @click="$router.push(`/${role}/embryo`)"><Icon name="layers" :size="16" /><span><b>Embryo Grading</b><small>Record development from Day 0</small></span></button>
      <button class="quick-action" @click="$router.push(`/${role}/schedule`)"><Icon name="snow" :size="16" /><span><b>Procedures &amp; Cryostorage</b><small>Reports, frozen specimens and locations</small></span></button>
      <button class="quick-action" @click="$router.push(`/${role}/qc`)"><Icon name="settings" :size="16" /><span><b>Equipment &amp; Supplies</b><small>QC, assets, media, kits and stock</small></span></button>
    </div>

    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="calendar" :size="15" /> Today's Fertility Procedures</h3><span class="link" @click="$router.push(`/${role}/schedule`)">View workspace</span></div>
        <div class="scroll-x"><table class="data-table">
          <thead><tr><th>Time</th><th>Patient</th><th>Procedure</th><th>Status</th></tr></thead>
          <tbody><tr v-for="procedure in todayProcedures" :key="`${procedure.source}-${procedure.id}`">
            <td>{{ procedure.time ? formatTime12(procedure.time) : '—' }}</td>
            <td class="cell-strong">{{ procedure.patient_name }}</td>
            <td class="cell-strong">{{ procedure.procedure }}</td>
            <td><StatusBadge :status="procedure.status" /></td>
          </tr></tbody>
        </table></div>
        <div v-if="!todayProcedures.length" style="padding:20px;"><EmptyState icon="calendar" title="Nothing scheduled today" description="OPU, IUI, transfers, sperm procedures, and freezing scheduled by Doctor or Matron will appear here." /></div>
      </div>

      <div style="display:flex;flex-direction:column;gap:16px;">
        <div class="card card-pad">
          <div class="flex-between"><h3 style="font-size:13.5px;"><Icon name="snow" :size="14" /> Cryo Tanks</h3><span class="link" @click="$router.push(`/${role}/schedule`)">Open</span></div>
          <div class="tank-list">
            <div v-for="tank in tanks" :key="tank.id">
              <div class="flex-between tank-label"><span>{{ tank.name }}</span><span class="cell-muted">{{ tank.used }}/{{ tank.capacity }}</span></div>
              <ProgressBar :pct="(tank.used / Math.max(1, tank.capacity)) * 100" :tone="tank.used / Math.max(1, tank.capacity) > 0.85 ? 'red' : ''" />
            </div>
            <p v-if="!tanks.length" class="cell-muted">No storage tanks documented.</p>
          </div>
        </div>
        <div class="card card-pad">
          <h3 style="font-size:13.5px;"><Icon name="clipboard" :size="14" /> Shared Laboratory Workflow</h3>
          <p class="cell-muted parity-note">Both Chief Embryologists and Lab Technicians use the same result templates, grading workspace, fertility reports, specimen register, and laboratory store.</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatTime12 } from '~/composables/useFormat'
import { isFertilityLabProcedure } from '~/composables/useFertilityProcedures'

const props = defineProps<{ role: 'chief_embryologist' | 'lab_tech' }>()
const supabase = useSupabaseClient()
const todayLabel = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
const todayProcedures = ref<any[]>([])
const tanks = ref<any[]>([])
const failingUnits = ref(0)

await useAsyncData(`lab-overview-${props.role}`, async () => {
  const today = new Date().toISOString().slice(0, 10)
  const [clinicalRes, legacyRes, tanksRes, incubatorRes] = await Promise.all([
    supabase.from('surgery_schedule').select('*, patient_names(full_name)').eq('date', today).order('time', { ascending: true }),
    supabase.from('transfer_cryo_schedule').select('*, patient_names(full_name)').eq('scheduled_date', today),
    supabase.from('cryo_tanks').select('*').order('name', { ascending: true }),
    supabase.from('incubator_logs').select('id', { count: 'exact', head: true }).eq('status', 'Fail'),
  ])
  const clinical = (clinicalRes.data || [])
    .filter((item: any) => isFertilityLabProcedure(item.procedure))
    .map((item: any) => ({ ...item, source: 'clinical', patient_name: item.patient_names?.full_name || 'Unknown' }))
  const legacy = (legacyRes.data || []).map((item: any) => ({ ...item, source: 'legacy', procedure: item.type, time: '', patient_name: item.patient_names?.full_name || 'Unknown' }))
  todayProcedures.value = [...clinical, ...legacy]
  tanks.value = tanksRes.data || []
  failingUnits.value = incubatorRes.count || 0
  return true
})

const totalUsed = computed(() => tanks.value.reduce((sum, tank) => sum + Number(tank.used || 0), 0))
const totalCapacity = computed(() => tanks.value.reduce((sum, tank) => sum + Number(tank.capacity || 0), 0))
const utilizationPct = computed(() => totalCapacity.value ? Math.round((totalUsed.value / totalCapacity.value) * 100) : 0)
</script>

<style scoped>
.quick-actions{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin-bottom:18px}.quick-action{display:flex;align-items:flex-start;gap:10px;padding:12px;border:1px solid var(--border);border-radius:9px;background:#fff;text-align:left;color:var(--blue-700);cursor:pointer}.quick-action:hover{border-color:var(--blue-400);background:var(--blue-50)}.quick-action span{display:flex;flex-direction:column;gap:3px}.quick-action b{font-size:12px;color:var(--text-800)}.quick-action small{font-size:10.5px;line-height:1.35;color:var(--text-500)}.tank-list{display:flex;flex-direction:column;gap:10px;margin-top:10px}.tank-label{font-size:12px;margin-bottom:4px}.parity-note{font-size:12px;line-height:1.55;margin-top:8px}@media(max-width:950px){.quick-actions{grid-template-columns:repeat(2,minmax(0,1fr))}}@media(max-width:560px){.quick-actions{grid-template-columns:1fr}}
</style>
