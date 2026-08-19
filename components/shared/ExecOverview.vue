<template>
  <div>
    <div class="page-header"><div><h1>Executive Overview</h1><div class="desc">Key performance indicators for the current quarter — aggregate data only.</div></div></div>
    <div v-if="k" class="grid grid-4" style="margin-bottom:18px;">
      <StatCard icon="cash" label="Total Revenue Generated" :value="fmtNaira(k.total_revenue)" />
      <StatCard icon="layers" label="Active IVF Cycles" :value="k.active_cycles" />
      <StatCard icon="target" label="Overall Success Rate" :value="k.success_rate + '%'" trend="Above national average" trend-tone="up" />
      <StatCard icon="users" label="Monthly Patient Acquisition" :value="k.monthly_acquisition + ' New'" :trend="'Targeting ' + k.acquisition_target" />
    </div>
    <div v-if="k" class="grid grid-main-side">
      <div class="card card-pad">
        <div class="flex-between"><b style="font-size:14px;">Revenue Over Time</b><span class="badge badge-gray">Last 6 Months</span></div>
        <div style="margin-top:10px;"><LineChart :data="revenueChartData" /></div>
      </div>
      <div class="card card-pad">
        <b style="font-size:14px;">Treatment Breakdown</b>
        <div style="display:flex; align-items:center; gap:20px; margin-top:14px;">
          <div style="position:relative;">
            <DonutChart :segments="breakdownWithColor" />
            <div style="position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center;">
              <b style="font-size:18px;">{{ k.active_cycles }}</b><span class="cell-muted" style="font-size:10px;">Total Cycles</span>
            </div>
          </div>
          <div style="display:flex; flex-direction:column; gap:10px;">
            <div v-for="s in breakdownWithColor" :key="s.label" class="flex gap-8">
              <span style="width:9px;height:9px;border-radius:50%;" :style="{ background: s.color }" />
              <span style="font-size:12.5px;">{{ s.label }}</span>
              <b style="font-size:12.5px; margin-left:auto;">{{ s.pct }}%</b>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtNaira } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const k = ref<any>(null)

await useAsyncData('exec-overview', async () => {
  const { data } = await supabase.rpc('exec_overview')
  k.value = data
  return true
})

const PALETTE = ['var(--blue-600)', 'var(--green-500)', 'var(--amber-500)', 'var(--purple-600)', 'var(--red-500)']
const revenueChartData = computed(() => (k.value?.revenue_by_month || []).map((d: any) => ({ m: d.m, v: d.v / 1_000_000 })))
const breakdownWithColor = computed(() => (k.value?.treatment_breakdown || []).map((s: any, i: number) => ({ ...s, color: PALETTE[i % PALETTE.length] })))
</script>
