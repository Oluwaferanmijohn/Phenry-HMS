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
          <div class="card-header"><h3><Icon name="shield" :size="15" /> Recent Staff Changes</h3><button class="btn btn-primary btn-sm" @click="$router.push('/admin_manager/staff')"><Icon name="plus" :size="12" /> Add Staff</button></div>
          <div class="card-body tight">
            <p v-if="!recentStaffChanges.length" class="muted" style="font-size:12px; padding:16px 20px;">No staff changes logged yet.</p>
            <div v-for="e in recentStaffChanges" :key="e.id" class="list-row">
              <Avatar :name="e.staff_name" :size="30" />
              <div><div class="main-txt">{{ e.staff_name }}</div><div class="sub-txt">{{ e.action_type }}{{ e.target ? ' — ' + e.target : '' }}</div></div>
              <div class="side cell-muted">{{ fmtDate(e.created_at) }}</div>
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
import { fmtNaira, fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { pendingCount, queueOrRun } = useSyncQueue()
const pendingWrites = computed(() => pendingCount.value)

const pending = ref<any[]>([])
const staff = ref<any[]>([])
const patientCount = ref(0)
const activeCyclesCount = ref(0)
const recentStaffChanges = ref<any[]>([])

const STAFF_ACTION_TYPES = ['Created Staff Account', 'Revoked Staff Access', 'Reinstated Staff Access', 'Changed Staff Role']

await useAsyncData('admin-overview', async () => {
  const [milestonesRes, staffRes, patientsRes, cyclesRes, auditRes] = await Promise.all([
    supabase.from('payment_milestones').select('*, payment_plans(patient_id, patient_names(full_name))').eq('status', 'Pending Verification'),
    supabase.from('profiles').select('*').not('role', 'is', null).neq('role', 'patient').order('created_at', { ascending: true }),
    supabase.from('patient_names').select('patient_id', { count: 'exact', head: true }),
    supabase.from('cycles').select('id', { count: 'exact', head: true }).eq('status', 'Active'),
    supabase.from('audit_log').select('*').in('action_type', STAFF_ACTION_TYPES).order('created_at', { ascending: false }).limit(5),
  ])
  pending.value = (milestonesRes.data || []).map((m: any) => ({ ...m, patient_name: m.payment_plans?.patient_names?.full_name || 'Unknown' }))
  staff.value = staffRes.data || []
  patientCount.value = patientsRes.count || 0
  activeCyclesCount.value = cyclesRes.count || 0
  recentStaffChanges.value = auditRes.data || []
  return true
})

const activeStaffCount = computed(() => staff.value.filter((s) => s.active).length)

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
