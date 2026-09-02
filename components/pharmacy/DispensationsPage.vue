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
  const inv = matchInventoryItem(inventory.value, r.medication)
  if (!inv) return toast(`No inventory item matches "${r.medication}"; dispensing was not recorded`, 'warn')
  await queueOrRun(
    `${r.medication} dispensed to ${r.patient_name}`,
    { kind: 'rpc', rpcName: 'dispense_prescription', payload: { p_prescription_id: r.id, p_inventory_id: inv.id, p_quantity: 1 } },
    () => { r.status = 'Dispensed'; inv.current_qty = Math.max(0, inv.current_qty - 1) },
  )
}

async function approve(r: any) {
  await queueOrRun(
    'Requisition approved and deducted from stock',
    { kind: 'rpc', rpcName: 'approve_requisition', payload: { p_requisition_id: r.id } },
    () => { r.status = 'Approved & Dispensed'; void load() },
  )
}

async function deny(r: any) {
  await queueOrRun(
    'Requisition denied — out of stock',
    { kind: 'rpc', rpcName: 'deny_requisition', payload: { p_requisition_id: r.id, p_reason: 'Out of stock' } },
    () => { r.status = 'Denied / Out of Stock' },
  )
}
</script>
