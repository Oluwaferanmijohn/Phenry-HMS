<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Book an Appointment</h1>
        <div class="desc">Select a date and time for your visit.</div>
      </div>
    </div>

    <div class="grid grid-main-side">
      <div class="card card-pad">
        <div class="flex-between" style="margin-bottom:12px;"><b style="font-size:14px;">{{ monthLabel }}</b></div>
        <div class="cal-grid">
          <div class="cal-dow">S</div><div class="cal-dow">M</div><div class="cal-dow">T</div><div class="cal-dow">W</div><div class="cal-dow">T</div><div class="cal-dow">F</div><div class="cal-dow">S</div>
          <div v-for="n in startOffset" :key="'pad' + n" />
          <div
            v-for="d in daysInMonth"
            :key="d"
            class="cal-day"
            :class="{ sel: bookingDay === d, disabled: isPast(d) }"
            @click="!isPast(d) && selectDay(d)"
          >{{ d }}</div>
        </div>
        <hr class="hr" />
        <b style="font-size:13px;">Available Times</b>
        <div v-if="loadingSlots" class="muted" style="font-size:12.5px; margin-top:10px;">Checking the schedule…</div>
        <div v-else-if="bookingDay && !availableTimes.length" class="muted" style="font-size:12.5px; margin-top:10px;">No open slots that day — try another date.</div>
        <div v-else class="grid grid-3" style="margin-top:10px; gap:8px;">
          <button
            v-for="t in availableTimes"
            :key="t"
            class="btn btn-sm"
            :class="bookingTime === t ? 'btn-primary' : 'btn-secondary'"
            @click="bookingTime = t"
          >{{ formatTime12(t) }}</button>
        </div>
        <button class="btn btn-primary btn-block" style="margin-top:18px;" :disabled="!bookingDay || !bookingTime" @click="confirmBooking">
          Confirm Booking
        </button>
      </div>

      <div class="card card-pad">
        <h3 style="font-size:13.5px;">Your upcoming visits</h3>
        <div style="display:flex; flex-direction:column; gap:10px; margin-top:12px;">
          <p v-if="!upcoming.length" class="muted" style="font-size:12.5px;">No upcoming visits yet.</p>
          <div v-for="a in upcoming" :key="a.id" class="list-row" style="padding:10px 0;">
            <div>
              <div class="main-txt">{{ a.type }}</div>
              <div class="sub-txt">{{ fmtDate(a.date) }} · {{ formatTime12(a.time) }}</div>
            </div>
            <div class="side"><StatusBadge :status="a.status" /></div>
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
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const patientId = profile.value!.patient_id!

const today = new Date()
const year = today.getFullYear()
const month = today.getMonth() // 0-indexed, current month only — matches the prototype (no month navigation)
const monthLabel = today.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
const startOffset = new Date(year, month, 1).getDay()
const daysInMonth = new Date(year, month + 1, 0).getDate()

const bookingDay = ref<number | null>(null)
const bookingTime = ref<string | null>(null)
const availableTimes = ref<string[]>([])
const loadingSlots = ref(false)
const upcoming = ref<any[]>([])
const assignedDoctorId = ref<string | null>(null)

function isPast(d: number) {
  const date = new Date(year, month, d)
  date.setHours(0, 0, 0, 0)
  const t = new Date()
  t.setHours(0, 0, 0, 0)
  return date < t
}

const { data } = await useAsyncData(`patient-appointments-${patientId}`, async () => {
  const [bioRes, apptRes] = await Promise.all([
    supabase.from('bio_details').select('assigned_doctor_id').eq('patient_id', patientId).maybeSingle(),
    supabase.from('appointments').select('*').eq('patient_id', patientId).order('date', { ascending: true }).order('time', { ascending: true }),
  ])
  return { assignedDoctorId: bioRes.data?.assigned_doctor_id || null, appointments: apptRes.data || [] }
})
if (data.value) {
  assignedDoctorId.value = data.value.assignedDoctorId
  upcoming.value = data.value.appointments
}

function selectDay(d: number) {
  bookingDay.value = d
  bookingTime.value = null
}

const selectedDateStr = computed(() => {
  if (!bookingDay.value) return null
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(bookingDay.value).padStart(2, '0')}`
})

watch(selectedDateStr, async (dateStr) => {
  availableTimes.value = []
  if (!dateStr || !assignedDoctorId.value) return
  loadingSlots.value = true
  const { data: slots } = await supabase.rpc('available_appointment_slots', {
    p_date: dateStr,
    p_provider_profile_id: assignedDoctorId.value,
  })
  availableTimes.value = (slots || []).map((s: any) => s.slot_time)
  loadingSlots.value = false
})

async function confirmBooking() {
  if (!selectedDateStr.value || !bookingTime.value || !assignedDoctorId.value) return
  const date = selectedDateStr.value
  const time = bookingTime.value
  const providerId = assignedDoctorId.value

  const appointment = {
    id: crypto.randomUUID(),
    patient_id: patientId,
    provider_role: 'doctor',
    provider_profile_id: providerId,
    type: 'Patient-Requested Visit',
    date,
    time,
    duration: 30,
    status: 'Scheduled',
  }
  await queueOrRun(
    'Appointment request sent to the clinic',
    { table: 'appointments', kind: 'insert', payload: appointment },
    () => { upcoming.value = [...upcoming.value, appointment].sort((a, b) => (a.date + a.time).localeCompare(b.date + b.time)) },
  )

  bookingDay.value = null
  bookingTime.value = null
}
</script>
