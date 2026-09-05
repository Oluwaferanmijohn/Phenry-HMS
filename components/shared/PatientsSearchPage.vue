<template>
  <div>
    <div class="page-header"><div><h1>Patients</h1><div class="desc">Search the patients available within your role.</div></div></div>
    <div v-if="directoryStatus === 'pending'" class="card card-pad">
      <div class="cell-muted">Loading accessible patients…</div>
    </div>
    <div v-else-if="directoryError" class="card card-pad">
      <EmptyState icon="alert" title="Patients could not be loaded" description="The patient directory is temporarily unavailable. Your access has not been changed." />
      <div style="margin-top:12px; text-align:center;"><button class="btn btn-secondary btn-sm" @click="retryDirectory">Try Again</button></div>
    </div>
    <div v-else class="card">
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
        <EmptyState
          icon="search"
          :title="search ? 'No matches' : 'No accessible patients'"
          :description="search ? 'Try a different name or ID.' : 'No patients are currently available within this account’s clinical scope.'"
        />
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
      @record-vitals="$router.push(`/nurse/vitals?patient=${activePatient.patient_id}`)"
      @go-to-visit="$router.push(`/nurse/visit?patient=${activePatient.patient_id}`)"
      @enter-lab-result="$router.push(`/${profile?.role}/results?patient=${activePatient.patient_id}`)"
      @upload-external="$router.push(`/${profile?.role}/results?patient=${activePatient.patient_id}&external=1`)"
      @open-spouse="openLinkedSpouse"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { computeAge } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'
import { fetchClinicalPatientContext, fetchClinicalPatientDirectory } from '~/composables/useClinicalPatientAccess'
import { useRecentPatientCache } from '~/composables/useRecentPatientCache'
import { useToast } from '~/composables/useToast'

const { loadWithCache } = useRecentPatientCache()
const { toast } = useToast()

type PatientActionCaps = { allowConsultation?: boolean; allowVisitDoc?: boolean; allowVitals?: boolean; allowLabEntry?: boolean; allowExternalUpload?: boolean }
const ROLE_PATIENT_CAPS: Record<string, PatientActionCaps> = {
  doctor: { allowConsultation: true },
  matron: { allowConsultation: true },
  nurse: { allowVitals: true, allowVisitDoc: true },
  admin_manager: { allowConsultation: false },
  chief_embryologist: { allowLabEntry: true, allowExternalUpload: true },
  lab_tech: { allowLabEntry: true, allowExternalUpload: true },
}

const supabase = useSupabaseClient()
const profile = useProfile()
const route = useRoute()
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
// The cache key must include the authenticated profile. A shared, constant key
// allowed Nuxt to reuse another user's `true` result without running this
// loader, leaving these component-local arrays empty after role switches.
interface PatientDirectoryPayload {
  patients: any[]
  activeCycles: any[]
}

const directoryKey = `patient-directory-${profile.value?.id || 'anonymous'}-${profile.value?.role || 'unknown'}`
const {
  data: directoryData,
  error: directoryError,
  status: directoryStatus,
  refresh: refreshDirectory,
} = await useAsyncData<PatientDirectoryPayload>(directoryKey, async () => {
  if (profile.value?.role === 'lab_tech') {
    const [patientRes, cycleRes] = await Promise.all([
      supabase.rpc('patients_lab_directory', { p_search: '' }),
      supabase.from('cycles').select('*').neq('status', 'Closed').order('start_date', { ascending: false }),
    ])
    if (patientRes.error) throw patientRes.error
    if (cycleRes.error) throw cycleRes.error
    return { patients: patientRes.data || [], activeCycles: cycleRes.data || [] }
  }
  return fetchClinicalPatientDirectory(supabase)
}, {
  default: () => ({ patients: [], activeCycles: [] }),
  // Reuse only the SSR payload during hydration; later page entries must hit
  // RLS again so a new patient or a changed assignment appears immediately.
  getCachedData: (key, nuxtApp) => nuxtApp.isHydrating ? nuxtApp.payload.data[key] : undefined,
})

