<template>
  <div class="lab-operations">
    <div class="page-header">
      <div><h1>Lab Equipment &amp; Store</h1><div class="desc">Manage incubator QC, laboratory assets, supplies, media, reagents, and test kits.</div></div>
      <div class="page-actions">
        <button v-if="tab === 'equipment'" class="btn btn-primary" @click="openEquipment()"><Icon name="plus" :size="14" /> Add equipment</button>
        <button v-if="tab === 'store'" class="btn btn-primary" @click="openStoreItem()"><Icon name="plus" :size="14" /> Add store item</button>
      </div>
    </div>

    <div class="asset-stats">
      <div class="card mini-stat"><span class="stat-icon"><Icon name="thermo" :size="17" /></span><div><b>{{ incubators.length }}</b><small>Incubators</small></div></div>
      <div class="card mini-stat"><span class="stat-icon"><Icon name="settings" :size="17" /></span><div><b>{{ equipment.length }}</b><small>Equipment assets</small></div></div>
      <div class="card mini-stat"><span class="stat-icon"><Icon name="box" :size="17" /></span><div><b>{{ store.length }}</b><small>Store items</small></div></div>
      <div class="card mini-stat" :class="{ alert: attentionCount > 0 }"><span class="stat-icon"><Icon name="alert" :size="17" /></span><div><b>{{ attentionCount }}</b><small>Need attention</small></div></div>
    </div>

    <div class="tabs section-tabs">
      <button class="tab" :class="{ active: tab === 'incubators' }" @click="tab = 'incubators'">Daily Incubator QC</button>
      <button class="tab" :class="{ active: tab === 'equipment' }" @click="tab = 'equipment'">Equipment Register</button>
      <button class="tab" :class="{ active: tab === 'store' }" @click="tab = 'store'">Supplies &amp; Kits</button>
    </div>

    <div v-if="tab === 'incubators'" class="card">
      <div class="card-header"><h3><Icon name="thermo" :size="15" /> Daily readings</h3><Badge tone="blue">{{ incubators.length }} units</Badge></div>
      <div v-if="incubators.length" class="scroll-x"><table class="data-table">
        <thead><tr><th>Unit</th><th>Location</th><th>Temp °C</th><th>CO₂ %</th><th>O₂ %</th><th>Humidity %</th><th>Status</th><th>Last checked</th><th /></tr></thead>
        <tbody><tr v-for="unit in incubators" :key="unit.id">
          <td class="cell-strong">{{ unit.name }}</td><td class="cell-muted">{{ unit.location || '—' }}</td>
          <td><input v-model.number="unit.temp" class="input reading-input" type="number" step="0.1" /></td><td><input v-model.number="unit.co2" class="input reading-input" type="number" step="0.1" /></td><td><input v-model.number="unit.o2" class="input reading-input" type="number" step="0.1" /></td><td><input v-model.number="unit.humidity" class="input reading-input" type="number" step="0.1" /></td>
          <td><StatusBadge :status="unit.status" /></td><td class="cell-muted">{{ unit.last_checked ? fmtDate(unit.last_checked) : 'Not recorded' }}</td>
          <td><div class="row-actions"><button class="btn btn-success btn-sm" @click="logCheck(unit, 'Pass')">Pass</button><button class="btn btn-danger btn-sm" @click="logCheck(unit, 'Fail')">Fail</button></div></td>
        </tr></tbody>
      </table></div>
      <EmptyState v-else icon="thermo" title="No incubators registered" description="Ask the chief embryologist to configure the laboratory incubator units." />
    </div>

    <div v-else-if="tab === 'equipment'" class="card">
      <div class="card-header"><h3><Icon name="settings" :size="15" /> Equipment register</h3><Badge tone="blue">{{ equipment.length }} assets</Badge></div>
      <div v-if="equipment.length" class="scroll-x"><table class="data-table">
        <thead><tr><th>Asset</th><th>Identification</th><th>Location</th><th>Service dates</th><th>Status</th><th /></tr></thead>
        <tbody><tr v-for="item in equipment" :key="item.id">
          <td><div class="cell-strong">{{ item.name }}</div><div class="cell-muted">{{ item.category || 'Uncategorised' }}</div></td>
          <td><div>{{ item.asset_code || 'No asset code' }}</div><div class="cell-muted">{{ equipmentIdentity(item) }}</div></td><td class="cell-muted">{{ item.location || '—' }}</td>
          <td><div>{{ item.last_serviced ? `Last: ${fmtDate(item.last_serviced)}` : 'No service recorded' }}</div><div class="cell-muted">{{ item.next_service_due ? `Next: ${fmtDate(item.next_service_due)}` : 'No next date' }}</div></td>
          <td><StatusBadge :status="equipmentStatus(item)" /></td><td><button class="icon-btn" title="Edit equipment" @click="openEquipment(item)"><Icon name="edit" :size="14" /></button></td>
        </tr></tbody>
      </table></div>
      <EmptyState v-else icon="settings" title="No equipment documented" description="Add the laboratory's first equipment asset to begin tracking identity and servicing." />
    </div>

    <div v-else class="card">
      <div class="card-header"><h3><Icon name="box" :size="15" /> Laboratory store</h3><Badge tone="blue">{{ store.length }} items</Badge></div>
      <div v-if="store.length" class="scroll-x"><table class="data-table">
        <thead><tr><th>Item</th><th>Type</th><th>Stock</th><th>Lot / Expiry</th><th>Storage</th><th>Status</th><th /></tr></thead>
        <tbody><tr v-for="item in store" :key="item.id">
          <td><div class="cell-strong">{{ item.name }}</div><div class="cell-muted">{{ item.manufacturer || item.category || '—' }}</div></td><td><Badge tone="purple">{{ item.item_type || 'Supply' }}</Badge></td>
          <td><div class="cell-strong">{{ item.current_qty }} {{ item.unit }}</div><div class="cell-muted">Minimum {{ item.min_threshold }} {{ item.unit }}</div></td>
          <td><div>{{ item.lot_number || 'No lot recorded' }}</div><div class="cell-muted">{{ item.expiry_date ? `Expires ${fmtDate(item.expiry_date)}` : 'No expiry recorded' }}</div></td><td class="cell-muted">{{ item.location || '—' }}</td>
          <td><StatusBadge :status="storeStatus(item)" /></td><td><button class="icon-btn" title="Edit store item" @click="openStoreItem(item)"><Icon name="edit" :size="14" /></button></td>
        </tr></tbody>
      </table></div>
      <EmptyState v-else icon="box" title="The laboratory store is empty" description="Document supplies, media, reagents, and kits here—not in pharmacy inventory." />
    </div>

    <Modal v-model="showEquipment" :title="editingEquipmentId ? 'Edit Equipment' : 'Add Equipment'" wide>
      <div class="form-row"><div class="field"><label>Equipment name</label><input v-model="equipmentForm.name" class="input" placeholder="e.g. Benchtop incubator" /></div><div class="field"><label>Category</label><input v-model="equipmentForm.category" class="input" list="equipment-categories" placeholder="e.g. Incubation" /></div></div>
      <datalist id="equipment-categories"><option value="Incubation" /><option value="Microscopy" /><option value="Micromanipulation" /><option value="Cryopreservation" /><option value="Air Handling" /><option value="General Lab" /></datalist>
      <div class="form-row"><div class="field"><label>Asset code</label><input v-model="equipmentForm.assetCode" class="input" placeholder="e.g. LAB-EQ-014" /></div><div class="field"><label>Serial number</label><input v-model="equipmentForm.serialNumber" class="input" /></div></div>
      <div class="form-row"><div class="field"><label>Manufacturer</label><input v-model="equipmentForm.manufacturer" class="input" /></div><div class="field"><label>Model</label><input v-model="equipmentForm.model" class="input" /></div></div>
      <div class="form-row"><div class="field"><label>Location</label><input v-model="equipmentForm.location" class="input" placeholder="e.g. Embryology Lab Bay A" /></div><div class="field"><label>Status</label><select v-model="equipmentForm.status" class="input"><option>OK</option><option>Due Soon</option><option>Overdue</option></select></div></div>
      <div class="form-row"><div class="field"><label>Purchase date</label><input v-model="equipmentForm.purchaseDate" class="input" type="date" /></div><div class="field"><label>Last serviced</label><input v-model="equipmentForm.lastServiced" class="input" type="date" /></div><div class="field"><label>Next service due</label><input v-model="equipmentForm.nextServiceDue" class="input" type="date" /></div></div>
      <div class="field"><label>Notes</label><textarea v-model="equipmentForm.notes" class="input" rows="3" placeholder="Service provider, calibration notes, operating condition…" /></div>
      <template #footer><button class="btn btn-secondary" @click="showEquipment = false">Cancel</button><button class="btn btn-primary" :disabled="savingAsset" @click="saveEquipment"><Icon name="check-circle" :size="13" /> Save equipment</button></template>
    </Modal>

    <Modal v-model="showStoreItem" :title="editingStoreId ? 'Edit Store Item' : 'Add Store Item'" wide>
      <div class="form-row"><div class="field"><label>Item name</label><input v-model="storeForm.name" class="input" placeholder="e.g. Blastocyst culture medium" /></div><div class="field"><label>Item type</label><select v-model="storeForm.itemType" class="input"><option>Supply</option><option>Consumable</option><option>Kit</option><option>Reagent</option><option>Culture Media</option><option>QC Material</option></select></div></div>
      <div class="form-row"><div class="field"><label>Category</label><input v-model="storeForm.category" class="input" placeholder="e.g. Embryo culture" /></div><div class="field"><label>Manufacturer</label><input v-model="storeForm.manufacturer" class="input" /></div></div>
      <div class="form-row"><div class="field"><label>Quantity on hand</label><input v-model.number="storeForm.currentQty" class="input" type="number" min="0" step="1" /></div><div class="field"><label>Unit</label><input v-model="storeForm.unit" class="input" list="lab-unit-options" placeholder="e.g. boxes" /></div><div class="field"><label>Minimum threshold</label><input v-model.number="storeForm.minThreshold" class="input" type="number" min="0" step="1" /></div></div>
      <datalist id="lab-unit-options"><option value="units" /><option value="boxes" /><option value="packs" /><option value="bottles" /><option value="vials" /><option value="kits" /><option value="straws" /><option value="dishes" /><option value="pipettes" /></datalist>
      <div class="form-row"><div class="field"><label>Lot / batch number</label><input v-model="storeForm.lotNumber" class="input" /></div><div class="field"><label>Received on</label><input v-model="storeForm.receivedOn" class="input" type="date" /></div><div class="field"><label>Expiry date</label><input v-model="storeForm.expiryDate" class="input" type="date" /></div></div>
      <div class="field"><label>Storage location</label><input v-model="storeForm.location" class="input" placeholder="e.g. Media fridge 2, shelf B" /></div><div class="field"><label>Notes</label><textarea v-model="storeForm.notes" class="input" rows="3" placeholder="Storage conditions, opened date, supplier, or handling notes…" /></div>
      <template #footer><button class="btn btn-secondary" @click="showStoreItem = false">Cancel</button><button class="btn btn-primary" :disabled="savingAsset" @click="saveStoreItem"><Icon name="check-circle" :size="13" /> Save store item</button></template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'
