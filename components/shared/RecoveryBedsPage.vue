<template>
  <div>
    <div class="page-header"><div><h1>Recovery Beds</h1><div class="desc">Live occupancy across the recovery ward.</div></div></div>
    <div class="grid grid-4">
      <div v-for="b in beds" :key="b.id" class="card card-pad" :style="{ borderColor: bedBorderColor(b) }">
        <div class="flex-between"><b style="font-size:14px;">{{ b.id }}</b><StatusBadge :status="b.status" /></div>
        <p class="cell-muted" style="margin-top:8px;">{{ bedDescription(b) }}</p>
        <button v-if="b.status === 'Occupied'" class="btn btn-secondary btn-sm btn-block" style="margin-top:10px;" @click="clear(b)"><Icon name="check-circle" :size="12" /> Clear for Discharge</button>
        <template v-else-if="b.status === 'Reserved'">
          <button class="btn btn-primary btn-sm btn-block" style="margin-top:10px;" @click="admit(b)"><Icon name="check-circle" :size="12" /> Admit to Bed</button>
          <button class="btn btn-secondary btn-sm btn-block" style="margin-top:6px;" @click="clear(b)"><Icon name="x-circle" :size="12" /> Cancel Reservation</button>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const beds = ref<any[]>([])

async function load() {
  const { data } = await supabase.from('recovery_beds').select('*, patient_names:occupied_by_patient_id(full_name)').order('id', { ascending: true })
  const rows = (data || []).map((b: any) => ({ ...b, patient_name: b.patient_names?.full_name }))

  beds.value = rows
}
await useAsyncData('recovery-beds-page', load)

function bedBorderColor(b: any) {
  if (b.status === 'Free') return 'var(--green-500)'
  if (b.status === 'Reserved') return 'var(--amber-500)'
  return 'var(--red-500)'
}

function bedDescription(b: any) {
  if (b.status === 'Free') return 'Ready for next patient'
  if (b.status === 'Reserved') return `Reserved for ${b.patient_name || 'patient'} — ${fmtDate(b.reserved_for_date)}`
  return 'Occupied by ' + (b.patient_name || 'patient')
}

async function clear(b: any) {
  const label = b.status === 'Reserved' ? `${b.id} reservation cancelled` : `${b.id} cleared and marked free`
  await queueOrRun(
    label,
    { kind: 'rpc', rpcName: 'set_recovery_bed_state', payload: { p_bed_id: b.id, p_action: 'clear' } },
    () => {
      b.status = 'Free'
      b.patient_name = null
      b.reserved_for_date = null
    }
  )
}

async function admit(b: any) {
  await queueOrRun(
    `${b.id} marked occupied`,
    { kind: 'rpc', rpcName: 'set_recovery_bed_state', payload: { p_bed_id: b.id, p_action: 'admit' } },
    () => { b.status = 'Occupied'; b.occupied_since = new Date().toISOString(); b.reserved_for_date = null },
  )
}
</script>
