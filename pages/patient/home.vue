<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Welcome back, {{ firstName }}</h1>
        <div class="desc">Here's your care plan summary for today, {{ fmtDate(new Date()) }}.</div>
      </div>
    </div>

    <div class="grid grid-main-side">
      <div style="display:flex; flex-direction:column; gap:18px;">
        <!-- Today's meds -->
        <div class="card">
          <div class="card-header"><h3><Icon name="pill" :size="15" /> Today's Injections &amp; Supplements</h3></div>
          <div class="card-body tight">
            <div v-if="!todaysMeds.length" style="padding:20px;">
              <EmptyState icon="pill" title="Nothing scheduled today" description="Your active prescriptions will appear here once your care team adds them." />
            </div>
            <div v-for="med in todaysMeds" :key="med.id" class="list-row">
              <div class="icon-wrap" style="background:var(--blue-50); color:var(--blue-600); width:36px;height:36px;border-radius:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
                <Icon name="syringe" :size="16" />
              </div>
              <div>
                <div class="main-txt">{{ med.medication }}</div>
                <div class="sub-txt">{{ med.sig }}</div>
              </div>
              <div class="side">
                <button class="btn btn-sm" :class="takenToday.has(med.id) ? 'btn-success' : 'btn-secondary'" :disabled="takenToday.has(med.id)" @click="markTaken(med.id, med.medication)">
                  <Icon v-if="takenToday.has(med.id)" name="check-circle" :size="13" />
                  {{ takenToday.has(med.id) ? 'Taken' : 'Mark as taken' }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Next appointment -->
        <div class="card card-pad">
          <div class="flex-between" style="margin-bottom:4px;">
            <h3 style="font-size:14.5px;"><Icon name="calendar" :size="15" /> {{ nextAppointment ? nextAppointmentDayLabel : 'Upcoming' }}</h3>
            <Badge v-if="nextAppointment" tone="blue">{{ formatTime12(nextAppointment.time) }}</Badge>
          </div>
          <template v-if="nextAppointment">
            <div style="font-weight:700; font-size:14.5px; margin-top:6px;">{{ nextAppointment.type }}</div>
            <div class="muted" style="font-size:12.5px; margin-top:3px;"><Icon name="clock" :size="12" /> {{ nextAppointment.room || 'Room TBC' }}</div>
          </template>
          <p v-else class="muted" style="font-size:12.5px; margin-top:6px;">No upcoming visits — book one from the Book Appointment page.</p>
        </div>

        <!-- Active milestone (spec §3.1) -->
        <div v-if="activeMilestone" class="card card-pad">
          <div class="flex-between">
            <h3 style="font-size:14.5px;"><Icon name="cash" :size="15" /> Next Payment Due</h3>
            <StatusBadge :status="activeMilestone.status" />
          </div>
          <div style="font-weight:700; font-size:14.5px; margin-top:6px;">{{ activeMilestone.label }}</div>
          <div class="muted" style="font-size:12.5px; margin-top:3px;">{{ activeMilestone.due_context }} · {{ fmtNaira(activeMilestone.amount) }}</div>
          <button class="btn btn-secondary btn-sm" style="margin-top:10px;" @click="$router.push('/patient/payments')">Go to Payment Plan <Icon name="arrow-right" :size="12" /></button>
        </div>

        <!-- Current cycle phase -->
        <div v-if="activeCycle" class="card card-pad" style="border-color:var(--blue-100); background:var(--blue-50);">
          <div class="flex-between">
            <h3 style="font-size:14.5px; color:var(--blue-700);"><Icon name="layers" :size="15" /> Current Phase — Cycle Day {{ activeCycle.cycle_day }}</h3>
            <Badge tone="blue">{{ activeCycle.stage }}</Badge>
          </div>
          <p style="font-size:12.5px; color:var(--text-700); margin-top:8px;">Daily hormone injections to stimulate follicle growth, accompanied by regular ultrasound monitoring scans.</p>
          <button class="btn btn-secondary btn-sm" style="margin-top:10px;" @click="$router.push('/patient/treatment')">View full treatment planner <Icon name="arrow-right" :size="12" /></button>
        </div>
      </div>

      <div style="display:flex; flex-direction:column; gap:18px;">
        <div class="card card-pad">
          <h3 style="font-size:13.5px;">Quick Links</h3>
          <div style="display:flex; flex-direction:column; gap:8px; margin-top:12px;">
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push('/patient/appointments')"><Icon name="calendar" :size="14" /> Book an appointment</button>
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push('/patient/results')"><Icon name="file" :size="14" /> View results &amp; invoices</button>
            <button class="btn btn-secondary btn-block" style="justify-content:flex-start;" @click="$router.push('/patient/payments')"><Icon name="cash" :size="14" /> View payment plan</button>
          </div>
        </div>
        <div class="card card-pad">
          <h3 style="font-size:13.5px;">Need help?</h3>
          <p class="muted" style="font-size:12px; margin-top:8px;">
            Questions about your results or medications are best discussed during your next scheduled consultation with {{ assignedDoctorName || 'your doctor' }}.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { fmtDate, fmtNaira, formatTime12 } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { queueOrRun } = useSyncQueue()
const patientId = profile.value!.patient_id!

const firstName = ref('')
const assignedDoctorName = ref('')
const activeCycle = ref<any>(null)
const nextAppointment = ref<any>(null)
const activeMilestone = ref<any>(null)
const todaysMeds = ref<any[]>([])
const takenToday = reactive(new Set<string>())

const { data } = await useAsyncData(`patient-home-${patientId}`, async () => {
  const today = new Date().toISOString().slice(0, 10)

  const [nameRes, bioRes, cycleRes, apptRes, planRes, rxRes, adherenceRes] = await Promise.all([
    supabase.from('patient_names').select('first_name').eq('patient_id', patientId).single(),
    supabase.from('bio_details').select('assigned_doctor_id, profiles:assigned_doctor_id(full_name)').eq('patient_id', patientId).maybeSingle(),
    // "Current" cycle = most recent one that isn't closed — bio_details/patient_names
    // has no explicit "active cycle" pointer column in the real schema (the prototype's
    // mock data had one, `activeCycleId`); this is the closest faithful equivalent.
    supabase.from('cycles').select('*').eq('patient_id', patientId).neq('status', 'Closed').order('start_date', { ascending: false }).limit(1).maybeSingle(),
    supabase.from('appointments').select('*').eq('patient_id', patientId).gte('date', today).order('date', { ascending: true }).order('time', { ascending: true }).limit(1).maybeSingle(),
    supabase.from('payment_plans').select('id, payment_milestones(*)').eq('patient_id', patientId),
    supabase.from('prescriptions').select('*').eq('patient_id', patientId).eq('status', 'Pending').order('date', { ascending: false }).limit(4),
    supabase.from('medication_adherence').select('prescription_id').eq('patient_id', patientId).eq('taken_on', today),
  ])

  const failed = [nameRes, bioRes, cycleRes, apptRes, planRes, rxRes, adherenceRes].find((result) => result.error)
  if (failed?.error) throw failed.error

  const milestones = (planRes.data || []).flatMap((p: any) => p.payment_milestones || [])
  const nextMilestone = milestones.filter((m: any) => m.status !== 'Paid').sort((a: any, b: any) => a.created_at?.localeCompare(b.created_at))[0] || null

  return {
    firstName: nameRes.data?.first_name || '',
    assignedDoctorName: (bioRes.data as any)?.profiles?.full_name || '',
    activeCycle: cycleRes.data,
    nextAppointment: apptRes.data,
    activeMilestone: nextMilestone,
    todaysMeds: rxRes.data || [],
    takenToday: (adherenceRes.data || []).map((row: any) => row.prescription_id),
  }
})

if (data.value) {
  firstName.value = data.value.firstName
  assignedDoctorName.value = data.value.assignedDoctorName
  activeCycle.value = data.value.activeCycle
  nextAppointment.value = data.value.nextAppointment
  activeMilestone.value = data.value.activeMilestone
  todaysMeds.value = data.value.todaysMeds
  data.value.takenToday.forEach((id: string) => takenToday.add(id))
}

const nextAppointmentDayLabel = computed(() => {
  if (!nextAppointment.value) return ''
  const today = new Date()
  const apptDate = new Date(nextAppointment.value.date)
  const diffDays = Math.round((apptDate.setHours(0, 0, 0, 0) - today.setHours(0, 0, 0, 0)) / 86400000)
  if (diffDays === 0) return 'Today'
  if (diffDays === 1) return 'Tomorrow'
  return fmtDate(nextAppointment.value.date)
})

async function markTaken(id: string, medication: string) {
  if (takenToday.has(id)) return
  const today = new Date().toISOString().slice(0, 10)
  await queueOrRun(
    `${medication} logged as taken`,
    {
      table: 'medication_adherence',
      kind: 'insert',
      payload: {
        id: crypto.randomUUID(),
        prescription_id: id,
        patient_id: patientId,
        taken_on: today,
        recorded_by: profile.value!.id,
      },
    },
    () => takenToday.add(id),
  )
}
</script>
