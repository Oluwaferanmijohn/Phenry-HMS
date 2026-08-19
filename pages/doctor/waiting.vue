<template>
  <div>
    <div class="page-header"><div><h1>Global Waiting Room</h1><div class="desc">{{ todayLabel }} · Your patient queue</div></div></div>
    <div class="card">
      <div class="card-header"><h3><Icon name="users" :size="15" /> Today's Queue</h3><Badge tone="amber">{{ waiting.length }} waiting</Badge></div>
      <div class="card-body tight">
        <div v-if="!today.length" style="padding:20px;"><EmptyState icon="users" title="No patients scheduled today" description="Your appointments for today will appear here." /></div>
        <div v-for="a in today" :key="a.id" class="list-row">
          <div style="width:56px; flex-shrink:0; font-size:12px; font-weight:700;">{{ formatTime12(a.time) }}</div>
          <Avatar :name="a.patient_name" :size="30" />
          <div><div class="main-txt">{{ a.patient_name }}</div><div class="sub-txt">{{ a.type }}</div></div>
          <div class="side flex gap-8">
            <StatusBadge :status="a.status" />
            <button class="btn btn-primary btn-sm" @click="$router.push(`/doctor/consultation?patient=${a.patient_id}`)"><Icon name="clipboard" :size="12" /> Start Consult</button>
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
const todayStr = new Date().toISOString().slice(0, 10)
const todayLabel = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
const today = ref<any[]>([])

await useAsyncData('doctor-waiting', async () => {
  const { data } = await supabase
    .from('appointments')
    .select('*, patient_names(full_name)')
    .eq('date', todayStr)
    .order('time', { ascending: true })
  today.value = (data || []).map((a: any) => ({ ...a, patient_name: a.patient_names?.full_name || 'Unknown' }))
  return true
})

const waiting = computed(() => today.value.filter((a) => a.status === 'Waiting'))
</script>
