<template>
  <div v-if="patient">
    <div class="page-header">
      <div><h1>Investigations &amp; Ultrasound Scans</h1><div class="desc">{{ patient.full_name }} · {{ patient.patient_id }}</div></div>
      <div class="page-actions">
        <select class="input" :value="patient.patient_id" @change="loadPatient(($event.target as HTMLSelectElement).value)">
          <option v-for="p in patients" :key="p.patient_id" :value="p.patient_id">{{ p.full_name }}</option>
        </select>
      </div>
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header"><h3><Icon name="flask" :size="15" /> Female Investigations</h3><span class="link" @click="showHistory = true">View History</span></div>
        <table v-if="investigations.length" class="data-table">
          <thead><tr><th>Hormone</th><th>Value</th><th>Unit</th><th>Ref. Range</th><th>Date</th></tr></thead>
          <tbody>
            <tr v-for="i in investigations" :key="i.id">
              <td class="cell-strong">{{ i.hormone }}</td>
              <td :style="{ color: i.flag ? 'var(--red-600)' : 'var(--text-900)', fontWeight: i.flag ? 700 : 500 }">{{ i.value }} {{ i.flag ? '⚠' : '' }}</td>
              <td class="cell-muted">{{ i.unit }}</td>
              <td class="cell-muted">{{ i.ref_range }}</td>
              <td class="cell-muted">{{ fmtDate(i.date) }}</td>
            </tr>
          </tbody>
        </table>
        <div v-else style="padding:20px;"><EmptyState icon="flask" title="No investigations logged" description="Lab values will appear here once entered by the lab team." /></div>
      </div>
      <div style="display:flex; flex-direction:column; gap:16px;">
        <div class="card card-pad">
          <b style="font-size:13px;"><Icon name="layers" :size="13" /> Patient Demographics</b>
          <div class="grid grid-2" style="margin-top:10px; gap:10px;">
            <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:700;">{{ computeAge(patient.dob) }} years</div></div>
            <div><div class="muted" style="font-size:10.5px;">CYCLE DAY</div><div style="font-weight:700; color:var(--blue-600);">{{ cycle ? 'CD ' + cycle.cycle_day : '—' }}</div></div>
          </div>
        </div>
        <div v-if="ultrasound" class="card card-pad">
          <b style="font-size:13px;"><Icon name="activity" :size="13" /> Latest Follicular Tracking Scan</b>
          <div class="flex-between" style="margin-top:8px;"><span class="cell-muted">Endometrial Thickness</span><b>{{ ultrasound.endometrial }} mm</b></div>
          <hr class="hr" />
          <div style="font-size:11.5px; font-weight:700; color:var(--text-500); margin-bottom:6px;">RIGHT OVARY</div>
          <div class="flex gap-8" style="flex-wrap:wrap;"><span v-for="(v, i) in ultrasound.right_ovary || []" :key="i" class="badge badge-blue">{{ v }}mm</span></div>
          <div style="font-size:11.5px; font-weight:700; color:var(--text-500); margin:10px 0 6px;">LEFT OVARY</div>
          <div class="flex gap-8" style="flex-wrap:wrap;"><span v-for="(v, i) in ultrasound.left_ovary || []" :key="i" class="badge badge-blue">{{ v }}mm</span></div>
        </div>
        <div class="card card-pad">
          <b style="font-size:13px;">Clinical Observations</b>
          <p style="font-size:12px; color:var(--text-700); margin-top:8px;">{{ cycle?.physician_notes || 'No observations logged for this patient yet.' }}</p>
        </div>
      </div>
    </div>
    <PatientDetailModal v-model="showHistory" :patient="patient" :cycle="cycle" :consultations="[]" :lab-results="[]" :caps="{}" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const patients = ref<any[]>([])
const patient = ref<any>(null)
const cycle = ref<any>(null)
const investigations = ref<any[]>([])
const ultrasound = ref<any>(null)
const showHistory = ref(false)

async function loadPatient(patientId: string) {
  const [bioRes, cycleRes] = await Promise.all([
    supabase.from('bio_details').select('*, patient_names(full_name)').eq('patient_id', patientId).single(),
    supabase.from('cycles').select('*').eq('patient_id', patientId).neq('status', 'Closed').order('start_date', { ascending: false }).limit(1).maybeSingle(),
  ])
  patient.value = bioRes.data ? { ...bioRes.data, full_name: bioRes.data.patient_names?.full_name } : null
  cycle.value = cycleRes.data

  if (cycle.value) {
    const [invRes, usRes] = await Promise.all([
      supabase.from('cycle_investigations').select('*').eq('cycle_id', cycle.value.id).order('date', { ascending: false }),
      supabase.from('cycle_ultrasounds').select('*').eq('cycle_id', cycle.value.id).order('date', { ascending: false }).limit(1).maybeSingle(),
    ])
    investigations.value = invRes.data || []
    ultrasound.value = usRes.data
  } else {
    investigations.value = []
    ultrasound.value = null
  }
}

await useAsyncData('doctor-investigations-init', async () => {
  const { data } = await supabase.from('patient_names').select('patient_id, full_name').order('full_name', { ascending: true })
  patients.value = data || []
  if (patients.value[0]) await loadPatient(patients.value[0].patient_id)
  return true
})
</script>
