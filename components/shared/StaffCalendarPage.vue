<template>
  <div>
    <div class="page-header">
      <div>
        <h1>{{ editable ? 'Staff Allocation & Shift Calendar' : 'My Shift Calendar' }}</h1>
        <div class="desc">{{ editable ? 'Click a date to set Morning, Afternoon, and Night duty — assigned by time, not by ward.' : "Days you're on duty are highlighted. Click a date for details." }}</div>
      </div>
    </div>
    <div class="card card-pad">
      <b style="font-size:14px;">{{ monthLabel }}</b>
      <div class="month-cal" style="margin-top:12px;">
        <div class="dow">Sun</div><div class="dow">Mon</div><div class="dow">Tue</div><div class="dow">Wed</div><div class="dow">Thu</div><div class="dow">Fri</div><div class="dow">Sat</div>
        <div v-for="n in startOffset" :key="'pad' + n" class="month-cell empty" />
        <div
          v-for="d in daysInMonth"
          :key="d"
          class="month-cell"
          :class="{ 'has-me': !editable && isMyDay(d) }"
          @click="editable ? openAssign(d) : openView(d)"
        >
          <div class="d-num">{{ d }}</div>
          <div style="display:flex; flex-wrap:wrap; gap:3px;">
            <span v-if="rosterFor(d).morning?.length" class="shift-chip shift-am">AM {{ rosterFor(d).morning.length }}</span>
            <span v-if="rosterFor(d).afternoon?.length" class="shift-chip shift-pm">PM {{ rosterFor(d).afternoon.length }}</span>
            <span v-if="rosterFor(d).night?.length" class="shift-chip shift-ni">Night {{ rosterFor(d).night.length }}</span>
          </div>
        </div>
      </div>
      <div class="flex gap-14" style="margin-top:14px; font-size:11.5px;">
        <span class="shift-chip shift-am">AM</span> Morning &nbsp; <span class="shift-chip shift-pm">PM</span> Afternoon &nbsp; <span class="shift-chip shift-ni">Night</span> Night
        <template v-if="!editable">&nbsp; <span class="badge badge-blue">Highlighted</span> = your shift</template>
      </div>
    </div>

    <AssignDutyModal v-if="editable" v-model="showAssign" :date-str="activeDateStr" @saved="load" />
    <ViewDutyDayModal v-else v-model="showView" :date-str="activeDateStr" :my-name="myName" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ editable?: boolean }>()

const supabase = useSupabaseClient()
const profile = useProfile()

const today = new Date()
const year = today.getFullYear()
const month = today.getMonth()
const monthLabel = today.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })
const startOffset = new Date(year, month, 1).getDay()
const daysInMonth = new Date(year, month + 1, 0).getDate()

const roster = ref<Record<string, any>>({})
const myName = ref('')
const showAssign = ref(false)
const showView = ref(false)
const activeDateStr = ref('')

function dateStrFor(d: number) {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}
function rosterFor(d: number) {
  return roster.value[dateStrFor(d)] || { morning: [], afternoon: [], night: [] }
}
function isMyDay(d: number) {
  const r = rosterFor(d)
  return r.morning?.includes(myName.value) || r.afternoon?.includes(myName.value) || r.night?.includes(myName.value)
}

async function load() {
  const start = dateStrFor(1)
  const end = dateStrFor(daysInMonth)
  const { data } = await supabase.from('duty_roster').select('*').gte('date', start).lte('date', end)
  roster.value = Object.fromEntries((data || []).map((r: any) => [r.date, r]))
  myName.value = profile.value?.full_name || ''
}
await useAsyncData(`staff-calendar-${props.editable}`, load)

function openAssign(d: number) {
  activeDateStr.value = dateStrFor(d)
  showAssign.value = true
}
function openView(d: number) {
  activeDateStr.value = dateStrFor(d)
  showView.value = true
}
</script>
