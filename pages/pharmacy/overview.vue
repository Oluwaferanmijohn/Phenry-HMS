<template>
  <div>
    <div class="page-header"><div><h1>Pharmacy &amp; Inventory Manager</h1><div class="desc">Real-time medication stock, prescription queues, and internal requisitions.</div></div></div>
    <div class="grid grid-main-side">
      <div style="display:flex; flex-direction:column; gap:18px;">
        <div class="card">
          <div class="card-header"><h3><Icon name="alert" :size="15" /> Critical Stock Alerts</h3><Badge tone="red">{{ critical.length }} Items Action Required</Badge></div>
          <div class="card-body tight">
            <div v-for="i in critical.slice(0, 5)" :key="i.id" class="list-row">
              <div class="icon-wrap" style="width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;" :style="{ background: invStatus(i) === 'Critical' ? 'var(--red-50)' : 'var(--amber-50)', color: invStatus(i) === 'Critical' ? 'var(--red-600)' : 'var(--amber-600)' }">
                <Icon name="alert" :size="14" />
              </div>
              <div><div class="main-txt">{{ i.name }}</div><div class="sub-txt">{{ i.location }}</div></div>
              <div class="side"><b>{{ i.current_qty }} {{ i.unit }}</b><div><StatusBadge :status="invStatus(i)" /></div></div>
            </div>
            <div v-if="!critical.length" style="padding:18px;"><EmptyState icon="check-circle" title="Stock levels healthy" description="Nothing below threshold right now." /></div>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="pill" :size="15" /> Pending Prescriptions</h3><Badge tone="blue">{{ pendingRx.length }} Pending</Badge></div>
          <table class="data-table">
            <thead><tr><th>Patient</th><th>Prescribing Provider</th><th>Medication &amp; Dosage</th><th>Date</th><th>Action</th></tr></thead>
            <tbody>
              <tr v-for="r in pendingRx" :key="r.id">
                <td class="cell-strong">{{ r.patient_name }}<div class="cell-muted mono">{{ r.patient_id }}</div></td>
                <td class="cell-muted">{{ r.prescriber_name }}</td>
                <td>{{ r.medication }}<div class="cell-muted">{{ r.sig }}</div></td>
                <td class="cell-muted">{{ fmtDate(r.date) }}</td>
                <td style="text-align:right;"><button class="btn btn-primary btn-sm" @click="dispense(r)"><Icon name="check-circle" :size="12" /> Dispense &amp; Deduct</button></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
      <div style="display:flex; flex-direction:column; gap:18px;">
        <div class="card">
          <div class="card-header"><h3><Icon name="download" :size="15" /> Restock Inventory</h3></div>
          <div class="card-body">
            <div class="field"><label>Select Item</label><select v-model="restockId" class="input"><option v-for="i in inventory" :key="i.id" :value="i.id">{{ i.name }}</option></select></div>
            <div class="field"><label>Quantity Received</label><input v-model.number="restockQty" class="input" type="number" placeholder="0" /></div>
            <button class="btn btn-primary btn-block" @click="restock"><Icon name="download" :size="13" /> Update Inventory</button>
          </div>
        </div>
        <div class="card">
          <div class="card-header"><h3><Icon name="box" :size="15" /> Ward Requisitions</h3><Badge tone="blue">{{ pendingReq.length }} Requests</Badge></div>
          <div class="card-body tight">
            <div v-for="r in pendingReq.slice(0, 4)" :key="r.id" class="list-row">
              <div><div class="main-txt">{{ (r.items || []).map((i: any) => `${i.name} x${i.qty}`).join(', ') }}</div><div class="sub-txt">{{ r.ward }} · {{ r.requester_name }}</div></div>
              <div class="side flex gap-8"><button class="btn btn-secondary btn-sm" @click="deny(r)">Deny</button><button class="btn btn-success btn-sm" @click="approve(r)">Approve</button></div>
            </div>
            <div v-if="!pendingReq.length" style="padding:18px;"><EmptyState icon="box" title="Nothing pending" description="Ward requisitions will appear here." /></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'
import { matchInventoryItem } from '~/composables/useInventoryMatch'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()

