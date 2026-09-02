<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Patients</h1>
        <div class="desc">{{ patients.length }} patients registered</div>
      </div>
      <div class="page-actions">
        <button class="btn btn-primary" @click="$router.push('/receptionist/register')"><Icon name="plus" :size="14" /> New Patient</button>
      </div>
    </div>

    <div class="card">
      <div style="padding:14px 20px; border-bottom:1px solid var(--border);">
        <div class="search-box" style="max-width:320px;">
          <Icon name="search" :size="14" />
          <input v-model="search" placeholder="Search name or ID…" />
        </div>
      </div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>ID</th><th>Age</th><th>Status</th><th>Assigned Doctor</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.patient_id" class="clickable" @click="openProfile(p.patient_id)">
            <td class="cell-strong">{{ p.full_name }}</td>
            <td class="cell-muted mono">{{ p.patient_id }}</td>
            <td>{{ computeAge(p.dob) }}</td>
            <td><StatusBadge :status="p.status" /></td>
            <td class="cell-muted">{{ doctorNames[p.assigned_doctor_id] || '—' }}</td>
            <td style="text-align:right;"><Icon name="chevron-right" :size="14" /></td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal v-model="showProfile" :title="activeProfile?.full_name || ''">
      <template v-if="activeProfile">
        <div class="grid grid-4" style="gap:10px; margin-bottom:16px;">
          <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.patient_id }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(activeProfile.dob) }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.blood_group || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="activeProfile.status" /></div>
        </div>
        <hr class="hr" />
        <b style="font-size:13px;">Contact</b>
        <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);"><Icon name="phone" :size="11" /> {{ activeProfile.phone || '—' }} &nbsp; <Icon name="mail" :size="11" /> {{ activeProfile.email || '—' }}</p>
        <p style="font-size:12.5px; color:var(--text-700);">{{ activeProfile.address || '—' }}</p>
        <hr class="hr" />
        <b style="font-size:13px;">Emergency Contact</b>
        <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
          {{ activeProfile.emergency_contact?.name || '—' }} ({{ activeProfile.emergency_contact?.relationship || '—' }}) · {{ activeProfile.emergency_contact?.phone || '—' }}
        </p>
      </template>
      <template #footer>
        <button class="btn btn-secondary" @click="showProfile = false">Close</button>
        <button class="btn btn-primary" @click="showProfile = false; $router.push('/receptionist/book')"><Icon name="calendar" :size="13" /> Book Visit</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { computeAge } from '~/composables/useFormat'

const supabase = useSupabaseClient()
const route = useRoute()
const search = ref('')
const patients = ref<any[]>([])
const doctorNames = ref<Record<string, string>>({})
const showProfile = ref(false)
const activeProfile = ref<any>(null)

await useAsyncData('receptionist-patients', async () => {
  const [patientsRes, doctorsRes] = await Promise.all([
    supabase.rpc('patients_front_desk_directory', { p_search: '' }),
    supabase.from('profiles').select('id, full_name').eq('role', 'doctor'),
  ])
  patients.value = patientsRes.data || []
  doctorNames.value = Object.fromEntries((doctorsRes.data || []).map((d: any) => [d.id, d.full_name]))
  return true
})

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((p) => (p.full_name + p.patient_id).toLowerCase().includes(q))
})

async function openProfile(patientId: string) {
  const { data } = await supabase.rpc('patient_front_desk_profile', { p_patient_id: patientId })
  activeProfile.value = data?.[0] || null
  showProfile.value = true
}

watch(() => route.query.patient, (patientId) => {
  if (typeof patientId === 'string') void openProfile(patientId)
}, { immediate: true })
</script>
