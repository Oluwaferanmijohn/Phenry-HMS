<template>
  <div>
    <div class="page-header"><div><h1>Clinical Dashboard</h1><div class="desc">{{ todayLabel }}</div></div></div>

    <div class="card" style="margin-bottom:18px;">
      <div class="card-header"><h3><Icon name="clipboard" :size="15" /> My Shift Checklist</h3><Badge tone="amber">{{ pendingCount }} Pending</Badge></div>
      <div class="card-body tight">
        <div v-if="!tasks.length" style="padding:18px;"><EmptyState icon="clipboard" title="Nothing on your list" description="Add a personal reminder for this shift below." /></div>
        <div v-for="t in tasks" :key="t.id" class="list-row">
          <input type="checkbox" :checked="t.done" style="width:16px;height:16px;" @change="toggleTask(t)" />
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
            <div class="field"><label>Temperature (°C)</label><input v-model="vitals.temp" class="input" type="number" step="0.1" placeholder="36.8" /></div>
          </div>
          <div class="field"><label>Weight (kg)</label><input v-model="vitals.weight" class="input" type="number" step="0.1" placeholder="62.0" /></div>
          <div class="field"><label>Clinical Notes</label><textarea v-model="vitals.notes" class="input" rows="2" placeholder="Optional observations…" /></div>
          <button class="btn btn-primary" :disabled="savingVitals" @click="saveVitals"><Icon name="check-circle" :size="13" /> Save to EMR</button>
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
const savingVitals = ref(false)
const todayIso = (() => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
})()

const tasks = ref<{ id: string; label: string; done: boolean; updated_at?: string }[]>([])
const newTask = ref('')
const pendingCount = computed(() => tasks.value.filter((t) => !t.done).length)

async function toggleTask(task: { id: string; label: string; done: boolean; updated_at?: string }) {
  const previous = task.done
  task.done = !previous
  try {
    await queueOrRun(`${task.done ? 'Completed' : 'Reopened'} shift task`, {
      table: 'nursing_tasks',
      kind: 'update',
      payload: { done: task.done },
      match: { id: task.id },
      expectedUpdatedAt: task.updated_at,
    })
  } catch {
    task.done = previous
  }
}
async function addTask() {
  const label = newTask.value.trim()
  if (!label || !profile.value) return
  if (label.length > 300) return toast('Shift reminders must be 300 characters or fewer', 'warn')
  const task = { id: crypto.randomUUID(), label, done: false }
  tasks.value.push(task)
  newTask.value = ''
  try {
    await queueOrRun('Shift reminder saved', {
      table: 'nursing_tasks',
      kind: 'insert',
      payload: { ...task, nurse_id: profile.value.id, shift_date: todayIso },
    })
  } catch {
    tasks.value = tasks.value.filter((item) => item.id !== task.id)
  }
}

await useAsyncData('nurse-overview', async () => {
  const [patientResult, taskResult] = await Promise.all([
    supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true }),
    supabase.from('nursing_tasks').select('id,label,done,updated_at').eq('nurse_id', profile.value!.id).eq('shift_date', todayIso).order('created_at'),
  ])
  if (patientResult.error) throw patientResult.error
  if (taskResult.error) throw taskResult.error
  patients.value = patientResult.data || []
  tasks.value = taskResult.data || []
  vitalsPatient.value = patients.value[0]?.patient_id || ''
  return true
})

async function saveVitals() {
  if (!vitalsPatient.value || !profile.value) return toast('Select a patient first', 'warn')
  if (![vitals.value.bp, vitals.value.temp, vitals.value.weight, vitals.value.notes].some((value) => String(value).trim())) {
    return toast('Enter at least one vital or clinical note', 'warn')
  }
  const bpMatch = vitals.value.bp.trim().match(/^(\d{2,3})\s*\/\s*(\d{2,3})$/)
  if (vitals.value.bp && !bpMatch) return toast('Blood pressure must use the format 120/80', 'warn')
  const systolic = bpMatch ? Number(bpMatch[1]) : null
  const diastolic = bpMatch ? Number(bpMatch[2]) : null
  const temperature = vitals.value.temp === '' ? null : Number(vitals.value.temp)
  const weight = vitals.value.weight === '' ? null : Number(vitals.value.weight)
  if ((temperature !== null && (!Number.isFinite(temperature) || temperature < 30 || temperature > 45))
    || (weight !== null && (!Number.isFinite(weight) || weight < 2 || weight > 400))) {
    return toast('Check the temperature and weight values', 'warn')
  }
  const p = patients.value.find((x) => x.patient_id === vitalsPatient.value)
  savingVitals.value = true
  try {
    await queueOrRun(`Vitals saved for ${p?.full_name || 'patient'}`, {
      table: 'nurse_visits',
      kind: 'insert',
      payload: {
        id: crypto.randomUUID(),
        patient_id: vitalsPatient.value,
        documented_by: profile.value.id,
        visit_date: todayIso,
        bp_systolic: systolic,
        bp_diastolic: diastolic,
        temperature_c: temperature,
        weight_kg: weight,
        nursing_notes: vitals.value.notes.trim() || null,
        condition: 'Stable',
      },
    })
    vitals.value = { bp: '', temp: '', weight: '', notes: '' }
  } finally {
    savingVitals.value = false
  }
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
  if (!Number.isInteger(reqQty.value) || reqQty.value < 1) return toast('Quantity must be a positive whole number', 'warn')
  const requestedBy = profile.value!.id
  const snapshotItem = reqItem.value
  const snapshotQty = reqQty.value
  const snapshotRoute = reqRoute.value
  const snapshotLoc = reqLoc.value
  const snapshotUrgency = reqUrgency.value
  await queueOrRun(`Requisition for ${snapshotItem} sent to pharmacy`, {
    table: 'requisitions',
    kind: 'insert',
    payload: {
      requested_by_profile_id: requestedBy,
      ward: 'IVF Ward 2',
      items: [{ name: snapshotItem, qty: snapshotQty, route: snapshotRoute, deliverTo: snapshotLoc }],
      urgency: snapshotUrgency,
      status: 'Pending',
    },
  })
  resetReq()
}
</script>
