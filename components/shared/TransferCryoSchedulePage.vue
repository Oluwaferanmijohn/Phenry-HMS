<template>
  <div>
    <div class="page-header"><div><h1>Transfer &amp; Cryopreservation Schedule</h1><div class="desc">Scheduled transfers and freezes — mark each as done, postponed, or cancelled and document the outcome.</div></div></div>
    <div class="tabs" style="margin-bottom:16px;">
      <div class="tab" :class="{ active: range === 'day' }" @click="range = 'day'">Today</div>
      <div class="tab" :class="{ active: range === 'week' }" @click="range = 'week'">This Week</div>
      <div class="tab" :class="{ active: range === 'month' }" @click="range = 'month'">This Month</div>
    </div>
    <div class="card">
      <table class="data-table">
        <thead><tr><th>Date</th><th>Patient</th><th>Type</th><th>Status</th><th>Actions</th></tr></thead>
        <tbody>
          <tr v-for="it in filtered" :key="it.id">
            <td>{{ fmtDate(it.scheduled_date) }}</td>
            <td class="cell-strong">{{ it.patient_name }}</td>
            <td><Badge tone="blue">{{ it.type }}</Badge></td>
            <td><StatusBadge :status="it.status" /><span v-if="it.embryos_used != null" class="cell-muted" style="margin-left:6px;">({{ it.embryos_used }} used)</span></td>
            <td style="text-align:right;">
              <div class="flex gap-8" style="justify-content:flex-end; flex-wrap:wrap;">
                <template v-if="it.status === 'Scheduled' || it.status === 'Postponed'">
                  <button class="btn btn-success btn-sm" @click="openAction(it, 'Done')">Done</button>
                  <button class="btn btn-secondary btn-sm" @click="openAction(it, 'Postponed')">Postpone</button>
                  <button class="btn btn-danger btn-sm" @click="openAction(it, 'Cancelled')">Cancel</button>
                  <button v-if="it.status === 'Postponed'" class="btn btn-secondary btn-sm" @click="viewDoc(it)"><Icon name="file" :size="11" /> Notes</button>
                </template>
                <button v-else class="btn btn-secondary btn-sm" @click="viewDoc(it)"><Icon name="file" :size="11" /> Notes</button>
                <button class="btn btn-secondary btn-sm" @click="openPatient(it)"><Icon name="user" :size="11" /> Patient &amp; Spouse</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <div v-if="!filtered.length" style="padding:20px;"><EmptyState icon="calendar" title="Nothing scheduled" description="No transfers or cryopreservations in this range." /></div>
    </div>

    <Modal v-model="showAction" :title="actionLabel + ' — ' + (activeItem?.type || '')">
      <p class="cell-muted" style="margin-bottom:12px;" v-if="activeItem">{{ activeItem.patient_name }} · scheduled {{ fmtDate(activeItem.scheduled_date) }}</p>
      <div v-if="pendingAction === 'Postponed'" class="field"><label>New Date</label><input v-model="newDate" class="input" type="date" /></div>
      <div v-if="pendingAction === 'Done' && isTransferType" class="field">
        <label>Embryos Transferred</label>
        <input v-model="embryosUsed" class="input" type="number" min="0" placeholder="e.g. 2" />
        <div v-if="storedCount !== null" class="hint">{{ storedCount }} embryo(s) currently in cryo storage for this patient.</div>
      </div>
      <div class="field"><label>Documentation — what was done / reason</label><textarea v-model="actionNotes" class="input" rows="4" placeholder="Document the clinical outcome or reason…" /></div>
      <template #footer>
        <button class="btn btn-secondary" @click="showAction = false">Cancel</button>
        <button class="btn btn-primary" @click="submitAction"><Icon name="check-circle" :size="13" /> Save</button>
      </template>
    </Modal>

    <Modal v-model="showDoc" :title="(activeItem?.type || '') + ' — ' + (activeItem?.status || '')">
      <p class="cell-muted" v-if="activeItem">{{ activeItem.patient_name }} · {{ fmtDate(activeItem.scheduled_date) }}</p>
      <p v-if="activeItem?.embryos_used != null" class="cell-strong" style="margin-top:8px;">{{ activeItem.embryos_used }} embryo(s) transferred</p>
      <p style="font-size:13px; margin-top:10px; color:var(--text-700);">{{ activeItem?.notes || 'No documentation recorded.' }}</p>
      <p class="cell-muted" style="margin-top:10px;" v-if="activeItem">Documented by {{ activeItem.documented_by_name || '—' }} on {{ fmtDate(activeItem.documented_on) }}</p>
      <template #footer><button class="btn btn-secondary" @click="showDoc = false">Close</button></template>
    </Modal>

    <PatientDetailModal v-model="showPatient" :patient="patientDetail" :cycle="null" :consultations="[]" :lab-results="[]" :caps="{}" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ role: string }>()
