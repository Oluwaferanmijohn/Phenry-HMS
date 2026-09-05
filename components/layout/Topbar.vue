<template>
  <div class="topbar">
    <div class="breadcrumb"><b>{{ meta?.label }}</b> <span>/</span> <span>{{ activeLabel }}</span></div>
    <div v-if="canSearch" class="search-box" style="position:relative;">
      <Icon name="search" :size="14" />
      <input v-model="query" placeholder="Search patients or IDs…" @input="scheduleSearch" @focus="showResults = true" @blur="hideResults" @keydown.enter.prevent="results[0] && openPatient(results[0].patient_id)" @keydown.escape="showResults = false" />
      <div v-if="showResults && query.trim().length >= 2" class="card" style="position:absolute;top:38px;left:0;right:0;z-index:40;max-height:280px;overflow:auto;box-shadow:var(--shadow-md);">
        <div v-if="searching" class="cell-muted" style="padding:12px;">Searching…</div>
        <div v-else-if="searchError" style="padding:12px; color:var(--red-600); font-size:11.5px;">{{ searchError }}</div>
        <button v-for="patient in results" :key="patient.patient_id" class="list-row clickable" style="width:100%;text-align:left;border:0;background:transparent;" @mousedown.prevent="openPatient(patient.patient_id)">
          <div><div class="main-txt">{{ patient.full_name }}</div><div class="sub-txt mono">{{ patient.patient_id }}</div></div>
        </button>
        <div v-if="!searching && !searchError && !results.length" class="cell-muted" style="padding:12px;">No accessible patients found.</div>
      </div>
    </div>
    <SyncPill />
    <button v-if="role === 'admin_manager'" class="icon-btn" title="Clinic settings" @click="$router.push('/admin_manager/settings')">
      <Icon name="settings" :size="15" />
    </button>
    <div class="topbar-user">
      <Avatar :name="displayName" :size="32" />
      <div class="who">
        <div class="name">{{ displayName }}</div>
        <div class="role">{{ roleLabel }}</div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { ROLE_META } from '~/composables/useRoleMeta'
import { useProfile } from '~/composables/useAuth'

const props = defineProps<{ role: string; activePage: string }>()
const profile = useProfile()
const router = useRouter()
const supabase = useSupabaseClient()
const query = ref('')
const results = ref<any[]>([])
const searching = ref(false)
const searchError = ref('')
const showResults = ref(false)
let timer: ReturnType<typeof setTimeout> | null = null
const canSearch = computed(() => ['receptionist', 'admin_manager', 'doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech'].includes(props.role))

const meta = computed(() => ROLE_META[props.role])
const activeLabel = computed(() => meta.value?.nav.find((n) => n.id === props.activePage)?.label ?? '')
const displayName = computed(() => profile.value?.full_name || 'Account')
const roleLabel = computed(() => meta.value?.label || props.role)

function scheduleSearch() {
  if (timer) clearTimeout(timer)
  timer = setTimeout(searchPatients, 250)
}

async function searchPatients() {
  const term = query.value.trim().replace(/[,()"']/g, '').slice(0, 80)
  if (term.length < 2) {
    results.value = []
    return
  }
  searching.value = true
  searchError.value = ''
  try {
    const { data, error } = await supabase.rpc('global_patient_search', { p_search: term })
    if (error) throw error
    results.value = data || []
    showResults.value = true
  } catch (error: any) {
    results.value = []
    searchError.value = String(error?.message || '').includes('global_patient_search')
      ? 'Global search needs the latest database migration.'
      : 'Search is temporarily unavailable. Check your connection and try again.'
  } finally {
    searching.value = false
  }
}

function hideResults() {
  window.setTimeout(() => { showResults.value = false }, 150)
}

async function openPatient(patientId: string) {
  showResults.value = false
  searchError.value = ''
  query.value = ''
  await router.push(`/${props.role}/patients?patient=${encodeURIComponent(patientId)}`)
}
</script>
