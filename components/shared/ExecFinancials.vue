<template>
  <div>
    <div class="page-header"><div><h1>Financials</h1><div class="desc">Revenue and collections across all active treatment packages.</div></div></div>
    <div v-if="k" class="grid grid-3" style="margin-bottom:18px;">
      <StatCard icon="cash" label="Collected Revenue" :value="fmtNaira(k.collected_revenue)" trend="Verified & approved" trend-tone="up" />
      <StatCard icon="clock" label="Outstanding / In Verification" :value="fmtNaira(k.outstanding_revenue)" trend="Across active plans" />
      <StatCard icon="layers" label="Active Payment Plans" :value="k.active_payment_plans" trend="Across all packages" />
    </div>
    <div v-if="k" class="card card-pad" style="margin-bottom:18px;">
      <b style="font-size:14px;">Monthly Revenue (₦ Millions)</b>
      <div style="margin-top:10px;"><LineChart :data="revenueChartData" /></div>
    </div>
    <div class="card">
      <div class="card-header"><h3><Icon name="cash" :size="15" /> Revenue by Treatment Package</h3></div>
      <table class="data-table">
        <thead><tr><th>Package</th><th>Active Plans</th><th>Total Value</th><th>Collected</th></tr></thead>
        <tbody>
          <tr v-for="p in k?.revenue_by_package || []" :key="p.package">
            <td class="cell-strong">{{ p.package }}</td>
            <td>{{ p.plans }}</td>
            <td>{{ fmtNaira(p.total) }}</td>
            <td style="color:var(--green-600); font-weight:600;">{{ fmtNaira(p.collected) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtNaira } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const k = ref<any>(null)
const overview = ref<any>(null)

await useAsyncData('exec-financials', async () => {
  const [finRes, overviewRes] = await Promise.all([supabase.rpc('exec_financials'), supabase.rpc('exec_overview')])
  k.value = finRes.data
  overview.value = overviewRes.data
  return true
})

const revenueChartData = computed(() => (overview.value?.revenue_by_month || []).map((d: any) => ({ m: d.m, v: d.v / 1_000_000 })))
</script>
