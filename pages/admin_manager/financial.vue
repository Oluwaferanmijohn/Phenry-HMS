<template>
  <div>
    <div class="page-header"><div><h1>Financial Approvals</h1><div class="desc">Review and process outstanding patient payments.</div></div></div>
    <div class="card">
      <div class="card-header"><h3><Icon name="cash" :size="15" /> Pending Approvals</h3><Badge tone="amber">{{ pending.length }} pending</Badge></div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>Milestone</th><th>Amount</th><th>Proof</th><th>Actions</th></tr></thead>
        <tbody>
          <tr v-for="m in pending" :key="m.id">
            <td class="cell-strong">{{ m.patient_name }}</td>
            <td class="cell-muted">{{ m.label }}</td>
            <td>{{ fmtNaira(m.amount) }}</td>
            <td><Badge :tone="m.proof_url ? 'blue' : 'red'">{{ m.proof_url ? 'Uploaded' : 'Missing' }}</Badge></td>
            <td style="text-align:right;" class="flex gap-8">
              <button class="btn btn-secondary btn-sm" @click="reject(m)">Flag / Reject</button>
              <button class="btn btn-success btn-sm" @click="approve(m)"><Icon name="check-circle" :size="12" /> Approve &amp; Update</button>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="!pending.length" style="padding:20px;"><EmptyState icon="check-circle" title="Nothing pending" description="All submitted payment proofs have been processed." /></div>
    </div>

    <div class="card" style="margin-top:18px;">
      <div class="card-header"><h3><Icon name="layers" :size="15" /> All Payment Plans</h3></div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>Package</th><th>Total</th><th>Status</th></tr></thead>
        <tbody>
          <tr v-for="pp in allPlans" :key="pp.id">
            <td class="cell-strong">{{ pp.patient_name }}</td>
            <td class="cell-muted">{{ pp.package }}</td>
            <td>{{ fmtNaira(pp.total_cost) }}</td>
            <td><Badge :tone="pp.paidCount === pp.milestoneCount ? 'green' : 'blue'">{{ pp.paidCount }}/{{ pp.milestoneCount }} milestones paid</Badge></td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtNaira } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const pending = ref<any[]>([])
const allPlans = ref<any[]>([])

async function load() {
  const [pendingRes, plansRes] = await Promise.all([
    supabase.from('payment_milestones').select('*, payment_plans(patient_id, patient_names(full_name))').eq('status', 'Pending Verification'),
    supabase.from('payment_plans').select('*, patient_names(full_name), payment_milestones(status)'),
  ])
  pending.value = (pendingRes.data || []).map((m: any) => ({ ...m, patient_name: m.payment_plans?.patient_names?.full_name || 'Unknown' }))
  allPlans.value = (plansRes.data || []).map((pp: any) => ({
    ...pp,
    patient_name: pp.patient_names?.full_name || 'Unknown',
    milestoneCount: pp.payment_milestones?.length || 0,
    paidCount: (pp.payment_milestones || []).filter((m: any) => m.status === 'Paid').length,
  }))
}
await useAsyncData('admin-financial', load)

async function approve(m: any) {
  await queueOrRun(`${m.patient_name}'s ${m.label} approved`, async () => {
    const { error } = await supabase.rpc('approve_milestone', { p_milestone_id: m.id })
    if (error) throw error
    await load()
  })
}
async function reject(m: any) {
  await queueOrRun(`${m.patient_name}'s ${m.label} flagged for follow-up`, async () => {
    const { error } = await supabase.rpc('reject_milestone', { p_milestone_id: m.id })
    if (error) throw error
    await load()
  })
}
</script>
