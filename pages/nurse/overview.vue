<template>
  <div>
    <div class="page-header"><div><h1>Clinical Dashboard</h1><div class="desc">{{ todayLabel }}</div></div></div>

    <div class="card" style="margin-bottom:18px;">
      <div class="card-header"><h3><Icon name="clipboard" :size="15" /> My Shift Checklist</h3><Badge tone="amber">{{ pendingCount }} Pending</Badge></div>
      <div class="card-body tight">
        <div v-if="!tasks.length" style="padding:18px;"><EmptyState icon="clipboard" title="Nothing on your list" description="Add a personal reminder for this shift below." /></div>
        <div v-for="t in tasks" :key="t.id" class="list-row">
          <input type="checkbox" :checked="t.done" style="width:16px;height:16px;" @change="toggleTask(t.id)" />
          <div style="margin-left:6px;"><div class="main-txt" :style="{ textDecoration: t.done ? 'line-through' : 'none', color: t.done ? 'var(--text-500)' : 'inherit' }">{{ t.label }}</div></div>
        </div>
        <div style="padding:10px 20px; display:flex; gap:8px;">
          <input v-model="newTask" class="input" placeholder="Add a reminder for this shift…" @keyup.enter="addTask" />
          <button class="btn btn-secondary btn-sm" @click="addTask"><Icon name="plus" :size="12" /> Add</button>
        </div>
      </div>
    </div>

    <div class="grid grid-2">
      <div class="card">
        <div class="card-header"><h3><Icon name="activity" :size="15" /> Vitals Logging</h3></div>
        <div class="card-body">
          <div class="field"><label>Select Patient</label><select v-model="vitalsPatient" class="input"><option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option></select></div>
          <div class="form-row">
            <div class="field"><label>Blood Pressure</label><input v-model="vitals.bp" class="input" placeholder="120/80" /></div>
            <div class="field"><label>Temperature</label><input v-model="vitals.temp" class="input" placeholder="98.6" /></div>
          </div>
          <div class="field"><label>Weight</label><input v-model="vitals.weight" class="input" placeholder="150.0" /></div>
          <div class="field"><label>Clinical Notes</label><textarea v-model="vitals.notes" class="input" rows="2" placeholder="Optional observations…" /></div>
          <button class="btn btn-primary" @click="saveVitals"><Icon name="check-circle" :size="13" /> Save to EMR</button>
        </div>
      </div>

      <div class="card">
        <div class="card-header"><h3><Icon name="pill" :size="15" /> Pharmacy Requisition</h3></div>
        <div class="card-body">
          <div class="flex gap-8" style="margin-bottom:12px;">
            <label class="flex gap-8" style="font-size:12.5px;"><input v-model="reqUrgency" type="radio" value="Routine" /> Standard</label>
            <label class="flex gap-8" style="font-size:12.5px; color:var(--red-600);"><input v-model="reqUrgency" type="radio" value="Emergency" /> STAT</label>
          </div>
          <div class="field"><label>Requisition Item</label><input v-model="reqItem" class="input" placeholder="e.g. Gonal-F 450 IU" /></div>
          <div class="form-row">
            <div class="field"><label>Quantity</label><input v-model.number="reqQty" class="input" type="number" /></div>
            <div class="field"><label>Route/Method</label><select v-model="reqRoute" class="input"><option>IM (Intramuscular)</option><option>SubQ</option><option>Oral</option><option>IV</option></select></div>
          </div>
          <div class="field"><label>Deliver To</label><input v-model="reqLoc" class="input" /></div>
          <div class="flex gap-10">
            <button class="btn btn-secondary" @click="resetReq">Clear</button>
            <button class="btn btn-primary" @click="sendRequisition"><Icon name="arrow-right" :size="13" /> Send Request</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useToast } from '~/composables/useToast'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const { queueOrRun } = useSyncQueue()

const todayLabel = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
const patients = ref<any[]>([])
const vitalsPatient = ref('')
const vitals = ref({ bp: '', temp: '', weight: '', notes: '' })

// No nursing_tasks table exists in spec §1 — this is an honest, session-only
// personal checklist rather than the prototype's hardcoded example tasks
// tied to patient names that may not exist in this deployment.
let nextTaskId = 1
const tasks = ref<{ id: number; label: string; done: boolean }[]>([])
const newTask = ref('')
const pendingCount = computed(() => tasks.value.filter((t) => !t.done).length)

function toggleTask(id: number) {
  const t = tasks.value.find((x) => x.id === id)
  if (t) t.done = !t.done
}
function addTask() {
  if (!newTask.value.trim()) return
  tasks.value.push({ id: nextTaskId++, label: newTask.value.trim(), done: false })
  newTask.value = ''
}

await useAsyncData('nurse-overview', async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  vitalsPatient.value = patients.value[0]?.patient_id || ''
  return true
})

// Matches the prototype's own behavior exactly: saveVitals() doesn't persist
// anywhere either (no vitals table exists in spec §1) — just confirms the action.
function saveVitals() {
  const p = patients.value.find((x) => x.patient_id === vitalsPatient.value)
  toast(`Vitals saved for ${p?.full_name || 'patient'}`, 'success')
  vitals.value = { bp: '', temp: '', weight: '', notes: '' }
}

const reqUrgency = ref('Routine')
const reqItem = ref('')
const reqQty = ref(1)
const reqRoute = ref('IM (Intramuscular)')
const reqLoc = ref('Exam Room 3')

function resetReq() {
  reqItem.value = ''
  reqQty.value = 1
  reqLoc.value = 'Exam Room 3'
}

async function sendRequisition() {
  if (!reqItem.value) return toast('Enter an item to request', 'warn')
  await queueOrRun(`Requisition for ${reqItem.value} sent to pharmacy`, async () => {
    const { error } = await supabase.from('requisitions').insert({
      requested_by_profile_id: profile.value!.id,
      ward: 'IVF Ward 2',
      items: [{ name: reqItem.value, qty: reqQty.value, route: reqRoute.value, deliverTo: reqLoc.value }],
      urgency: reqUrgency.value,
      status: 'Pending',
    })
    if (error) throw error
  })
  resetReq()
}
</script>
