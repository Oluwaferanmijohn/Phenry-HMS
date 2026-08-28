<template>
  <div>
    <div class="page-header"><div><h1>Patients</h1><div class="desc">Search the full patient roster.</div></div></div>
    <div class="card">
      <div style="padding:14px 20px; border-bottom:1px solid var(--border);">
        <div class="search-box" style="max-width:320px;">
          <Icon name="search" :size="14" />
          <input v-model="search" placeholder="Search name or ID…" />
        </div>
      </div>
      <table class="data-table">
        <thead><tr><th>Patient</th><th>ID</th><th>Age</th><th>Status</th><th>Active Cycle</th><th></th></tr></thead>
        <tbody>
          <tr v-for="p in filtered" :key="p.patient_id" class="clickable" @click="openDetail(p.patient_id)">
            <td class="cell-strong">{{ p.full_name }}</td>
            <td class="cell-muted mono">{{ p.patient_id }}</td>
            <td>{{ computeAge(p.dob) }}</td>
            <td><StatusBadge :status="p.status" /></td>
            <td class="cell-muted">{{ activeCycleByPatient[p.patient_id] ? `${activeCycleByPatient[p.patient_id].type} — ${activeCycleByPatient[p.patient_id].stage}` : 'None' }}</td>
            <td style="text-align:right;"><Icon name="chevron-right" :size="14" /></td>
          </tr>
        </tbody>
      </table>
      <div v-if="!filtered.length" style="padding:20px;">
        <EmptyState icon="search" title="No matches" description="Try a different name or ID." />
      </div>
    </div>

    <PatientDetailModal
      v-model="showDetail"
      :patient="activePatient"
      :cycle="activeCycleByPatient[activePatient?.patient_id]"
      :consultations="activeConsultations"
      :lab-results="activeLabResults"
      :caps="caps"
      @start-consultation="$router.push(`/${profile?.role}/consultation?patient=${activePatient.patient_id}`)"
      @go-to-visit="$router.push(`/nurse/visit?patient=${activePatient.patient_id}`)"
      @upload-external="$router.push(`/${profile?.role}/results?patient=${activePatient.patient_id}`)"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { computeAge } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'
import { useRecentPatientCache } from '~/composables/useRecentPatientCache'

const { loadWithCache } = useRecentPatientCache()

const ROLE_PATIENT_CAPS: Record<string, { allowConsultation?: boolean; allowVisitDoc?: boolean; allowLabActions?: boolean }> = {
  doctor: { allowConsultation: true },
  matron: { allowConsultation: true },
  nurse: { allowConsultation: false, allowVisitDoc: true },
  admin_manager: { allowConsultation: false },
  chief_embryologist: { allowConsultation: false, allowLabActions: true },
  lab_tech: { allowConsultation: false, allowLabActions: true },
}

const supabase = useSupabaseClient()
const profile = useProfile()
const caps = computed(() => ROLE_PATIENT_CAPS[profile.value?.role ?? ''] || {})

const search = ref('')
const patients = ref<any[]>([])
const activeCycleByPatient = ref<Record<string, any>>({})
const showDetail = ref(false)
const activePatient = ref<any>(null)
const activeConsultations = ref<any[]>([])
const activeLabResults = ref<any[]>([])

// RLS scopes the rows returned here differently per role (full for Admin,
// assigned/waiting-room for Doctor, assigned for Nurse, etc. — see each
// role's migration) — the query itself is identical for all of them.
await useAsyncData('shared-patients-list', async () => {
  const [bioRes, cyclesRes] = await Promise.all([
    supabase.from('bio_details').select('*, patient_names(full_name)'),
    supabase.from('cycles').select('*').neq('status', 'Closed').order('start_date', { ascending: false }),
  ])
  patients.value = (bioRes.data || []).map((b: any) => ({ ...b, full_name: b.patient_names?.full_name || 'Unknown' }))
  const byPatient: Record<string, any> = {}
  for (const c of cyclesRes.data || []) if (!byPatient[c.patient_id]) byPatient[c.patient_id] = c
  activeCycleByPatient.value = byPatient
  return true
})

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((p) => (p.full_name + p.patient_id).toLowerCase().includes(q))
})

async function openDetail(patientId: string) {
  activePatient.value = patients.value.find((p) => p.patient_id === patientId)
  showDetail.value = true

  // Cached so this detail view still opens offline for any patient already
  // looked at on this device — see useRecentPatientCache.
  const { data } = await loadWithCache(patientId, async () => {
    const [consultRes, labRes] = await Promise.all([
      supabase.from('consultations').select('*, profiles:provider_profile_id(full_name)').eq('patient_id', patientId).order('date', { ascending: false }),
      supabase.from('lab_results').select('*, lab_templates(name)').eq('patient_id', patientId).order('collected_on', { ascending: false }),
    ])
    return {
      consultations: (consultRes.data || []).map((c: any) => ({ ...c, provider_name: c.profiles?.full_name || 'Staff' })),
      labResults: labRes.data || [],
    }
  })

  activeConsultations.value = data?.consultations || []
  activeLabResults.value = data?.labResults || []
}
</script>
