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
        <thead><tr><th>Patient</th><th>Asset</th><th>Straws</th><th>Frozen On</th><th>Location</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="r in records" :key="r.id">
            <td class="cell-strong">{{ r.patient_name }}</td>
            <td><Badge tone="blue">{{ r.asset_type }}</Badge></td>
            <td>{{ r.straws }}</td>
            <td class="cell-muted">{{ fmtDate(r.freezing_date) }}</td>
            <td class="cell-muted mono">{{ r.tank_name || '—' }} / {{ r.canister }} / {{ r.position }}</td>
            <td><Badge :tone="r.status === 'Used' ? 'gray' : 'green'">{{ r.status }}</Badge></td>
            <td style="text-align:right;">
              <button v-if="r.status === 'Stored'" class="btn btn-secondary btn-sm" @click="openUse(r)">Use / Remove</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="!records.length" style="padding:20px;"><EmptyState icon="snow" title="No cryo records yet" description="Logged cryopreservation records will appear here." /></div>
    </div>

    <TankModal v-model="showTank" :tank="activeTank" @saved="load" />
    <CryoLogModal v-model="showLog" :tanks="tanks" @logged="load" />

    <Modal v-model="showUse" title="Log Straws Used">
      <p v-if="activeRecord" class="cell-muted" style="margin-bottom:12px;">{{ activeRecord.patient_name }} · {{ activeRecord.asset_type }} · {{ activeRecord.straws }} straw(s) currently in storage</p>
      <div class="field">
        <label>Straws Used</label>
        <input v-model="useQty" class="input" type="number" min="1" :max="activeRecord?.straws" />
        <div class="hint">Leave at the full amount to mark this record fully used; enter fewer to record a partial thaw.</div>
      </div>
      <template #footer>
        <button class="btn btn-secondary" @click="showUse = false">Cancel</button>
        <button class="btn btn-primary" :disabled="usingRecord" @click="confirmUse"><Icon name="check-circle" :size="13" /> Confirm Usage</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { toast } = useToast()
const tanks = ref<any[]>([])
const records = ref<any[]>([])
const showTank = ref(false)
const showLog = ref(false)
const activeTank = ref<any>(null)

const showUse = ref(false)
const activeRecord = ref<any>(null)
const useQty = ref<number | string>(1)
const usingRecord = ref(false)

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

function openUse(r: any) {
  activeRecord.value = r
  useQty.value = r.straws
  showUse.value = true
}

async function confirmUse() {
  if (!activeRecord.value) return
  usingRecord.value = true
  const { error } = await supabase.rpc('use_cryo_record', { p_record_id: activeRecord.value.id, p_straws_used: Number(useQty.value) })
  usingRecord.value = false
  if (error) {
    toast(error.message)
    return
  }
  showUse.value = false
  await load()
}
</script>