import { useToast } from '~/composables/useToast'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()
const today = new Date().toISOString().slice(0, 10)
const tab = ref<'incubators' | 'equipment' | 'store'>('incubators')
const incubators = ref<any[]>([])
const equipment = ref<any[]>([])
const store = ref<any[]>([])
const showEquipment = ref(false)
const showStoreItem = ref(false)
const editingEquipmentId = ref('')
const editingStoreId = ref('')
const savingAsset = ref(false)
const equipmentForm = reactive({ name: '', category: '', assetCode: '', serialNumber: '', manufacturer: '', model: '', location: '', status: 'OK', purchaseDate: '', lastServiced: '', nextServiceDue: '', notes: '' })
const storeForm = reactive({ name: '', itemType: 'Supply', category: '', manufacturer: '', currentQty: 0 as number | null, unit: 'units', minThreshold: 10 as number | null, lotNumber: '', receivedOn: '', expiryDate: '', location: '', notes: '' })

await useAsyncData(`lab-operations-${props.role}-${profile.value?.id || 'anonymous'}`, async () => {
  const [incubatorResult, equipmentResult, storeResult] = await Promise.all([
    supabase.from('incubator_logs').select('*').order('name', { ascending: true }), supabase.from('lab_equipment').select('*').order('name', { ascending: true }), supabase.from('lab_store').select('*').order('name', { ascending: true }),
  ])
  incubators.value = incubatorResult.data || []; equipment.value = equipmentResult.data || []; store.value = storeResult.data || []
  return true
}, { getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined })

