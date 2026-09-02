<template>
  <div>
    <div class="page-header">
      <div><h1>Inventory Ledger &amp; Restocking</h1><div class="desc">Manage central stock, log shipments, and monitor critical thresholds.</div></div>
      <div class="page-actions">
        <button class="btn btn-secondary" disabled title="Barcode and package scanning is coming soon"><Icon name="search" :size="14" /> Scan Drug · Coming Soon</button>
        <button class="btn btn-primary" @click="openNewDrug"><Icon name="plus" :size="14" /> Add New Drug</button>
        <button class="btn btn-danger-solid" @click="showEmergency = true"><Icon name="alert" :size="14" /> Emergency Restock</button>
      </div>
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
        <div class="card-header"><h3><Icon name="layers" :size="15" /> Master Stock List</h3><Badge tone="blue">{{ inventory.length }} Items</Badge></div>
        <div v-if="!inventory.length" style="padding:18px;"><EmptyState icon="box" title="No inventory items" description="Add your first drug or inventory item manually to begin tracking stock." /></div>
        <div v-else class="scroll-x">
          <table class="data-table">
            <thead><tr><th>Item Name</th><th>Current Qty</th><th>Min Threshold</th><th>Batch &amp; Expiry</th><th>Location</th><th>Status</th></tr></thead>
            <tbody>
              <tr v-for="i in inventory" :key="i.id">
                <td class="cell-strong">{{ i.name }}<div class="cell-muted">{{ i.category || 'Uncategorised' }}</div></td>
                <td>{{ i.current_qty.toLocaleString() }} <span class="cell-muted">{{ i.unit }}</span></td>
                <td class="cell-muted">{{ i.min_threshold.toLocaleString() }} {{ i.unit }}</td>
                <td><div>{{ i.batch_number || '—' }}</div><div class="cell-muted">{{ i.expiry ? `Expires ${fmtDate(i.expiry)}` : 'No expiry recorded' }}</div></td>
                <td class="cell-muted">{{ i.location || '—' }}</td>
                <td><StatusBadge :status="invStatus(i)" /></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    <Modal :model-value="showNewDrug" title="Add New Drug to Inventory" wide @update:model-value="setNewDrugModal">
      <div style="padding:10px 12px; margin-bottom:14px; border:1px solid var(--blue-100); border-radius:var(--radius-sm); background:var(--blue-50); font-size:12px; color:var(--text-700);">
        Enter the product details manually now. Barcode lookup can work without AI; package-text recognition can be added as an AI-assisted option later.
      </div>
      <div class="field"><label>Drug / Product Name and Strength</label><input v-model="newDrug.name" class="input" maxlength="160" placeholder="e.g. Gonal-F 900 IU pre-filled pen" /></div>
      <div class="form-row">
        <div class="field"><label>Category</label><input v-model="newDrug.category" class="input" maxlength="80" placeholder="e.g. Gonadotropins" /></div>
        <div class="field">
          <label>Stock Unit</label>
          <input v-model="newDrug.unit" class="input" maxlength="40" list="inventory-unit-options" placeholder="e.g. pens, vials, packs" />
          <datalist id="inventory-unit-options"><option value="units" /><option value="packs" /><option value="boxes" /><option value="bottles" /><option value="vials" /><option value="ampoules" /><option value="tablets" /><option value="capsules" /><option value="pens" /><option value="syringes" /><option value="tubes" /><option value="sachets" /></datalist>
        </div>
      </div>
      <div class="form-row">
        <div class="field"><label>Opening Quantity</label><input v-model.number="newDrug.currentQty" class="input" type="number" min="0" step="1" /></div>
        <div class="field"><label>Low-stock Threshold</label><input v-model.number="newDrug.minThreshold" class="input" type="number" min="0" step="1" /></div>
      </div>
      <div class="form-row">
        <div class="field"><label>Batch Number</label><input v-model="newDrug.batch" class="input" maxlength="80" placeholder="e.g. BATCH-2026-X" /></div>
        <div class="field"><label>Expiry Date</label><input v-model="newDrug.expiry" class="input" type="date" :min="today" /></div>
      </div>
      <div class="field"><label>Storage Location</label><input v-model="newDrug.location" class="input" maxlength="120" placeholder="e.g. Cold Storage A" /></div>
      <template #footer>
        <button class="btn btn-secondary" @click="setNewDrugModal(false)">Cancel</button>
        <button class="btn btn-primary" :disabled="savingNewDrug" @click="addNewDrug"><Icon name="plus" :size="13" /> Add to Inventory</button>
      </template>
    </Modal>
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
import { reactive, ref } from 'vue'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'
import { fmtDate } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()
const profile = useProfile()
const route = useRoute()
const router = useRouter()

