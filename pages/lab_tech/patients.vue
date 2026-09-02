<template>
  <div>
    <div class="page-header"><div><h1>Patients</h1><div class="desc">Lab-relevant identity and partner (SFA) context.</div></div></div>
    <div class="card">
      <div style="padding:14px 20px; border-bottom:1px solid var(--border);">
        <div class="search-box" style="max-width:320px;">
          <Icon name="search" :size="14" />
          <input v-model="search" placeholder="Search name or ID…" />
        </div>
      </div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>ID</th><th>Age</th><th>Blood Group</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.patient_id" class="clickable" @click="openProfile(p.patient_id)">
            <td class="cell-strong">{{ p.full_name }}</td>
            <td class="cell-muted mono">{{ p.patient_id }}</td>
            <td>{{ computeAge(p.dob) }}</td>
            <td class="cell-muted">{{ p.blood_group || '—' }}</td>
            <td><StatusBadge :status="p.status" /></td>
            <td style="text-align:right;"><Icon name="chevron-right" :size="14" /></td>
          </tr>
        </tbody>
      </table>
      <div v-if="!filtered.length" style="padding:20px;"><EmptyState icon="search" title="No matches" description="Try a different name or ID." /></div>
    </div>

    <Modal v-model="showProfile" :title="activeProfile?.full_name || ''">
      <template v-if="activeProfile">
        <div class="grid grid-4" style="gap:10px; margin-bottom:14px;">
          <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.patient_id }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(activeProfile.dob) }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.blood_group || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="activeProfile.status" /></div>
        </div>
        <template v-if="activeProfile.spouse">
          <hr class="hr" />
          <b style="font-size:12.5px;"><Icon name="user" :size="12" /> Spouse / Partner</b>
          <div class="grid grid-3" style="margin-top:8px; gap:10px;">
            <div><div class="muted" style="font-size:10.5px;">NAME</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.spouse.name || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.spouse.bloodGroup || '—' }}</div></div>
            <div><div class="muted" style="font-size:10.5px;">SFA RESULT</div><div style="font-weight:600; font-size:12.5px;">{{ activeProfile.spouse.sfa || 'Not on file' }}</div></div>
          </div>
        </template>
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="layers" :size="12" /> Treatment Cycle</b>
        <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
          {{ activeCycle ? `${activeCycle.type} — ${activeCycle.stage} (Day ${activeCycle.cycle_day})` : 'No active treatment cycle.' }}
        </p>
        <div v-if="activeCycle" style="margin-top:10px;">
          <CycleDayChart :cycle-id="activeCycle.id" :start-date="activeCycle.start_date" :can-edit="false" />
        </div>
      </template>
      <template #footer>
        <button class="btn btn-secondary" @click="showProfile = false">Close</button>
        <button class="btn btn-primary" @click="showProfile = false; $router.push(`/lab_tech/results?patient=${activeProfile.patient_id}`)"><Icon name="flask" :size="13" /> Enter Results</button>
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
const showProfile = ref(false)
const activeProfile = ref<any>(null)
const activeCycle = ref<any>(null)

await useAsyncData('lab-tech-patients', async () => {
  const { data } = await supabase.rpc('patients_lab_directory', { p_search: '' })
  patients.value = data || []
  return true
})

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((p) => (p.full_name + p.patient_id).toLowerCase().includes(q))
})

async function openProfile(patientId: string) {
  const { data } = await supabase.rpc('patient_lab_profile', { p_patient_id: patientId })
  activeProfile.value = data?.[0] || null
  showProfile.value = true

  // Cycle info comes from a direct table read (now that Lab Tech has
  // read-only RLS on cycles/cycle_daily_logs) rather than the RPC above —
  // additive, so the existing patients_lab_directory/patient_lab_profile
  // RPCs (deliberately scoped to lab-relevant fields only) don't need to
  // change shape.
  const { data: cycleData } = await supabase
    .from('cycles')
    .select('*')
    .eq('patient_id', patientId)
    .neq('status', 'Closed')
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle()
  activeCycle.value = cycleData
}

watch(() => route.query.patient, (patientId) => {
  if (typeof patientId === 'string') void openProfile(patientId)
}, { immediate: true })
</script>
