<template>
  <div>
    <div class="page-header"><div><h1>Ward Requisition Request</h1><div class="desc">Submit new supply requests to central pharmacy and monitor recent orders.</div></div></div>
    <div class="grid grid-main-side">
      <div class="card card-pad">
        <b style="font-size:13px;">New Supply Request</b>
        <div class="field" style="margin-top:12px;"><label>Requesting From</label><input class="input" value="IVF Ward 2" disabled /></div>
        <div v-for="(row, i) in itemRows" :key="i" class="form-row" :style="{ marginTop: i === 0 ? 0 : '10px' }">
          <select v-model="row.name" class="input"><option>10ml Syringes</option><option>Alcohol Swabs</option><option>Gauze & Dressings</option><option>Cryo-Straws</option></select>
          <input v-model.number="row.qty" class="input" type="number" placeholder="Qty" style="max-width:100px;" />
        </div>
        <button class="btn btn-secondary btn-sm" style="margin-top:8px;" @click="itemRows.push({ name: '10ml Syringes', qty: 1 })"><Icon name="plus" :size="12" /> Add Another Item</button>
        <div class="field" style="margin-top:14px;">
          <label>Urgency Level</label>
          <div style="display:flex; flex-direction:column; gap:6px; font-size:12.5px;">
            <label class="flex gap-8"><input v-model="urgency" type="radio" value="Routine" /> Routine (24hrs)</label>
            <label class="flex gap-8"><input v-model="urgency" type="radio" value="Urgent" /> Urgent (End of Shift)</label>
            <label class="flex gap-8" style="color:var(--red-600);"><input v-model="urgency" type="radio" value="Emergency" /> Emergency (Immediate)</label>
          </div>
        </div>
        <button class="btn btn-primary btn-block" style="margin-top:14px;" @click="submit"><Icon name="arrow-right" :size="13" /> Submit Requisition to Pharmacy</button>
      </div>
      <div class="card">
        <div class="card-header"><h3><Icon name="box" :size="15" /> Recent Requisition Status</h3></div>
        <div class="card-body tight">
          <div v-for="r in recent" :key="r.id" class="list-row">
            <div><div class="main-txt">{{ (r.items || []).map((i: any) => i.name).join(', ') }}</div><div class="sub-txt">{{ r.ward }} · {{ (r.items || []).length }} item(s) · {{ fmtWhen(r.requested_on) }}</div></div>
            <div class="side"><StatusBadge :status="r.status" /></div>
          </div>
          <div v-if="!recent.length" style="padding:20px;"><EmptyState icon="box" title="No requisitions yet" description="Requests you submit will show up here." /></div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const itemRows = ref([{ name: '10ml Syringes', qty: 10 }])
const urgency = ref('Routine')
const recent = ref<any[]>([])

async function load() {
  const { data } = await supabase
    .from('requisitions')
    .select('*')
    .eq('requested_by_profile_id', profile.value!.id)
    .order('requested_on', { ascending: false })
    .limit(6)
  recent.value = data || []
}
await useAsyncData('nurse-requisitions', load)

function fmtWhen(iso: string) {
  const d = new Date(iso)
  const diffMin = Math.round((Date.now() - d.getTime()) / 60000)
  if (diffMin < 1) return 'just now'
  if (diffMin < 60) return `${diffMin}m ago`
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

async function submit() {
  await queueOrRun('Requisition submitted to pharmacy', async () => {
    const { error } = await supabase.from('requisitions').insert({
      requested_by_profile_id: profile.value!.id,
      ward: 'IVF Ward 2',
      items: itemRows.value,
      urgency: urgency.value,
      status: 'Pending',
    })
    if (error) throw error
    await load()
  })
  itemRows.value = [{ name: '10ml Syringes', qty: 10 }]
  urgency.value = 'Routine'
}
</script>