const inventory = ref<any[]>([])
const prescriptions = ref<any[]>([])
const requisitions = ref<any[]>([])
const restockId = ref('')
const restockQty = ref<number | null>(null)

function invStatus(i: any) {
  if (i.current_qty <= i.min_threshold * 0.3) return 'Critical'
  if (i.current_qty < i.min_threshold) return 'Low Stock'
  return 'Adequate'
}

async function load() {
  const [invRes, rxRes, reqRes] = await Promise.all([
    supabase.from('pharmacy_inventory').select('*').order('name', { ascending: true }),
    supabase.from('prescriptions').select('*, patient_names(full_name), profiles:prescribed_by_profile_id(full_name)').eq('status', 'Pending').order('date', { ascending: false }),
    supabase.from('requisitions').select('*, profiles:requested_by_profile_id(full_name)').eq('status', 'Pending').order('requested_on', { ascending: false }),
  ])
  inventory.value = invRes.data || []
  restockId.value = inventory.value[0]?.id || ''
  prescriptions.value = (rxRes.data || []).map((r: any) => ({ ...r, patient_name: r.patient_names?.full_name || 'Unknown', prescriber_name: r.profiles?.full_name || 'Staff' }))
  requisitions.value = (reqRes.data || []).map((r: any) => ({ ...r, requester_name: r.profiles?.full_name || 'Staff' }))
}
await useAsyncData('pharmacy-overview', load)

const critical = computed(() => [...inventory.value].filter((i) => invStatus(i) !== 'Adequate').sort((a, b) => a.current_qty / a.min_threshold - b.current_qty / b.min_threshold))
const pendingRx = computed(() => prescriptions.value)
const pendingReq = computed(() => requisitions.value)

async function dispense(r: any) {
  await queueOrRun(`${r.medication} dispensed to ${r.patient_name}`, async () => {
    const { error } = await supabase.from('prescriptions').update({ status: 'Dispensed' }).eq('id', r.id)
    if (error) throw error

    // Prescriptions carry no qty/inventory FK, so this deducts 1 unit per
    // dispensed prescription against whichever inventory item's name
    // matches the medication text — same convention the (working) side of
    // requisition approval already uses.
    const inv = matchInventoryItem(inventory.value, r.medication)
    if (inv) {
      const newQty = Math.max(0, inv.current_qty - 1)
      const { error: invErr } = await supabase.from('pharmacy_inventory').update({ current_qty: newQty }).eq('id', inv.id)
      if (invErr) throw invErr
      inv.current_qty = newQty
    } else {
      toast(`No inventory match for "${r.medication}" — stock not adjusted`, 'warn')
    }

    prescriptions.value = prescriptions.value.filter((x) => x.id !== r.id)
  })
}

async function restock() {
  const item = inventory.value.find((i) => i.id === restockId.value)
  if (!item || !restockQty.value) return
  await queueOrRun(`${restockQty.value} ${item.unit} of ${item.name} added to stock`, async () => {
    const { error } = await supabase.from('pharmacy_inventory').update({ current_qty: item.current_qty + restockQty.value! }).eq('id', item.id)
    if (error) throw error
    item.current_qty += restockQty.value!
  })
  restockQty.value = null
}

async function approve(r: any) {
  await queueOrRun('Requisition approved and deducted from stock', async () => {
    const { error } = await supabase.from('requisitions').update({ status: 'Approved & Dispensed' }).eq('id', r.id)
    if (error) throw error
    for (const it of r.items || []) {
      const inv = matchInventoryItem(inventory.value, it.name)
      if (inv) {
        const newQty = Math.max(0, inv.current_qty - Number(it.qty || 1))
        await supabase.from('pharmacy_inventory').update({ current_qty: newQty }).eq('id', inv.id)
        inv.current_qty = newQty
      } else {
        toast(`No inventory match for "${it.name}" — stock not adjusted`, 'warn')
      }
    }
    requisitions.value = requisitions.value.filter((x) => x.id !== r.id)
  })
}

async function deny(r: any) {
  await queueOrRun('Requisition denied — out of stock', async () => {
    const { error } = await supabase.from('requisitions').update({ status: 'Denied / Out of Stock' }).eq('id', r.id)
    if (error) throw error
    requisitions.value = requisitions.value.filter((x) => x.id !== r.id)
  })
}
</script>
