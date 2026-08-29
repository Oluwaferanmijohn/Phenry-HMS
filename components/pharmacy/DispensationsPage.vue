<template>
  <div>
    <div class="page-header"><div><h1>Pending Dispensations &amp; Requests</h1><div class="desc">Review and process active pharmacy orders and internal clinic requisitions.</div></div></div>
    <div class="card" style="margin-bottom:18px;">
      <div class="card-header"><h3><Icon name="pill" :size="15" /> Patient Prescriptions</h3><Badge tone="blue">{{ prescriptions.filter((r) => r.status === 'Pending').length }} Pending</Badge></div>
      <table class="data-table">
        <thead><tr><th>Patient ID</th><th>Prescribing Provider</th><th>Medication &amp; Dosage</th><th>Date</th><th>Action</th></tr></thead>
        <tbody>
          <tr v-for="r in prescriptions" :key="r.id">
            <td class="cell-strong">{{ r.patient_name }}<div class="cell-muted mono">{{ r.patient_id }}</div></td>
            <td class="cell-muted">{{ r.prescriber_name }}</td>
            <td>{{ r.medication }}<div class="cell-muted">{{ r.sig }}</div></td>
            <td class="cell-muted">{{ fmtDate(r.date) }}</td>
            <td style="text-align:right;">
              <StatusBadge v-if="r.status === 'Dispensed'" status="Dispensed" />
              <button v-else class="btn btn-primary btn-sm" @click="dispense(r)">Dispense &amp; Deduct</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div class="card">
      <div class="card-header"><h3><Icon name="box" :size="15" /> Internal Requisitions</h3><Badge tone="blue">{{ requisitions.filter((r) => r.status === 'Pending').length }} Requests</Badge></div>
      <table class="data-table">
        <thead><tr><th>Requesting Ward/Staff</th><th>Items Requested</th><th>Urgency</th><th>Actions</th></tr></thead>
        <tbody>
          <tr v-for="r in requisitions" :key="r.id">
            <td class="cell-strong">{{ r.ward }}<div class="cell-muted">{{ r.requester_name }}</div></td>
            <td>{{ (r.items || []).map((i: any) => `${i.name} x${i.qty}`).join(', ') }}</td>
            <td><StatusBadge :status="r.urgency" /></td>
            <td style="text-align:right;">
              <template v-if="r.status === 'Pending'">
                <button class="btn btn-secondary btn-sm" @click="deny(r)">Deny/Out of Stock</button>
                <button class="btn btn-success btn-sm" @click="approve(r)">Approve Request</button>
              </template>
              <StatusBadge v-else :status="r.status" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'
import { matchInventoryItem } from '~/composables/useInventoryMatch'

const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const supabase = useSupabaseClient()

const prescriptions = ref<any[]>([])
const requisitions = ref<any[]>([])
const inventory = ref<any[]>([])

async function load() {
  const [rxRes, reqRes, invRes] = await Promise.all([
    supabase.from('prescriptions').select('*, patient_names(full_name), profiles:prescribed_by_profile_id(full_name)').order('date', { ascending: false }),
    supabase.from('requisitions').select('*, profiles:requested_by_profile_id(full_name)').order('requested_on', { ascending: false }),
    supabase.from('pharmacy_inventory').select('*'),
  ])
  prescriptions.value = (rxRes.data || []).map((r: any) => ({ ...r, patient_name: r.patient_names?.full_name || 'Unknown', prescriber_name: r.profiles?.full_name || 'Staff' }))
  requisitions.value = (reqRes.data || []).map((r: any) => ({ ...r, requester_name: r.profiles?.full_name || 'Staff' }))
  inventory.value = invRes.data || []
}
await useAsyncData('pharmacy-dispensations', load)

async function dispense(r: any) {
  // Resolved up front (synchronous, over data already loaded) so the queued
  // write is plain data — the inventory match itself can't be redone later
  // from a stale snapshot.
  const inv = matchInventoryItem(inventory.value, r.medication)
  const newQty = inv ? Math.max(0, inv.current_qty - 1) : null
  await queueOrRun(
    `${r.medication} dispensed to ${r.patient_name}`,
    [
      { table: 'prescriptions', kind: 'update', payload: { status: 'Dispensed' }, match: { id: r.id } },
      ...(inv ? [{ table: 'pharmacy_inventory', kind: 'update' as const, payload: { current_qty: newQty }, match: { id: inv.id } }] : []),
    ],
    () => {
      if (inv) inv.current_qty = newQty
      else toast(`No inventory match for "${r.medication}" — stock not adjusted`, 'warn')
      r.status = 'Dispensed'
    }
  )
}

async function approve(r: any) {
  // Same reasoning as dispense() — resolve every inventory match and its
  // resulting quantity up front. Tracked via a running per-item map (rather
  // than mutating inventory.value directly here) so two requisition lines
  // for the same item still deduct cumulatively, exactly as the sequential
  // version did.
  const items = r.items || []
  const matched: { inv: any; newQty: number }[] = []
  const unmatchedNames: string[] = []
  const runningQty = new Map<string, number>()
  for (const it of items) {
    const inv = matchInventoryItem(inventory.value, it.name)
    if (inv) {
      const currentQty = runningQty.has(inv.id) ? runningQty.get(inv.id)! : inv.current_qty
      const newQty = Math.max(0, currentQty - Number(it.qty || 1))
      runningQty.set(inv.id, newQty)
      matched.push({ inv, newQty })
    } else {
      unmatchedNames.push(it.name)
    }
  }
  await queueOrRun(
    'Requisition approved and deducted from stock',
    [
      { table: 'requisitions', kind: 'update', payload: { status: 'Approved & Dispensed' }, match: { id: r.id } },
      ...matched.map(({ inv, newQty }) => ({ table: 'pharmacy_inventory', kind: 'update' as const, payload: { current_qty: newQty }, match: { id: inv.id } })),
    ],
    () => {
      matched.forEach(({ inv, newQty }) => { inv.current_qty = newQty })
      unmatchedNames.forEach((name) => toast(`No inventory match for "${name}" — stock not adjusted`, 'warn'))
      r.status = 'Approved & Dispensed'
    }
  )
}

async function deny(r: any) {
  await queueOrRun(
    'Requisition denied — out of stock',
    { table: 'requisitions', kind: 'update', payload: { status: 'Denied / Out of Stock' }, match: { id: r.id } },
    () => { r.status = 'Denied / Out of Stock' }
  )
}
</script>