const inventory = ref<any[]>([])
const itemId = ref('')
const qty = ref<number | null>(null)
const batch = ref('')
const expiry = ref('')
const today = new Date().toISOString().slice(0, 10)
const showNewDrug = ref(route.query.new === '1')
const savingNewDrug = ref(false)
const newDrug = reactive({
  name: '',
  category: '',
  unit: 'units',
  currentQty: 0 as number | null,
  minThreshold: 20 as number | null,
  batch: '',
  expiry: '',
  location: '',
})
const showEmergency = ref(false)
const emergencyItemId = ref('')
const emergencyQty = ref<number | null>(null)
const emergencyNotes = ref('')

await useAsyncData(`pharmacy-inventory-${profile.value?.id || 'anonymous'}`, async () => {
  const { data } = await supabase.from('pharmacy_inventory').select('*').order('name', { ascending: true })
  inventory.value = data || []
  itemId.value = inventory.value[0]?.id || ''
  emergencyItemId.value = inventory.value[0]?.id || ''
  return true
}, {
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

function invStatus(i: any) {
  if (i.expiry && i.expiry < today) return 'Expired'
  if (i.current_qty <= i.min_threshold * 0.3) return 'Critical'
  if (i.current_qty < i.min_threshold) return 'Low Stock'
  return 'Adequate'
}

function openNewDrug() {
  showNewDrug.value = true
}

function resetNewDrug() {
  Object.assign(newDrug, {
    name: '',
    category: '',
    unit: 'units',
    currentQty: 0,
    minThreshold: 20,
    batch: '',
    expiry: '',
    location: '',
  })
}

function setNewDrugModal(open: boolean) {
  showNewDrug.value = open
  if (!open && route.query.new === '1') {
    const query = { ...route.query }
    delete query.new
    void router.replace({ query })
  }
}

function addItemToInventory(item: any) {
  if (!inventory.value.some((existing) => existing.id === item.id)) {
    inventory.value = [...inventory.value, item].sort((a, b) => a.name.localeCompare(b.name))
  }
  itemId.value = item.id
  if (!emergencyItemId.value) emergencyItemId.value = item.id
}

async function addNewDrug() {
  const name = newDrug.name.trim()
  const unit = newDrug.unit.trim()
  const currentQty = Number(newDrug.currentQty)
  const minThreshold = Number(newDrug.minThreshold)

  if (!name || !unit) {
    toast('Enter the drug name and stock unit', 'warn')
    return
  }
  if (!Number.isInteger(currentQty) || currentQty < 0 || !Number.isInteger(minThreshold) || minThreshold < 0) {
    toast('Opening quantity and low-stock threshold must be whole numbers of zero or more', 'warn')
    return
  }
  if (newDrug.expiry && newDrug.expiry < today) {
    toast('Expiry date cannot be in the past', 'warn')
    return
  }
  if (inventory.value.some((item) => item.name.trim().toLowerCase() === name.toLowerCase())) {
    toast(`"${name}" is already in inventory; use Log New Shipment to add stock`, 'warn')
    return
  }

  const item = {
    id: crypto.randomUUID(),
    name,
    category: newDrug.category.trim() || null,
    current_qty: currentQty,
    unit,
    min_threshold: minThreshold,
    location: newDrug.location.trim() || null,
    batch_number: newDrug.batch.trim() || null,
    expiry: newDrug.expiry || null,
  }

  savingNewDrug.value = true
  try {
    await queueOrRun(
      `${name} added to pharmacy inventory`,
      { table: 'pharmacy_inventory', kind: 'insert', payload: item },
      () => addItemToInventory(item),
    )
    addItemToInventory(item)
    resetNewDrug()
    setNewDrugModal(false)
  } finally {
    savingNewDrug.value = false
  }
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