const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()

const range = ref<'day' | 'week' | 'month'>('week')
const all = ref<any[]>([])

async function load() {
  const { data } = await supabase
    .from('transfer_cryo_schedule')
    .select('*, patient_names(full_name), profiles:documented_by(full_name)')
    .order('scheduled_date', { ascending: true })
  all.value = (data || []).map((it: any) => ({ ...it, patient_name: it.patient_names?.full_name || 'Unknown', documented_by_name: it.profiles?.full_name }))
}
await useAsyncData(`transfer-cryo-schedule-${props.role}`, load)

const filtered = computed(() => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return all.value.filter((it) => {
    const d = new Date(it.scheduled_date + 'T00:00')
    if (range.value === 'day') return d.getTime() === today.getTime()
    if (range.value === 'week') {
      const diff = (d.getTime() - today.getTime()) / 86400000
      return diff >= -1 && diff <= 7
    }
    if (range.value === 'month') return d.getMonth() === today.getMonth() && d.getFullYear() === today.getFullYear()
    return true
  })
})

const showAction = ref(false)
const showDoc = ref(false)
const showPatient = ref(false)
const activeItem = ref<any>(null)
const patientDetail = ref<any>(null)
const pendingAction = ref('')
const actionNotes = ref('')
const newDate = ref('')
const embryosUsed = ref<number | string>('')
const storedCount = ref<number | null>(null)

const actionLabel = computed(() => (pendingAction.value === 'Done' ? 'Mark Done' : pendingAction.value === 'Postponed' ? 'Postpone' : 'Cancel'))
const isTransferType = computed(() => (activeItem.value?.type || '').toLowerCase().includes('transfer'))

async function openAction(it: any, action: string) {
  activeItem.value = it
  pendingAction.value = action
  actionNotes.value = ''
  newDate.value = it.scheduled_date
  embryosUsed.value = ''
  storedCount.value = null
  showAction.value = true

  if (action === 'Done' && (it.type || '').toLowerCase().includes('transfer')) {
    const { data } = await supabase
      .from('cryo_records')
      .select('straws')
      .eq('patient_id', it.patient_id)
      .eq('asset_type', 'Embryo')
      .eq('status', 'Stored')
    storedCount.value = (data || []).reduce((sum: number, r: any) => sum + (r.straws || 0), 0)
  }
}

async function submitAction() {
  if (!activeItem.value) return
  const it = activeItem.value
  const action = pendingAction.value
  const notes = actionNotes.value
  const rescheduleDate = newDate.value
  const documentedBy = profile.value!.id
  const targetEmbryosUsed = action === 'Done' && isTransferType.value && embryosUsed.value !== '' ? Number(embryosUsed.value) : null
  await queueOrRun(`${it.type} for ${it.patient_name} marked ${action}`, async () => {
    const patch: any = {
      status: action,
      notes,
      documented_by: documentedBy,
      documented_on: new Date().toISOString().slice(0, 10),
    }
    if (action === 'Postponed' && rescheduleDate) patch.scheduled_date = rescheduleDate
    if (targetEmbryosUsed !== null) patch.embryos_used = targetEmbryosUsed
    const { error } = await supabase.from('transfer_cryo_schedule').update(patch).eq('id', it.id)
    if (error) throw error
    await load()
  })
  showAction.value = false
}

function viewDoc(it: any) {
  activeItem.value = it
  showDoc.value = true
}

async function openPatient(it: any) {
  if (props.role === 'lab_tech') {
    const { data } = await supabase.rpc('patient_lab_profile', { p_patient_id: it.patient_id })
    patientDetail.value = data?.[0] || null
  } else {
    const { data } = await supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', it.patient_id).single()
    patientDetail.value = data ? { ...data, full_name: data.patient_names?.full_name } : null
  }
  showPatient.value = true
}
</script>
