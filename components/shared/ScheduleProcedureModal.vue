<template>
  <Modal :model-value="modelValue" title="Schedule Clinical Procedure" @update:model-value="$emit('update:modelValue', $event)">
    <div class="form-row">
      <div v-if="!preselectedPatientId" class="field">
        <label>Patient</label>
        <select v-model="patientId" class="input">
          <option value="">Select a patient…</option>
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
      </div>
      <div class="field"><label>Date</label><input v-model="date" class="input" type="date" /></div>
    </div>
    <div class="form-row">
      <div class="field"><label>Time</label><input v-model="time" class="input" type="time" /></div>
      <div class="field">
        <label>Procedure Type</label>
        <select v-model="procedure" class="input">
          <option>OPU</option><option>Embryo Transfer</option><option>Consultation</option><option>Hysteroscopy</option>
        </select>
      </div>
    </div>
    <div class="form-row">
      <div class="field">
        <label>Location / Theatre</label>
        <select v-model="location" class="input"><option>Theatre 1</option><option>Theatre 2</option><option>Room 1</option><option>Room 2</option></select>
      </div>
      <div class="field">
        <label>Assigned Provider</label>
        <select v-model="providerId" class="input">
          <option value="">Unassigned</option>
          <option v-for="p in providers" :key="p.id" :value="p.id">{{ p.full_name }} ({{ p.role }})</option>
        </select>
      </div>
    </div>
    <div class="field">
      <label>Recovery Bed Allocation</label>
      <select v-model="bedId" class="input">
        <option value="">Assign bed (optional)</option>
        <option v-for="b in freeBeds" :key="b.id" :value="b.id">{{ b.id }}</option>
      </select>
    </div>
    <div class="field"><label>Pre-Op Instructions or Notes</label><textarea v-model="notes" class="input" rows="3" placeholder="Specific instructions regarding fasting, allergies, or specific protocols…" /></div>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="submitting || (!preselectedPatientId && !patientId)" @click="submit"><Icon name="check-circle" :size="13" /> Confirm &amp; Schedule Procedure</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { useSyncQueue } from '~/composables/useSyncQueue'

const props = defineProps<{ modelValue: boolean; preselectedPatientId?: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; scheduled: [] }>()

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()

const patients = ref<any[]>([])
const providers = ref<any[]>([])
const freeBeds = ref<any[]>([])
const patientId = ref('')
const procedure = ref('OPU')
const date = ref(new Date(Date.now() + 86400000).toISOString().slice(0, 10))
const time = ref('09:00')
const location = ref('Theatre 1')
const providerId = ref('')
const bedId = ref('')
const notes = ref('')
const submitting = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    const [providersRes, bedsRes] = await Promise.all([
      supabase.from('profiles').select('id, full_name, role').in('role', ['doctor', 'matron']),
      supabase.from('recovery_beds').select('id').eq('status', 'Free'),
    ])
    providers.value = providersRes.data || []
    freeBeds.value = bedsRes.data || []
    if (!props.preselectedPatientId && !patients.value.length) {
      const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
      patients.value = data || []
    }
  }
)

async function submit() {
  const targetPatientId = props.preselectedPatientId || patientId.value
  if (!targetPatientId) return
  submitting.value = true

  // A bed only physically has someone in it once the procedure date
  // arrives — flipping it to 'Occupied' the moment ANY future date is
  // scheduled (previously every case, since this defaults to tomorrow)
  // made the ward register read as full when it was physically empty.
  // Today-or-earlier still occupies the bed now; anything further out only
  // reserves it (excluded from the picker so it can't be double-booked,
  // but not counted toward "beds occupied now").
  const todayStr = new Date().toISOString().slice(0, 10)
  const isNow = date.value <= todayStr

  // Snapshotted so a queued-while-offline save replays with what was on
  // the form when Schedule was clicked, not whatever the form happens to
  // hold (a different patient/procedure entirely) by the time it replays.
  const targetProcedure = procedure.value
  const targetDate = date.value
  const targetTime = time.value
  const targetLocation = location.value
  const targetProviderId = providerId.value || null
  const targetBedId = bedId.value || null
  const targetNotes = notes.value

  await queueOrRun(`${targetProcedure} scheduled`, [
    {
      table: 'surgery_schedule',
      kind: 'insert',
      payload: {
        patient_id: targetPatientId,
        procedure: targetProcedure,
        date: targetDate,
        time: targetTime,
        location: targetLocation,
        assigned_provider_id: targetProviderId,
        recovery_bed_id: targetBedId,
        status: 'Scheduled',
        notes: targetNotes,
      },
    },
    ...(targetBedId ? [{
      table: 'recovery_beds',
      kind: 'update' as const,
      payload: isNow
        ? { status: 'Occupied', occupied_by_patient_id: targetPatientId, occupied_since: new Date().toISOString(), reserved_for_date: null }
        : { status: 'Reserved', occupied_by_patient_id: targetPatientId, occupied_since: null, reserved_for_date: targetDate },
      match: { id: targetBedId },
    }] : []),
  ])

  submitting.value = false
  emit('scheduled')
  emit('update:modelValue', false)
}
</script>
