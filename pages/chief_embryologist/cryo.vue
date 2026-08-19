<template>
  <div>
    <div class="page-header">
      <div><h1>Cryopreservation Management</h1><div class="desc">Storage tank inventory and cryo-asset tracking.</div></div>
      <div class="page-actions">
        <button class="btn btn-secondary" @click="openTank(null)"><Icon name="plus" :size="14" /> Add Tank</button>
        <button class="btn btn-primary" @click="showLog = true"><Icon name="snow" :size="14" /> Log Cryo Record</button>
      </div>
    </div>
    <div class="grid grid-3" style="margin-bottom:18px;">
      <div v-for="t in tanks" :key="t.id" class="card card-pad clickable" @click="openTank(t)">
        <div class="flex-between"><b style="font-size:14px;">{{ t.name }}</b><Icon name="snow" :size="16" /></div>
        <div class="cell-muted" style="margin-top:4px;">{{ t.phase }} · {{ t.current_temp }}°C</div>
        <div style="margin-top:10px;"><ProgressBar :pct="(t.used / Math.max(1, t.capacity)) * 100" :tone="t.used / t.capacity > 0.85 ? 'red' : ''" /></div>
        <div class="cell-muted" style="margin-top:6px;">{{ t.used }} / {{ t.capacity }} straws used</div>
      </div>
    </div>
    <div class="card">
      <div class="card-header"><h3><Icon name="layers" :size="15" /> Cryo Storage Log</h3></div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>Asset</th><th>Straws</th><th>Frozen On</th><th>Location</th></tr></thead>
        <tbody>
          <tr v-for="r in records" :key="r.id">
            <td class="cell-strong">{{ r.patient_name }}</td>
            <td><Badge tone="blue">{{ r.asset_type }}</Badge></td>
            <td>{{ r.straws }}</td>
            <td class="cell-muted">{{ fmtDate(r.freezing_date) }}</td>
            <td class="cell-muted mono">{{ r.tank_name || '—' }} / {{ r.canister }} / {{ r.position }}</td>
          </tr>
        </tbody>
      </table>
      <div v-if="!records.length" style="padding:20px;"><EmptyState icon="snow" title="No cryo records yet" description="Logged cryopreservation records will appear here." /></div>
    </div>

    <TankModal v-model="showTank" :tank="activeTank" @saved="load" />
    <CryoLogModal v-model="showLog" :tanks="tanks" @logged="load" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const tanks = ref<any[]>([])
const records = ref<any[]>([])
const showTank = ref(false)
const showLog = ref(false)
const activeTank = ref<any>(null)

async function load() {
  const [tanksRes, recordsRes] = await Promise.all([
    supabase.from('cryo_tanks').select('*').order('name', { ascending: true }),
    supabase.from('cryo_records').select('*, patient_names(full_name), cryo_tanks(name)').order('freezing_date', { ascending: false }),
  ])
  tanks.value = tanksRes.data || []
  records.value = (recordsRes.data || []).map((r: any) => ({ ...r, patient_name: r.patient_names?.full_name || 'Unknown', tank_name: r.cryo_tanks?.name }))
}
await useAsyncData('chief-cryo', load)

function openTank(t: any) {
  activeTank.value = t
  showTank.value = true
}
</script>
