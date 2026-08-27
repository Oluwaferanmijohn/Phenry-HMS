<template>
  <div>
    <div class="page-header">
      <div><h1>Inventory Ledger &amp; Restocking</h1><div class="desc">Manage central stock, log shipments, and monitor critical thresholds.</div></div>
      <div class="page-actions"><button class="btn btn-danger-solid" @click="toast('Emergency restock request sent to supplier')"><Icon name="alert" :size="14" /> Emergency Restock</button></div>
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="download" :size="15" /> Log New Shipment</h3></div>
        <div class="card-body">
          <div class="field"><label>Select Item</label><select v-model="itemId" class="input"><option v-for="i in inventory" :key="i.id" :value="i.id">{{ i.name }}</option></select></div>
          <div class="field"><label>Quantity Received</label><input v-model.number="qty" class="input" type="number" placeholder="e.g. 500" /></div>
          <div class="field"><label>Batch Number</label><input v-model="batch" class="input" placeholder="e.g. BATCH-2026-X" /></div>
          <div class="field"><label>Expiry Date</label><input v-model="expiry" class="input" type="date" /></div>
          <button class="btn btn-primary btn-block" @click="logShipment"><Icon name="download" :size="13" /> Update Central Inventory</button>
        </div>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="layers" :size="15" /> Master Stock List</h3><span class="link"><Icon name="filter" :size="11" /> Filter</span></div>
        <table class="data-table">
          <thead><tr><th>Item Name</th><th>Current Qty</th><th>Min Threshold</th><th>Status</th></tr></thead>
          <tbody>
            <tr v-for="i in inventory" :key="i.id">
              <td class="cell-strong">{{ i.name }}<div class="cell-muted">{{ i.category }}</div></td>
              <td>{{ i.current_qty.toLocaleString() }}</td>
              <td class="cell-muted">{{ i.min_threshold.toLocaleString() }}</td>
              <td><StatusBadge :status="invStatus(i)" /></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()

const inventory = ref<any[]>([])
const itemId = ref('')
const qty = ref<number | null>(null)
const batch = ref('')
const expiry = ref('')

await useAsyncData('pharmacy-inventory', async () => {
  const { data } = await supabase.from('pharmacy_inventory').select('*').order('name', { ascending: true })
  inventory.value = data || []
  itemId.value = inventory.value[0]?.id || ''
  return true
})

function invStatus(i: any) {
  if (i.current_qty <= i.min_threshold * 0.3) return 'Critical'
  if (i.current_qty < i.min_threshold) return 'Low Stock'
  return 'Adequate'
}

async function logShipment() {
  const item = inventory.value.find((i) => i.id === itemId.value)
  if (!item || !qty.value) {
    toast('Enter quantity received', 'warn')
    return
  }
  const targetItemId = item.id
  const qtyReceived = qty.value
  const baseQty = item.current_qty
  const targetExpiry = expiry.value
  const targetBatch = batch.value
  await queueOrRun(`Shipment logged — ${item.name} +${qtyReceived}`, async () => {
    const patch: any = { current_qty: baseQty + qtyReceived }
    if (targetExpiry) patch.expiry = targetExpiry
    if (targetBatch) patch.batch_number = targetBatch
    const { error } = await supabase.from('pharmacy_inventory').update(patch).eq('id', targetItemId)
    if (error) throw error
    item.current_qty = patch.current_qty
    if (patch.batch_number) item.batch_number = patch.batch_number
    if (patch.expiry) item.expiry = patch.expiry
  })
  qty.value = null
  batch.value = ''
  expiry.value = ''
}
</script>
