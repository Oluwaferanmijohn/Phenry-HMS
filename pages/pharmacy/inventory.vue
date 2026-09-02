<template>
  <div>
    <div class="page-header">
      <div><h1>Inventory Ledger &amp; Restocking</h1><div class="desc">Manage central stock, log shipments, and monitor critical thresholds.</div></div>
      <div class="page-actions"><button class="btn btn-danger-solid" @click="showEmergency = true"><Icon name="alert" :size="14" /> Emergency Restock</button></div>
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
    <Modal v-model="showEmergency" title="Emergency Supplier Request">
      <div class="field"><label>Inventory Item</label><select v-model="emergencyItemId" class="input"><option v-for="i in inventory" :key="i.id" :value="i.id">{{ i.name }} ({{ i.current_qty }} remaining)</option></select></div>
      <div class="field"><label>Quantity Requested</label><input v-model.number="emergencyQty" class="input" type="number" min="1" /></div>
      <div class="field"><label>Notes</label><textarea v-model="emergencyNotes" class="input" rows="3" placeholder="Supplier or delivery instructions" /></div>
      <template #footer>
        <button class="btn btn-secondary" @click="showEmergency = false">Cancel</button>
        <button class="btn btn-danger-solid" :disabled="!emergencyItemId || !emergencyQty" @click="requestEmergencyRestock">Create Request</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()
const profile = useProfile()

const inventory = ref<any[]>([])
const itemId = ref('')
const qty = ref<number | null>(null)
const batch = ref('')
const expiry = ref('')
const showEmergency = ref(false)
const emergencyItemId = ref('')
const emergencyQty = ref<number | null>(null)
const emergencyNotes = ref('')

await useAsyncData('pharmacy-inventory', async () => {
  const { data } = await supabase.from('pharmacy_inventory').select('*').order('name', { ascending: true })
  inventory.value = data || []
  itemId.value = inventory.value[0]?.id || ''
  emergencyItemId.value = inventory.value[0]?.id || ''
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
  const targetExpiry = expiry.value
  const targetBatch = batch.value
  await queueOrRun(
    `Shipment logged — ${item.name} +${qtyReceived}`,
    {
      kind: 'rpc',
      rpcName: 'receive_pharmacy_stock',
      payload: { p_inventory_id: targetItemId, p_quantity: qtyReceived, p_batch_number: targetBatch || null, p_expiry: targetExpiry || null },
    },
    () => {
      item.current_qty += qtyReceived
      if (targetBatch) item.batch_number = targetBatch
      if (targetExpiry) item.expiry = targetExpiry
    },
  )
  qty.value = null
  batch.value = ''
  expiry.value = ''
}

async function requestEmergencyRestock() {
  const item = inventory.value.find((row) => row.id === emergencyItemId.value)
  if (!item || !emergencyQty.value || emergencyQty.value < 1) return
  await queueOrRun('Emergency supplier request created', {
    table: 'supplier_requests',
    kind: 'insert',
    payload: {
      id: crypto.randomUUID(),
      inventory_id: item.id,
      item_name: item.name,
      requested_quantity: emergencyQty.value,
      priority: 'Emergency',
      requested_by: profile.value!.id,
      notes: emergencyNotes.value || null,
    },
  })
  showEmergency.value = false
  emergencyQty.value = null
  emergencyNotes.value = ''
}
</script>
