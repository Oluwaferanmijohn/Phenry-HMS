<template>
  <div>
    <div class="page-header"><div><h1>Clinical Operations</h1><div class="desc">Aggregate operational metrics — no patient-identifiable data.</div></div></div>
    <div v-if="k" class="grid grid-3" style="margin-bottom:18px;">
      <StatCard icon="activity" label="Cycles In Progress" :value="k.cycles_in_progress" trend="Across all stages" />
      <StatCard icon="bed" label="Recovery Bed Utilization" :value="`${k.beds_occupied}/${k.beds_total}`" :trend="occupancyPct + '% occupied'" />
      <StatCard icon="users" label="Clinical Staff Headcount" :value="k.clinical_staff_count" trend="Across 6 clinical roles" />
    </div>
    <div v-if="k" class="card card-pad">
      <b style="font-size:14px;">Cycle Distribution by Stage</b>
      <div style="display:flex; flex-direction:column; gap:12px; margin-top:16px;">
        <div v-for="sc in k.stage_distribution" :key="sc.stage">
          <div class="flex-between" style="font-size:12.5px; margin-bottom:5px;"><span>{{ sc.stage }}</span><b>{{ sc.n }}</b></div>
          <ProgressBar :pct="(sc.n / Math.max(1, totalCycles)) * 100" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const supabase = useSupabaseClient()
const k = ref<any>(null)

await useAsyncData('exec-operations', async () => {
  const { data } = await supabase.rpc('exec_operations')
  k.value = data
  return true
})

const occupancyPct = computed(() => (k.value ? Math.round((k.value.beds_occupied / Math.max(1, k.value.beds_total)) * 100) : 0))
const totalCycles = computed(() => (k.value?.stage_distribution || []).reduce((s: number, x: any) => s + x.n, 0))
</script>
