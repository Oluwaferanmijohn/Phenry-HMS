<template>
  <div>
    <div class="page-header"><div><h1>Overview</h1><div class="desc">Clinic-wide operations at a glance.</div></div></div>
    <div class="grid grid-4" style="margin-bottom:18px;">
      <StatCard icon="cash" label="Pending Approvals" :value="pending.length" :trend="pending.length ? 'Needs review' : 'All clear'" :trend-tone="pending.length ? 'down' : 'up'" />
      <StatCard icon="users" label="Active Staff" :value="activeStaffCount" :trend="`of ${staff.length} total`" />
      <StatCard icon="user" label="Registered Patients" :value="patientCount" />
      <StatCard icon="activity" label="Active Cycles" :value="activeCyclesCount" trend="in progress" />
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="cash" :size="15" /> Pending Approvals</h3><span class="link" @click="$router.push('/admin_manager/financial')">View all</span></div>
        <div class="card-body tight">
          <div v-if="!pending.length" style="padding:18px;"><EmptyState icon="check-circle" title="All caught up" description="No outstanding payment approvals right now." /></div>
          <div v-for="m in pending.slice(0, 4)" :key="m.id" class="list-row">
            <div><div class="main-txt">{{ m.patient_name }}</div><div class="sub-txt">{{ m.label }} · {{ fmtNaira(m.amount) }}</div></div>
            <div class="side flex gap-8">
              <button class="btn btn-secondary btn-sm" @click="reject(m)">Flag</button>
              <button class="btn btn-success btn-sm" @click="approve(m)"><Icon name="check-circle" :size="12" /> Approve</button>
            </div>
          </div>
        </div>
      </div>
      <div style="display:flex; flex-direction:column; gap:18px;">
        <div class="card">
          <div class="card-header"><h3><Icon name="users" :size="15" /> Recent Staff Changes</h3><button class="btn btn-primary btn-sm" @click="$router.push('/admin_manager/staff')"><Icon name="plus" :size="12" /> Add Staff</button></div>
          <div class="card-body tight">
            <div v-for="s in recentStaff" :key="s.id" class="list-row">
              <Avatar :name="s.full_name" :size="30" />
              <div><div class="main-txt">{{ s.full_name }}</div><div class="sub-txt">{{ roleLabelOf(s) }}</div></div>
              <div class="side"><Badge :tone="s.active ? 'blue' : 'gray'">{{ s.active ? 'New Hire' : 'Offboarded' }}</Badge></div>
            </div>
          </div>
        </div>
        <div class="card card-pad">
          <h3 style="font-size:13.5px;"><Icon name="shield" :size="14" /> System Health &amp; Compliance</h3>
          <p class="muted" style="font-size:12px; margin-top:6px;">Offline write queue status.</p>
          <div class="grid grid-2" style="margin-top:12px; gap:10px;">
            <div class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm);"><div class="muted" style="font-size:10.5px;">DATA SYNC</div><div style="font-weight:700;" :style="{ color: pendingWrites === 0 ? 'var(--green-600)' : 'var(--amber-600)' }">{{ pendingWrites === 0 ? '100%' : `${pendingWrites} pending` }}</div></div>
            <div class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm);"><div class="muted" style="font-size:10.5px;">ACTIVE STAFF</div><div style="font-weight:700;">{{ activeStaffCount }}</div></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtNaira } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { ROLE_META } from '~/composables/useRoleMeta'

const supabase = useSupabaseClient()
const { pendingCount, queueOrRun } = useSyncQueue()
const pendingWrites = computed(() => pendingCount.value)

const pending = ref<any[]>([])
const staff = ref<any[]>([])
const patientCount = ref(0)
const activeCyclesCount = ref(0)

await useAsyncData('admin-overview', async () => {
  const [milestonesRes, staffRes, patientsRes, cyclesRes] = await Promise.all([
    supabase.from('payment_milestones').select('*, payment_plans(patient_id, patient_names(full_name))').eq('status', 'Pending Verification'),
    supabase.from('profiles').select('*').not('role', 'is', null).neq('role', 'patient').order('created_at', { ascending: true }),
    supabase.from('patient_names').select('patient_id', { count: 'exact', head: true }),
    supabase.from('cycles').select('id', { count: 'exact', head: true }).eq('status', 'Active'),
  ])
  pending.value = (milestonesRes.data || []).map((m: any) => ({ ...m, patient_name: m.payment_plans?.patient_names?.full_name || 'Unknown' }))
  staff.value = staffRes.data || []
  patientCount.value = patientsRes.count || 0
  activeCyclesCount.value = cyclesRes.count || 0
  return true
})

const activeStaffCount = computed(() => staff.value.filter((s) => s.active).length)
const recentStaff = computed(() => [...staff.value].slice(-3).reverse())

function roleLabelOf(s: any) {
  return ROLE_META[s.role]?.label || s.custom_role_key || s.role
}

async function approve(m: any) {
  await queueOrRun(`${m.patient_name}'s ${m.label} approved`, async () => {
    const { error } = await supabase.rpc('approve_milestone', { p_milestone_id: m.id })
    if (error) throw error
    pending.value = pending.value.filter((x) => x.id !== m.id)
  })
}
async function reject(m: any) {
  await queueOrRun(`${m.patient_name}'s ${m.label} flagged for follow-up`, async () => {
    const { error } = await supabase.rpc('reject_milestone', { p_milestone_id: m.id })
    if (error) throw error
    pending.value = pending.value.filter((x) => x.id !== m.id)
  })
}
</script>
