<template>
  <div>
    <div class="page-header"><div><h1>Growth &amp; Acquisition</h1><div class="desc">Where new patients are coming from, and how acquisition trends month to month.</div></div></div>
    <div v-if="k" class="grid grid-main-side">
      <div class="card card-pad">
        <b style="font-size:14px;">Monthly Acquisition vs Target</b>
        <div class="flex-between" style="margin-top:14px;"><span class="cell-muted">{{ k.monthly_acquisition }} new patients this month</span><span class="cell-muted">Target: {{ k.acquisition_target }}</span></div>
        <ProgressBar :pct="(k.monthly_acquisition / Math.max(1, k.acquisition_target)) * 100" tone="amber" />
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="target" :size="15" /> Referral Source Breakdown</h3></div>
        <div class="card-body tight">
          <div v-for="r in k.referral_breakdown" :key="r.source" class="list-row">
            <div class="main-txt">{{ r.source }}</div>
            <div class="side"><b>{{ r.n }}</b><span class="cell-muted"> patients</span></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const supabase = useSupabaseClient()
const k = ref<any>(null)

await useAsyncData('exec-growth', async () => {
  const { data } = await supabase.rpc('exec_growth')
  k.value = data
  return true
})
</script>