function applyDirectory(payload: PatientDirectoryPayload | null | undefined) {
  patients.value = payload?.patients || []
  const byPatient: Record<string, any> = {}
  for (const c of payload?.activeCycles || []) if (!byPatient[c.patient_id]) byPatient[c.patient_id] = c
  activeCycleByPatient.value = byPatient
}

watch(directoryData, applyDirectory, { immediate: true })

async function retryDirectory() {
  await refreshDirectory()
  applyDirectory(directoryData.value)
}

const filtered = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return patients.value
  return patients.value.filter((p) => (p.full_name + p.patient_id).toLowerCase().includes(q))
})

async function openDetail(patientId: string) {
  const selected = patients.value.find((p) => p.patient_id === patientId)
  if (!selected) return
  activePatient.value = selected
  showDetail.value = true

  // Cached so this detail view still opens offline for any patient already
  // looked at on this device — see useRecentPatientCache.
  try {
    const { data } = await loadWithCache(patientId, async () => {
      // Doctor, Matron, and Admin use the same explicit patient-context API as
      // their workspaces. Lab technicians keep the deliberately restricted
      // laboratory directory and only load result records here. Chief
      // Embryologist and Nurse retain their table-RLS detail reads.
      if (['doctor', 'matron', 'admin_manager'].includes(profile.value?.role || '')) {
        const context = await fetchClinicalPatientContext(supabase, patientId)
        return {
          consultations: context.pastConsultations,
          labResults: context.pastLabResults,
        }
      }

      if (profile.value?.role === 'lab_tech') {
        const labRes = await supabase.from('lab_results').select('*, lab_templates(name)').eq('patient_id', patientId).order('collected_on', { ascending: false })
        if (labRes.error) throw labRes.error
        return { consultations: [], labResults: labRes.data || [] }
      }

      const [consultRes, labRes] = await Promise.all([
        supabase.from('consultations').select('*, profiles:provider_profile_id(full_name)').eq('patient_id', patientId).order('date', { ascending: false }),
        supabase.from('lab_results').select('*, lab_templates(name)').eq('patient_id', patientId).order('collected_on', { ascending: false }),
      ])
      if (consultRes.error) throw consultRes.error
      if (labRes.error) throw labRes.error
      return {
        consultations: (consultRes.data || []).map((c: any) => ({ ...c, provider_name: c.profiles?.full_name || 'Staff' })),
        labResults: labRes.data || [],
      }
    })

    activeConsultations.value = data?.consultations || []
    activeLabResults.value = data?.labResults || []
  } catch {
    showDetail.value = false
    activePatient.value = null
    activeConsultations.value = []
    activeLabResults.value = []
    toast('Patient details could not be loaded. Check your connection and try again.', 'warn')
  }
}

async function openLinkedSpouse(spousePatientId: string) {
  const linkedFromPatientId = activePatient.value?.patient_id
  if (!linkedFromPatientId) return
  await openLinkedSpouseFrom(linkedFromPatientId, spousePatientId)
}

async function openLinkedSpouseFrom(linkedFromPatientId: string, spousePatientId: string) {
  if (patients.value.some((patient) => patient.patient_id === spousePatientId)) {
    await openDetail(spousePatientId)
    return
  }

  const { data, error } = await supabase.rpc('linked_spouse_patient_detail', {
    p_from_patient_id: linkedFromPatientId,
    p_spouse_patient_id: spousePatientId,
  })
  if (error || !data) {
    toast('The linked spouse details are not available to this account.', 'warn')
    return
  }
  activePatient.value = data
  activeConsultations.value = []
  activeLabResults.value = []
  showDetail.value = true
}

watch(() => [route.query.patient, route.query.linkedFrom] as const, ([patientId, linkedFrom]) => {
  if (typeof patientId !== 'string') return
  if (patients.value.some((patient) => patient.patient_id === patientId)) void openDetail(patientId)
  else if (typeof linkedFrom === 'string') void openLinkedSpouseFrom(linkedFrom, patientId)
}, { immediate: true })
</script>
