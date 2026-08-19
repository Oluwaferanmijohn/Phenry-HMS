<template>
  <div>
    <div class="page-header"><div><h1>Book Appointment</h1><div class="desc">Schedule a visit for any registered patient.</div></div></div>
    <div class="grid grid-main-side">
      <div class="card card-pad">
        <div class="field">
          <label>Patient</label>
          <select v-model="patientId" class="input">
            <option value="">Select a registered patient…</option>
            <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }} — {{ p.patient_id }}</option>
          </select>
        </div>
        <div class="field">
          <label>Seen By</label>
          <div class="flex gap-14" style="margin-top:2px;">
            <label class="flex gap-8" style="font-size:13px;"><input v-model="providerRole" type="radio" value="doctor" @change="onProviderChange" /> Doctor <span class="cell-muted">({{ doctorName }})</span></label>
            <label class="flex gap-8" style="font-size:13px;"><input v-model="providerRole" type="radio" value="matron" @change="onProviderChange" /> Matron <span class="cell-muted">({{ matronName }})</span></label>
          </div>
        </div>
        <hr class="hr" />
        <div class="flex-between" style="margin-bottom:12px;"><b style="font-size:14px;">{{ monthLabel }}</b></div>
        <div class="cal-grid">
          <div class="cal-dow">S</div><div class="cal-dow">M</div><div class="cal-dow">T</div><div class="cal-dow">W</div><div class="cal-dow">T</div><div class="cal-dow">F</div><div class="cal-dow">S</div>
          <div v-for="n in startOffset" :key="'pad' + n" />
          <div v-for="d in daysInMonth" :key="d" class="cal-day" :class="{ sel: bookingDay === d }" @click="selectDay(d)">{{ d }}</div>
        </div>
        <hr class="hr" />
        <b style="font-size:13px;">Available Times</b>
        <div v-if="loadingSlots" class="muted" style="font-size:12.5px; margin-top:10px;">Checking the schedule…</div>
        <div v-else-if="bookingDay && !availableTimes.length" class="muted" style="font-size:12.5px; margin-top:10px;">No open slots that day.</div>
        <div v-else class="grid grid-4" style="margin-top:10px; gap:8px;">
          <button v-for="t in availableTimes" :key="t" class="btn btn-sm" :class="bookingTime === t ? 'btn-primary' : 'btn-secondary'" @click="bookingTime = t">
            {{ formatTime12(t) }}
          </button>
        </div>
        <button class="btn btn-primary btn-block" style="margin-top:18px;" @click="confirmBooking">
          <Icon name="check-circle" :size="13" /> Confirm Appointment
        </button>
      </div>

      <div class="card card-pad">
        <h3 style="font-size:13.5px;">Booking Summary</h3>
        <div style="margin-top:12px; display:flex; flex-direction:column; gap:10px; font-size:12.5px;">
          <div><div class="muted" style="font-size:10.5px;">PATIENT</div><div style="font-weight:600;">{{ selectedPatientName || 'Not selected' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">SEEN BY</div><div style="font-weight:600;">{{ providerRole === 'doctor' ? doctorName : matronName }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">DATE</div><div style="font-weight:600;">{{ selectedDateStr ? fmtDate(selectedDateStr) : 'Not selected' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">TIME</div><div style="font-weight:600;">{{ bookingTime ? formatTime12(bookingTime) : 'Not selected' }}</div></div>
        </div>
        <hr class="hr" />
        <b style="font-size:13px;">Today's New Bookings</b>
        <div style="margin-top:10px; display:flex; flex-direction:column; gap:8px;">
          <p v-if="!sessionBookings.length" class="muted" style="font-size:12px;">No bookings yet this session.</p>
          <div v-for="a in sessionBookings" :key="a.id" class="list-row" style="padding:8px 0;">
            <div><div class="main-txt">{{ a.patient_name }}</div><div class="sub-txt">{{ a.provider_name }} · {{ fmtDate(a.date) }} {{ formatTime12(a.time) }}</div></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { fmtDate, formatTime12 } from '~/composables/useFormat'
import { useSyncQueue } from '~/composables/useSyncQueue'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
const { toast } = useToast()

const today = new Date()
const year = today.getFullYear()
const month = today.getMonth()
const monthLabel = today.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
const startOffset = new Date(year, month, 1).getDay()
const daysInMonth = new Date(year, month + 1, 0).getDate()

const patients = ref<any[]>([])
const patientId = ref('')
const providerRole = ref<'doctor' | 'matron'>('doctor')
const doctorProfile = ref<{ id: string; full_name: string } | null>(null)
const matronProfile = ref<{ id: string; full_name: string } | null>(null)
const bookingDay = ref<number | null>(null)
const bookingTime = ref<string | null>(null)
const availableTimes = ref<string[]>([])
const loadingSlots = ref(false)
const sessionBookings = ref<any[]>([])

const doctorName = computed(() => doctorProfile.value?.full_name || 'Unassigned')
const matronName = computed(() => matronProfile.value?.full_name || 'Unassigned')
const selectedPatientName = computed(() => patients.value.find((p) => p.patient_id === patientId.value)?.full_name || '')

await useAsyncData('receptionist-book-init', async () => {
  const [patientsRes, doctorRes, matronRes] = await Promise.all([
    supabase.rpc('patients_front_desk_directory', { p_search: '' }),
    supabase.from('profiles').select('id, full_name').eq('role', 'doctor').limit(1).maybeSingle(),
    supabase.from('profiles').select('id, full_name').eq('role', 'matron').limit(1).maybeSingle(),
  ])
  patients.value = patientsRes.data || []
  doctorProfile.value = doctorRes.data
  matronProfile.value = matronRes.data
  return true
})

function selectDay(d: number) {
  bookingDay.value = d
  bookingTime.value = null
}
function onProviderChange() {
  bookingTime.value = null
}

const selectedDateStr = computed(() => {
  if (!bookingDay.value) return null
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(bookingDay.value).padStart(2, '0')}`
})
const currentProvider = computed(() => (providerRole.value === 'doctor' ? doctorProfile.value : matronProfile.value))

watch([selectedDateStr, providerRole], async ([dateStr]) => {
  availableTimes.value = []
  if (!dateStr || !currentProvider.value) return
  loadingSlots.value = true
  const { data: slots } = await supabase.rpc('available_appointment_slots', {
    p_date: dateStr,
    p_provider_profile_id: currentProvider.value.id,
  })
  availableTimes.value = (slots || []).map((s: any) => s.slot_time)
  loadingSlots.value = false
})

async function confirmBooking() {
  if (!patientId.value) return toast('Select a patient first', 'warn')
  if (!selectedDateStr.value || !bookingTime.value) return toast('Choose a date and time', 'warn')
  if (!currentProvider.value) return toast(`No ${providerRole.value} is on staff yet`, 'warn')

  const date = selectedDateStr.value
  const time = bookingTime.value
  const provider = currentProvider.value
  const pName = selectedPatientName.value

  await queueOrRun(`${pName} booked with ${provider.full_name}`, async () => {
    const { data, error } = await supabase
      .from('appointments')
      .insert({
        patient_id: patientId.value,
        provider_role: providerRole.value,
        provider_profile_id: provider.id,
        type: 'Consultation',
        date,
        time,
        duration: 30,
        status: 'Scheduled',
        room: providerRole.value === 'doctor' ? 'Room 1' : 'Room 2',
      })
      .select()
      .single()
    if (error) throw error
    sessionBookings.value.unshift({ ...data, patient_name: pName, provider_name: provider.full_name })
  })

  patientId.value = ''
  bookingDay.value = null
  bookingTime.value = null
}
</script>
