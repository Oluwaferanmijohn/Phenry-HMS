<template>
  <div>
    <div class="page-header"><div><h1>Recovery Beds</h1><div class="desc">Live occupancy across the recovery ward.</div></div></div>
    <div class="grid grid-4">
      <div v-for="b in beds" :key="b.id" class="card card-pad" :style="{ borderColor: b.status === 'Free' ? 'var(--green-500)' : 'var(--red-500)' }">
        <div class="flex-between"><b style="font-size:14px;">{{ b.id }}</b><StatusBadge :status="b.status" /></div>
        <p class="cell-muted" style="margin-top:8px;">{{ b.status === 'Free' ? 'Ready for next patient' : 'Occupied by ' + (b.patient_name || 'patient') }}</p>
        <button v-if="b.status !== 'Free'" class="btn btn-secondary btn-sm btn-block" style="margin-top:10px;" @click="clear(b)"><Icon name="check-circle" :size="12" /> Clear for Discharge</button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const beds = ref<any[]>([])

async function load() {
  const { data } = await supabase.from('recovery_beds').select('*, patient_names:occupied_by_patient_id(full_name)').order('id', { ascending: true })
  beds.value = (data || []).map((b: any) => ({ ...b, patient_name: b.patient_names?.full_name }))
}
await useAsyncData('recovery-beds-page', load)

async function clear(b: any) {
  await queueOrRun(`${b.id} cleared and marked free`, async () => {
    const { error } = await supabase.from('recovery_beds').update({ status: 'Free', occupied_by_patient_id: null, occupied_since: null }).eq('id', b.id)
    if (error) throw error
    b.status = 'Free'
    b.patient_name = null
  })
}
</script>
