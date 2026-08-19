<template>
  <div>
    <div class="page-header"><div><h1>Equipment, QC &amp; Supplies</h1><div class="desc">Daily incubator checks, servicing history, and lab consumables.</div></div></div>
    <div class="tabs" style="margin-bottom:16px;">
      <div class="tab" :class="{ active: tab === 'incubators' }" @click="tab = 'incubators'">Daily Incubator QC</div>
      <div class="tab" :class="{ active: tab === 'equipment' }" @click="tab = 'equipment'">Equipment Servicing</div>
      <div class="tab" :class="{ active: tab === 'store' }" @click="tab = 'store'">Lab Store</div>
    </div>

    <div v-if="tab === 'incubators'" class="card">
      <table class="data-table">
        <thead><tr><th>Unit</th><th>Location</th><th>Temp °C</th><th>CO₂ %</th><th>O₂ %</th><th>Humidity %</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="u in incubators" :key="u.id">
            <td class="cell-strong">{{ u.name }}</td>
            <td class="cell-muted">{{ u.location }}</td>
            <td><input v-model.number="u.temp" class="input" style="width:70px;" type="number" step="0.1" /></td>
            <td><input v-model.number="u.co2" class="input" style="width:70px;" type="number" step="0.1" /></td>
            <td><input v-model.number="u.o2" class="input" style="width:70px;" type="number" step="0.1" /></td>
            <td><input v-model.number="u.humidity" class="input" style="width:70px;" type="number" step="0.1" /></td>
            <td><StatusBadge :status="u.status" /></td>
            <td style="text-align:right;" class="flex gap-8">
              <button class="btn btn-success btn-sm" @click="logCheck(u, 'Pass')">Pass</button>
              <button class="btn btn-danger btn-sm" @click="logCheck(u, 'Fail')">Fail</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else-if="tab === 'equipment'" class="card">
      <table class="data-table">
        <thead><tr><th>Equipment</th><th>Category</th><th>Last Serviced</th><th>Next Due</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="e in equipment" :key="e.id">
            <td class="cell-strong">{{ e.name }}</td>
            <td class="cell-muted">{{ e.category }}</td>
            <td class="cell-muted">{{ fmtDate(e.last_serviced) }}</td>
            <td class="cell-muted">{{ fmtDate(e.next_service_due) }}</td>
            <td><StatusBadge :status="e.status" /></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="card">
      <table class="data-table">
        <thead><tr><th>Item</th><th>Category</th><th>Qty on Hand</th><th>Min Threshold</th><th>Location</th></tr></thead>
        <tbody>
          <tr v-for="s in store" :key="s.id">
            <td class="cell-strong">{{ s.name }}</td>
            <td class="cell-muted">{{ s.category }}</td>
            <td :style="{ color: s.current_qty <= s.min_threshold ? 'var(--red-600)' : 'inherit', fontWeight: s.current_qty <= s.min_threshold ? 700 : 500 }">
              {{ s.current_qty }} {{ s.unit }}
            </td>
            <td class="cell-muted">{{ s.min_threshold }} {{ s.unit }}</td>
            <td class="cell-muted">{{ s.location }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const tab = ref<'incubators' | 'equipment' | 'store'>('incubators')
const incubators = ref<any[]>([])
const equipment = ref<any[]>([])
const store = ref<any[]>([])

await useAsyncData('chief-qc', async () => {
  const [incRes, eqRes, storeRes] = await Promise.all([
    supabase.from('incubator_logs').select('*').order('name', { ascending: true }),
    supabase.from('lab_equipment').select('*').order('name', { ascending: true }),
    supabase.from('lab_store').select('*').order('name', { ascending: true }),
  ])
  incubators.value = incRes.data || []
  equipment.value = eqRes.data || []
  store.value = storeRes.data || []
  return true
})

async function logCheck(u: any, status: string) {
  await queueOrRun(`${u.name} logged as ${status}`, async () => {
    const { error } = await supabase
      .from('incubator_logs')
      .update({ temp: u.temp, co2: u.co2, o2: u.o2, humidity: u.humidity, status, last_checked: new Date().toISOString(), checked_by: profile.value!.id })
      .eq('id', u.id)
    if (error) throw error
    u.status = status
  })
}
</script>
