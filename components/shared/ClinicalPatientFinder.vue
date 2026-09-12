<template>
  <div class="finder">
    <div class="finder-controls">
      <input v-model="query" class="input finder-query" placeholder="Search patient name, ID, or phone…" @focus="open = true" />
      <select v-model="period" class="input finder-period" aria-label="Date filter"><option value="all">Any date</option><option value="today">Today</option><option value="yesterday">Yesterday</option><option value="last_week">Last 7 days</option><option value="date">Choose date</option></select>
      <input v-if="period === 'date'" v-model="date" class="input finder-date" type="date" title="Registration, walk-in, or appointment date" />
      <select v-model="patientType" class="input finder-type" aria-label="Patient type"><option value="all">All patients</option><option value="walk_in">Walk-in</option><option value="appointment">Appointment</option><option value="registered">Registered only</option></select>
      <button v-if="allowWalkIn" class="btn btn-secondary" type="button" @click="showWalkIn = true"><Icon name="plus" :size="13" /> Walk-in</button>
    </div>
    <div v-if="open" class="finder-results card">
      <div v-if="loading" class="finder-empty">Searching patients…</div>
      <button v-for="entry in entries" :key="entry.patient_id" class="finder-result" type="button" @click="choose(entry)">
        <span><b>{{ entry.full_name }}</b><small>{{ entry.patient_id }} · {{ entry.phone || 'No phone' }}</small></span>
        <span class="finder-meta"><small>{{ entry.event_date || entry.registered_on }}</small><Badge :tone="entry.patient_type === 'walk_in' ? 'amber' : 'blue'">{{ typeLabel(entry.patient_type) }}</Badge></span>
      </button>
      <div v-if="!loading && !entries.length" class="finder-empty">No matching patients. Try another filter or register a walk-in.</div>
    </div>
    <Modal v-model="showWalkIn" title="Register walk-in patient" size="md">
      <p class="modal-copy">Creates a clinical record immediately so the nurse can take observations. Reception can complete portal and billing details later.</p>
      <div class="form-row"><div class="field"><label>First name *</label><input v-model="walkIn.firstName" class="input" /></div><div class="field"><label>Surname *</label><input v-model="walkIn.surname" class="input" /></div></div>
      <div class="form-row"><div class="field"><label>Date of birth *</label><input v-model="walkIn.dob" class="input" type="date" /></div><div class="field"><label>Sex *</label><select v-model="walkIn.sex" class="input"><option value="">Select</option><option>Female</option><option>Male</option><option>Intersex / another identity</option></select></div></div>
      <div class="field"><label>Phone</label><input v-model="walkIn.phone" class="input" inputmode="tel" /></div>
      <div class="field"><label>Reason for visit</label><textarea v-model="walkIn.reason" class="input" rows="2" placeholder="Main concern or reason for walk-in…" /></div>
      <template #footer><button class="btn btn-secondary" @click="showWalkIn=false">Cancel</button><button class="btn btn-primary" :disabled="creating" @click="registerWalkIn">{{ creating ? 'Creating…' : 'Create and select patient' }}</button></template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { useToast } from '~/composables/useToast'
const props = withDefaults(defineProps<{ modelValue?: string; allowWalkIn?: boolean; initialWalkInOpen?: boolean }>(), { modelValue: '', allowWalkIn: false, initialWalkInOpen: false })
const emit = defineEmits<{ 'update:modelValue': [value: string]; selected: [entry: any] }>()
const supabase = useSupabaseClient(); const { toast } = useToast()
const query = ref(''); const period = ref('all'); const date = ref(''); const patientType = ref('all'); const entries = ref<any[]>([]); const loading = ref(false); const open = ref(false); const showWalkIn = ref(props.initialWalkInOpen); const creating = ref(false)
watch(() => props.initialWalkInOpen, (value) => { if (value) showWalkIn.value = true })
const walkIn = reactive({ firstName: '', surname: '', dob: '', sex: '', phone: '', reason: '' })
let timer: ReturnType<typeof setTimeout> | undefined
async function search() { loading.value = true; const { data, error } = await supabase.rpc('clinical_patient_search_v2', { p_query: query.value.trim(), p_period: period.value, p_custom_date: period.value === 'date' ? date.value || null : null, p_patient_type: patientType.value, p_limit: 50 }); loading.value = false; if (error) { entries.value = []; toast('Patient search needs the latest database update.', 'warn'); return }; entries.value = data || [] }
watch([query, period, date, patientType], () => { open.value = true; clearTimeout(timer); timer = setTimeout(() => void search(), 220) }, { immediate: true })
function typeLabel(value: string) { return value === 'walk_in' ? 'Walk-in' : value === 'appointment' ? 'Appointment' : 'Registered' }
function choose(entry: any) { emit('update:modelValue', entry.patient_id); emit('selected', entry); open.value = false }
async function registerWalkIn() { if (!walkIn.firstName.trim() || !walkIn.surname.trim() || !walkIn.dob || !walkIn.sex) return toast('Enter the required walk-in details.', 'warn'); creating.value = true; const { data, error } = await supabase.rpc('register_walk_in_patient', { p_first_name: walkIn.firstName, p_surname: walkIn.surname, p_dob: walkIn.dob, p_sex: walkIn.sex, p_phone: walkIn.phone || null, p_reason: walkIn.reason || null, p_provider_id: null }); creating.value = false; if (error) return toast(error.message || 'Could not register walk-in patient', 'warn'); showWalkIn.value = false; Object.assign(walkIn, { firstName: '', surname: '', dob: '', sex: '', phone: '', reason: '' }); entries.value = [data, ...entries.value]; choose(data); toast('Walk-in patient created and selected.', 'success') }
</script>

<style scoped>
.finder { position:relative; min-width:min(760px, 100%); }.finder-controls { display:flex; gap:7px; align-items:center; flex-wrap:wrap; }.finder-query { min-width:220px; flex:1; }.finder-period { width:120px; }.finder-type { width:132px; }.finder-date { width:145px; }.finder-results { position:absolute; z-index:20; top:calc(100% + 6px); right:0; left:0; max-height:350px; overflow:auto; padding:5px; box-shadow:0 10px 28px rgba(15,23,42,.16); }.finder-result { width:100%; display:flex; justify-content:space-between; gap:16px; text-align:left; padding:10px; border:0; border-radius:7px; background:transparent; cursor:pointer; }.finder-result:hover { background:var(--blue-50); }.finder-result span { display:flex; flex-direction:column; gap:2px; }.finder-result b { font-size:12.5px; }.finder-result small,.finder-empty { color:var(--text-500); font-size:11px; }.finder-meta { align-items:end; }.finder-empty { padding:14px; text-align:center; }.modal-copy { color:var(--text-600); font-size:12px; margin:0 0 14px; line-height:1.45; } @media(max-width:760px){.finder{min-width:0;width:100%;}.finder-controls{flex-wrap:wrap;}.finder-query{min-width:100%;}.finder-period,.finder-type,.finder-date{flex:1;width:auto;}.finder-results{position:fixed;top:155px;left:14px;right:14px;}}
</style>
