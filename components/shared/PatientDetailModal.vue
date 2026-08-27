<template>
  <Modal :model-value="modelValue" :title="patient?.full_name || ''" wide @update:model-value="$emit('update:modelValue', $event)">
    <template v-if="patient">
      <div class="grid grid-4" style="gap:10px; margin-bottom:14px;">
        <div><div class="muted" style="font-size:10.5px;">ID</div><div style="font-weight:600; font-size:12.5px;">{{ patient.patient_id }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">AGE</div><div style="font-weight:600; font-size:12.5px;">{{ computeAge(patient.dob) }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patient.blood_group || '—' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">STATUS</div><StatusBadge :status="patient.status" /></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;">Contact</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);"><Icon name="phone" :size="11" /> {{ patient.phone || '—' }} &nbsp; <Icon name="mail" :size="11" /> {{ patient.email || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700);">{{ patient.address || '—' }}</p>
      <p style="font-size:12.5px; color:var(--text-700); margin-top:4px;">Emergency: {{ patient.emergency_contact?.name || '—' }} ({{ patient.emergency_contact?.relationship || '—' }}) · {{ patient.emergency_contact?.phone || '—' }}</p>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="clipboard" :size="12" /> Medical History</b>
      <div class="grid grid-3" style="margin-top:8px; gap:10px;">
        <div><div class="muted" style="font-size:10.5px;">ALLERGIES</div><div style="font-weight:600; font-size:12.5px;" :style="{ color: patient.allergies?.length ? 'var(--red-600)' : 'var(--text-900)' }">{{ patient.allergies?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">CHRONIC CONDITIONS</div><div style="font-weight:600; font-size:12.5px;">{{ patient.chronic_conditions?.join(', ') || 'None documented' }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">OBSTETRIC HISTORY</div><div style="font-weight:600; font-size:12.5px;">{{ patient.obstetric_history || '—' }}</div></div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="layers" :size="12" /> Treatment Cycle</b>
      <p style="font-size:12.5px; margin-top:6px; color:var(--text-700);">
        {{ cycle ? `${cycle.type} — ${cycle.stage} (Day ${cycle.cycle_day}) · ${cycle.protocol}` : 'No active treatment cycle.' }}
      </p>
      <p v-if="cycle" class="cell-muted" style="margin-top:4px;"><Icon name="user" :size="11" /> Cycle Manager: {{ cycleManagerName || 'Unassigned' }}</p>
      <div v-if="cycle" style="margin-top:12px;">
        <CycleDayChart :cycle-id="cycle.id" :start-date="cycle.start_date" :can-edit="false" />
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="syringe" :size="12" /> Transfer &amp; Cryopreservation</b>
      <div v-if="embryosTransferredTotal > 0 || cryoStoredCount > 0" class="grid grid-2" style="margin:8px 0; gap:10px;">
        <div><div class="muted" style="font-size:10.5px;">EMBRYOS TRANSFERRED</div><div style="font-weight:700;">{{ embryosTransferredTotal }}</div></div>
        <div><div class="muted" style="font-size:10.5px;">CURRENTLY IN STORAGE</div><div style="font-weight:700;">{{ cryoStoredCount }}</div></div>
      </div>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!transferCryoEvents.length" class="muted" style="font-size:12px;">No transfer or cryo events scheduled.</p>
        <div v-for="e in transferCryoEvents" :key="e.id" class="list-row" style="padding:6px 0;">
          <div><div class="main-txt">{{ e.type }}<span v-if="e.embryos_used != null" class="cell-muted"> — {{ e.embryos_used }} used</span></div><div class="sub-txt">{{ fmtDate(e.scheduled_date) }}{{ e.notes ? ' · ' + e.notes : '' }}</div></div>
          <StatusBadge :status="e.status" />
        </div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="activity" :size="12" /> Surgical Procedures</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!surgeries.length" class="muted" style="font-size:12px;">No procedures scheduled or on record.</p>
        <div v-for="s in surgeries" :key="s.id" class="list-row" style="padding:6px 0;">
          <div><div class="main-txt">{{ s.procedure }}</div><div class="sub-txt">{{ fmtDate(s.date) }}{{ s.time ? ' · ' + s.time : '' }}{{ s.location ? ' · ' + s.location : '' }}</div></div>
          <StatusBadge :status="s.status" />
        </div>
      </div>
      <template v-if="patient.spouse">
        <hr class="hr" />
        <b style="font-size:12.5px;"><Icon name="user" :size="12" /> Spouse / Partner</b>
        <div class="grid grid-3" style="margin-top:8px; gap:10px;">
          <div><div class="muted" style="font-size:10.5px;">NAME</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.name || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">BLOOD GROUP</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.bloodGroup || '—' }}</div></div>
          <div><div class="muted" style="font-size:10.5px;">SFA RESULT</div><div style="font-weight:600; font-size:12.5px;">{{ patient.spouse.sfa || 'Not on file' }}</div></div>
        </div>
      </template>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="message" :size="12" /> Past Consultations</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:8px;">
        <p v-if="!consultations.length" class="muted" style="font-size:12px;">No past consultations on file.</p>
        <div v-for="c in consultations" :key="c.id" class="card-pad" style="border:1px solid var(--border); border-radius:var(--radius-sm);">
          <div class="flex-between"><b style="font-size:12px;">{{ fmtDate(c.date) }} · {{ c.type }}</b><span class="cell-muted">{{ c.provider_name }}</span></div>
          <p style="font-size:12px; color:var(--text-700); margin-top:6px;">{{ c.notes }}</p>
          <p class="cell-muted" style="margin-top:4px;">Dx: {{ c.diagnosis }}</p>
        </div>
      </div>
      <hr class="hr" />
      <b style="font-size:12.5px;"><Icon name="flask" :size="12" /> Past Tests</b>
      <div style="margin-top:8px; display:flex; flex-direction:column; gap:6px;">
        <p v-if="!labResults.length" class="muted" style="font-size:12px;">No lab results on file yet.</p>
        <div v-for="r in labResults" :key="r.id" style="border-bottom:1px solid var(--border);">
          <div class="list-row" style="padding:6px 0; cursor:pointer;" @click="toggleExpanded(r.id)">
            <div><div class="main-txt">{{ r.lab_templates?.name || r.title || 'External Upload' }}</div><div class="sub-txt">{{ fmtDate(r.collected_on) }}</div></div>
            <div class="flex gap-8" style="align-items:center;">
              <Badge v-if="flaggedCount(r) > 0" tone="red">⚠ {{ flaggedCount(r) }} abnormal</Badge>
              <Icon v-if="Array.isArray(r.values) && r.values.length" :name="expanded.has(r.id) ? 'line' : 'plus'" :size="11" />
            </div>
          </div>
          <table v-if="expanded.has(r.id) && Array.isArray(r.values) && r.values.length" class="data-table" style="margin-bottom:8px;">
            <thead><tr><th>Parameter</th><th>Value</th><th>Ref. Range</th></tr></thead>
            <tbody>
              <tr v-for="(v, i) in r.values" :key="i">
                <td class="cell-strong">{{ v.param }}</td>
                <td :style="{ color: v.flag ? 'var(--red-600)' : 'var(--text-900)', fontWeight: v.flag ? 700 : 500 }">{{ v.value }} {{ v.unit }} {{ v.flag ? '⚠' : '' }}</td>
                <td class="cell-muted">{{ v.ref }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else-if="expanded.has(r.id) && r.remarks" class="cell-muted" style="padding:0 0 8px;">{{ r.remarks }}</p>
        </div>
      </div>
    </template>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Close</button>
      <button v-if="caps.allowLabActions" class="btn btn-secondary" @click="$emit('upload-external')"><Icon name="upload" :size="13" /> Upload External Result</button>
      <button v-if="caps.allowConsultation" class="btn btn-primary" @click="$emit('start-consultation')"><Icon name="clipboard" :size="13" /> Start Consultation</button>
      <button v-if="caps.allowVisitDoc" class="btn btn-primary" @click="$emit('go-to-visit')"><Icon name="clipboard" :size="13" /> Go to Visit Documentation</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'
import { resolveCycleManagerNames } from '~/composables/useCycleManagerNames'

const props = defineProps<{
  modelValue: boolean
  patient: any | null
  cycle: any | null
  consultations: any[]
  labResults: any[]
  caps: { allowConsultation?: boolean; allowVisitDoc?: boolean; allowLabActions?: boolean }
}>()
defineEmits<{ 'update:modelValue': [boolean]; 'upload-external': []; 'start-consultation': []; 'go-to-visit': [] }>()

const expanded = ref<Set<string>>(new Set())
function toggleExpanded(id: string) {
  const next = new Set(expanded.value)
  next.has(id) ? next.delete(id) : next.add(id)
  expanded.value = next
}
function flaggedCount(result: any) {
  return Array.isArray(result.values) ? result.values.filter((v: any) => v.flag).length : 0
}

// Resolved here rather than requiring every caller to embed
// cycle_manager:cycle_manager_id(...) on their own `cycle` fetch — some did,
// some didn't, which is exactly the kind of inconsistency that made this
// look "assigned" on one screen and "Unassigned" on another. `cycle` only
// needs the plain cycle_manager_id scalar (part of any `select('*')`).
const supabase = useSupabaseClient()
const cycleManagerName = ref('')
watch(
  () => props.cycle?.cycle_manager_id,
  async (id) => {
    cycleManagerName.value = id ? (await resolveCycleManagerNames(supabase, [id])).get(id) || '' : ''
  },
  { immediate: true }
)

// Surgery and transfer/cryo events are patient-scoped, not cycle-scoped
// (a patient can have surgical history outside any active cycle), so these
// fetch off patient_id directly rather than depending on `cycle` being
// present. Self-contained here for the same reason cycleManagerName is:
// every caller of this modal (5+ pages) would otherwise need its own copy
// of this fetch, and RLS already scopes what each role can actually see —
// a role without access to one of these tables just gets an empty list
// back, no error, so this is safe to always attempt.
const surgeries = ref<any[]>([])
const transferCryoEvents = ref<any[]>([])
const cryoStoredCount = ref(0)
watch(
  () => props.patient?.patient_id,
  async (patientId) => {
    if (!patientId) {
      surgeries.value = []
      transferCryoEvents.value = []
      cryoStoredCount.value = 0
      return
    }
    const [surgeryRes, transferRes, cryoRes] = await Promise.all([
      supabase.from('surgery_schedule').select('*').eq('patient_id', patientId).order('date', { ascending: false }),
      supabase.from('transfer_cryo_schedule').select('*').eq('patient_id', patientId).order('scheduled_date', { ascending: false }),
      supabase.from('cryo_records').select('straws').eq('patient_id', patientId).eq('asset_type', 'Embryo').eq('status', 'Stored'),
    ])
    surgeries.value = surgeryRes.data || []
    transferCryoEvents.value = transferRes.data || []
    cryoStoredCount.value = (cryoRes.data || []).reduce((sum: number, r: any) => sum + (r.straws || 0), 0)
  },
  { immediate: true }
)
const embryosTransferredTotal = computed(() =>
  transferCryoEvents.value.filter((e) => e.status === 'Done' && e.embryos_used != null).reduce((sum, e) => sum + e.embryos_used, 0)
)
</script>
