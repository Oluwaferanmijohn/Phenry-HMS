<template>
  <div>
    <div class="page-header"><div><h1>Recovery Beds</h1><div class="desc">Live occupancy across the recovery ward.</div></div></div>
    <div class="grid grid-4">
      <div v-for="b in beds" :key="b.id" class="card card-pad" :style="{ borderColor: bedBorderColor(b) }">
        <div class="flex-between"><b style="font-size:14px;">{{ b.id }}</b><StatusBadge :status="b.status" /></div>
        <p class="cell-muted" style="margin-top:8px;">{{ bedDescription(b) }}</p>
        <button v-if="b.status === 'Occupied'" class="btn btn-secondary btn-sm btn-block" style="margin-top:10px;" @click="clear(b)"><Icon name="check-circle" :size="12" /> Clear for Discharge</button>
        <button v-else-if="b.status === 'Reserved'" class="btn btn-secondary btn-sm btn-block" style="margin-top:10px;" @click="clear(b)"><Icon name="x-circle" :size="12" /> Cancel Reservation</button>
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

  // Self-heal: a bed 'Reserved' for a date that has now arrived is
  // physically occupied, it just hasn't been told yet — there's no
  // scheduled job to flip it automatically, so this does it the moment
  // staff load this board (which happens routinely through the shift)
  // rather than leave it stuck showing 'Reserved' indefinitely.
  const todayStr = new Date().toISOString().slice(0, 10)
  const dueToday = rows.filter((b: any) => b.status === 'Reserved' && b.reserved_for_date && b.reserved_for_date <= todayStr)
  if (dueToday.length) {
    await Promise.all(
      dueToday.map((b: any) =>
        supabase.from('recovery_beds').update({ status: 'Occupied', occupied_since: new Date().toISOString(), reserved_for_date: null }).eq('id', b.id)
      )
    )
    for (const b of dueToday) {
      b.status = 'Occupied'
      b.reserved_for_date = null
    }
  }

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
    { table: 'recovery_beds', kind: 'update', payload: { status: 'Free', occupied_by_patient_id: null, occupied_since: null, reserved_for_date: null }, match: { id: b.id } },
    () => {
      b.status = 'Free'
      b.patient_name = null
      b.reserved_for_date = null
    }
  )
}
</script>