const attentionCount = computed(() => equipment.value.filter((item) => equipmentStatus(item) !== 'OK').length + store.value.filter((item) => storeStatus(item) !== 'Adequate').length)
function equipmentStatus(item: any) {
  if (item.next_service_due && item.next_service_due < today) return 'Overdue'
  if (item.next_service_due && new Date(`${item.next_service_due}T00:00:00`).getTime() - Date.now() <= 30 * 86400000) return 'Due Soon'
  return item.status || 'OK'
}
function storeStatus(item: any) { if (item.expiry_date && item.expiry_date < today) return 'Expired'; return Number(item.current_qty) <= Number(item.min_threshold) ? 'Low Stock' : 'Adequate' }
function equipmentIdentity(item: any) { return [item.manufacturer, item.model, item.serial_number ? `S/N ${item.serial_number}` : ''].filter(Boolean).join(' · ') || 'No identity details' }
function sortByName(rows: any[]) { return [...rows].sort((a, b) => a.name.localeCompare(b.name)) }

async function logCheck(unit: any, status: string) {
  const checkedAt = new Date().toISOString()
  await queueOrRun(`${unit.name} logged as ${status}`, { table: 'incubator_logs', kind: 'update', payload: { temp: unit.temp, co2: unit.co2, o2: unit.o2, humidity: unit.humidity, status, last_checked: checkedAt, checked_by: profile.value!.id }, match: { id: unit.id } })
  unit.status = status; unit.last_checked = checkedAt
}
function openEquipment(item?: any) {
  editingEquipmentId.value = item?.id || ''
  Object.assign(equipmentForm, { name: item?.name || '', category: item?.category || '', assetCode: item?.asset_code || '', serialNumber: item?.serial_number || '', manufacturer: item?.manufacturer || '', model: item?.model || '', location: item?.location || '', status: item?.status || 'OK', purchaseDate: item?.purchase_date || '', lastServiced: item?.last_serviced || '', nextServiceDue: item?.next_service_due || '', notes: item?.notes || '' })
  showEquipment.value = true
}
async function saveEquipment() {
  const name = equipmentForm.name.trim(); if (!name) return toast('Enter the equipment name', 'warn')
  const payload = { name, category: equipmentForm.category.trim() || null, asset_code: equipmentForm.assetCode.trim() || null, serial_number: equipmentForm.serialNumber.trim() || null, manufacturer: equipmentForm.manufacturer.trim() || null, model: equipmentForm.model.trim() || null, location: equipmentForm.location.trim() || null, status: equipmentForm.status, purchase_date: equipmentForm.purchaseDate || null, last_serviced: equipmentForm.lastServiced || null, next_service_due: equipmentForm.nextServiceDue || null, notes: equipmentForm.notes.trim() || null }
  savingAsset.value = true
  try {
    if (editingEquipmentId.value) { await queueOrRun(`${name} equipment record updated`, { table: 'lab_equipment', kind: 'update', payload, match: { id: editingEquipmentId.value } }); const index = equipment.value.findIndex((item) => item.id === editingEquipmentId.value); if (index !== -1) equipment.value[index] = { ...equipment.value[index], ...payload } }
    else { const item = { id: crypto.randomUUID(), ...payload }; await queueOrRun(`${name} added to lab equipment`, { table: 'lab_equipment', kind: 'insert', payload: item }); equipment.value = sortByName([...equipment.value, item]) }
    showEquipment.value = false
  } finally { savingAsset.value = false }
}
function openStoreItem(item?: any) {
  editingStoreId.value = item?.id || ''
  Object.assign(storeForm, { name: item?.name || '', itemType: item?.item_type || 'Supply', category: item?.category || '', manufacturer: item?.manufacturer || '', currentQty: item?.current_qty ?? 0, unit: item?.unit || 'units', minThreshold: item?.min_threshold ?? 10, lotNumber: item?.lot_number || '', receivedOn: item?.received_on || '', expiryDate: item?.expiry_date || '', location: item?.location || '', notes: item?.notes || '' })
  showStoreItem.value = true
}
async function saveStoreItem() {
  const name = storeForm.name.trim(), currentQty = Number(storeForm.currentQty), minThreshold = Number(storeForm.minThreshold)
  if (!name || !storeForm.unit.trim()) return toast('Enter the item name and stock unit', 'warn')
  if (!Number.isInteger(currentQty) || currentQty < 0 || !Number.isInteger(minThreshold) || minThreshold < 0) return toast('Stock quantities must be whole numbers of zero or more', 'warn')
  if (storeForm.receivedOn && storeForm.expiryDate && storeForm.expiryDate < storeForm.receivedOn) return toast('Expiry date cannot be before the received date', 'warn')
  const payload = { name, item_type: storeForm.itemType, category: storeForm.category.trim() || null, manufacturer: storeForm.manufacturer.trim() || null, current_qty: currentQty, unit: storeForm.unit.trim(), min_threshold: minThreshold, lot_number: storeForm.lotNumber.trim() || null, received_on: storeForm.receivedOn || null, expiry_date: storeForm.expiryDate || null, location: storeForm.location.trim() || null, notes: storeForm.notes.trim() || null }
  savingAsset.value = true
  try {
    if (editingStoreId.value) { await queueOrRun(`${name} store record updated`, { table: 'lab_store', kind: 'update', payload, match: { id: editingStoreId.value } }); const index = store.value.findIndex((item) => item.id === editingStoreId.value); if (index !== -1) store.value[index] = { ...store.value[index], ...payload } }
    else { const item = { id: crypto.randomUUID(), ...payload }; await queueOrRun(`${name} added to laboratory store`, { table: 'lab_store', kind: 'insert', payload: item }); store.value = sortByName([...store.value, item]) }
    showStoreItem.value = false
  } finally { savingAsset.value = false }
}
</script>

<style scoped>
.lab-operations { max-width: 1280px; margin: 0 auto; }
.asset-stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 16px; }
.mini-stat { display: flex; align-items: center; gap: 11px; padding: 14px 16px; }
.stat-icon { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 9px; background: var(--blue-50); color: var(--blue-600); }
.mini-stat div { display: flex; flex-direction: column; }.mini-stat b { font-size: 19px; }.mini-stat small { color: var(--text-500); font-size: 11px; }.mini-stat.alert .stat-icon { color: var(--amber-600); background: var(--amber-50); }
.section-tabs { margin-bottom: 16px; }.section-tabs .tab { border-top: 0; border-left: 0; border-right: 0; background: transparent; }.reading-input { width: 72px; }.row-actions { display: flex; gap: 6px; justify-content: flex-end; }
@media (max-width: 900px) { .asset-stats { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 560px) { .asset-stats { grid-template-columns: 1fr; } }
</style>
