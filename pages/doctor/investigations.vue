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
    <div v-if="!cycle" class="card card-pad" style="margin-bottom:16px; background:var(--amber-50);">
      <b style="font-size:12.5px; color:var(--amber-600);"><Icon name="clock" :size="12" /> No active treatment cycle</b>
      <p style="font-size:12px; color:var(--text-700); margin-top:4px;">Investigation results and ultrasound scans are logged against an active cycle — start one from Consultation before recording results.</p>
    </div>
    <div class="grid grid-main-side">
      <div class="card">
        <div class="card-header">
          <h3><Icon name="flask" :size="15" /> Female Investigations</h3>
          <div class="flex gap-10">
            <button v-if="cycle" class="btn btn-primary btn-sm" @click="openInvestigation"><Icon name="plus" :size="12" /> Add Result</button>
            <span class="link" @click="showHistory = true">View History</span>
          </div>
        </div>
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
        <div class="card card-pad">
          <div class="flex-between">
            <b style="font-size:13px;"><Icon name="activity" :size="13" /> Latest Follicular Tracking Scan</b>
            <span v-if="cycle" class="link" @click="openUltrasound"><Icon name="plus" :size="12" /> Log Scan</span>
          </div>
          <template v-if="ultrasound">
            <div class="flex-between" style="margin-top:8px;"><span class="cell-muted">Endometrial Thickness</span><b>{{ ultrasound.endometrial }} mm</b></div>
            <hr class="hr" />
            <div style="font-size:11.5px; font-weight:700; color:var(--text-500); margin-bottom:6px;">RIGHT OVARY</div>
            <div class="flex gap-8" style="flex-wrap:wrap;"><span v-for="(v, i) in ultrasound.right_ovary || []" :key="i" class="badge badge-blue">{{ v }}mm</span></div>
            <div style="font-size:11.5px; font-weight:700; color:var(--text-500); margin:10px 0 6px;">LEFT OVARY</div>
            <div class="flex gap-8" style="flex-wrap:wrap;"><span v-for="(v, i) in ultrasound.left_ovary || []" :key="i" class="badge badge-blue">{{ v }}mm</span></div>
            <div class="cell-muted" style="margin-top:8px;">Scanned {{ fmtDate(ultrasound.date) }}</div>
          </template>
          <p v-else class="muted" style="font-size:12px; margin-top:8px;">No follicular tracking scan logged yet.</p>
        </div>
        <div class="card card-pad">
          <b style="font-size:13px;">Clinical Observations</b>
          <p style="font-size:12px; color:var(--text-700); margin-top:8px;">{{ cycle?.physician_notes || 'No observations logged for this patient yet.' }}</p>
        </div>
      </div>
    </div>
    <PatientDetailModal v-model="showHistory" :patient="patient" :cycle="cycle" :consultations="[]" :lab-results="[]" :caps="{}" />

    <Modal v-model="showInvestigation" title="Add Investigation Result">
      <div class="form-row">
        <div class="field">
          <label>Hormone / Parameter</label>
          <input v-model="invDraft.hormone" class="input" list="hormone-suggestions" placeholder="e.g. FSH" />
          <datalist id="hormone-suggestions">
            <option value="FSH" /><option value="LH" /><option value="Estradiol (E2)" /><option value="Progesterone" /><option value="AMH" /><option value="TSH" /><option value="Prolactin" /><option value="Beta hCG (Quantitative)" />
          </datalist>
        </div>
        <div class="field"><label>Date</label><input v-model="invDraft.date" class="input" type="date" /></div>
      </div>
      <div class="form-row">
        <div class="field"><label>Value</label><input v-model="invDraft.value" class="input" type="number" step="any" placeholder="e.g. 6.2" /></div>
        <div class="field"><label>Unit</label><input v-model="invDraft.unit" class="input" placeholder="e.g. mIU/mL" /></div>
      </div>
      <div class="field"><label>Reference Range</label><input v-model="invDraft.ref_range" class="input" placeholder="e.g. 3.5-12.5" /></div>
      <p v-if="invPreviewFlag" class="cell-muted" style="color:var(--red-600); margin-top:4px;"><Icon name="alert" :size="11" /> This value falls outside the reference range and will be flagged abnormal.</p>
      <template #footer>
        <button class="btn btn-secondary" @click="showInvestigation = false">Cancel</button>
        <button class="btn btn-primary" :disabled="!invDraft.hormone || invDraft.value === '' || savingInv" @click="saveInvestigation"><Icon name="check-circle" :size="13" /> Save Result</button>
      </template>
    </Modal>

    <Modal v-model="showUltrasound" title="Log Follicular Tracking Scan">
      <div class="field"><label>Date</label><input v-model="usDraft.date" class="input" type="date" /></div>
      <div class="field"><label>Endometrial Thickness (mm)</label><input v-model="usDraft.endometrial" class="input" type="number" step="any" /></div>
      <div class="form-row">
        <div class="field"><label>Right Ovary Follicles (mm, comma-separated)</label><input v-model="usDraft.rightOvary" class="input" placeholder="e.g. 12, 14, 16" /></div>
        <div class="field"><label>Left Ovary Follicles (mm, comma-separated)</label><input v-model="usDraft.leftOvary" class="input" placeholder="e.g. 11, 13" /></div>
      </div>
      <template #footer>
        <button class="btn btn-secondary" @click="showUltrasound = false">Cancel</button>
        <button class="btn btn-primary" :disabled="savingUs" @click="saveUltrasound"><Icon name="check-circle" :size="13" /> Save Scan</button>
      </template>
    </Modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue'
import { fmtDate, computeAge } from '~/composables/useFormat'
import { computeFlag } from '~/composables/useLabFlag'
import { useSyncQueue } from '~/composables/useSyncQueue'

const supabase = useSupabaseClient()
const { queueOrRun } = useSyncQueue()
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

// ---- Add Investigation Result ----
const showInvestigation = ref(false)
const savingInv = ref(false)
const invDraft = reactive({ hormone: '', value: '' as string | number, unit: '', ref_range: '', date: new Date().toISOString().slice(0, 10) })
const invPreviewFlag = computed(() => computeFlag(invDraft.value, invDraft.ref_range))

function openInvestigation() {
  invDraft.hormone = ''
  invDraft.value = ''
  invDraft.unit = ''
  invDraft.ref_range = ''
  invDraft.date = new Date().toISOString().slice(0, 10)
  showInvestigation.value = true
}

async function saveInvestigation() {
  if (!cycle.value || !invDraft.hormone || invDraft.value === '') return
  savingInv.value = true
  const targetCycleId = cycle.value.id
  const targetPatientName = patient.value.full_name
  const targetHormone = invDraft.hormone
  const targetValue = invDraft.value
  const targetUnit = invDraft.unit
  const targetRefRange = invDraft.ref_range
  const targetDate = invDraft.date
  await queueOrRun(`${targetHormone} result saved for ${targetPatientName}`, async () => {
    const { error } = await supabase.from('cycle_investigations').insert({
      cycle_id: targetCycleId,
      hormone: targetHormone,
      value: Number(targetValue),
      unit: targetUnit,
      ref_range: targetRefRange,
      date: targetDate,
      flag: computeFlag(targetValue, targetRefRange),
    })
    if (error) throw error
    if (cycle.value?.id === targetCycleId) {
      const { data } = await supabase.from('cycle_investigations').select('*').eq('cycle_id', targetCycleId).order('date', { ascending: false })
      investigations.value = data || []
    }
  })
  savingInv.value = false
  showInvestigation.value = false
}

// ---- Log Follicular Tracking Scan ----
const showUltrasound = ref(false)
const savingUs = ref(false)
const usDraft = reactive({ endometrial: '' as string | number, rightOvary: '', leftOvary: '', date: new Date().toISOString().slice(0, 10) })

function openUltrasound() {
  usDraft.endometrial = ultrasound.value?.endometrial ?? ''
  usDraft.rightOvary = ''
  usDraft.leftOvary = ''
  usDraft.date = new Date().toISOString().slice(0, 10)
  showUltrasound.value = true
}

function parseFollicles(input: string): number[] {
  return input
    .split(/[,\s]+/)
    .map((s) => Number(s))
    .filter((n) => !Number.isNaN(n) && input.trim() !== '')
}

async function saveUltrasound() {
  if (!cycle.value) return
  savingUs.value = true
  const targetCycleId = cycle.value.id
  const targetPatientName = patient.value.full_name
  const targetEndometrial = usDraft.endometrial === '' ? null : Number(usDraft.endometrial)
  const targetRightOvary = parseFollicles(usDraft.rightOvary)
  const targetLeftOvary = parseFollicles(usDraft.leftOvary)
  const targetDate = usDraft.date
  await queueOrRun(`Follicular scan logged for ${targetPatientName}`, async () => {
    const { data, error } = await supabase
      .from('cycle_ultrasounds')
      .insert({
        cycle_id: targetCycleId,
        endometrial: targetEndometrial,
        right_ovary: targetRightOvary,
        left_ovary: targetLeftOvary,
        date: targetDate,
      })
      .select()
      .single()
    if (error) throw error
    if (cycle.value?.id === targetCycleId) ultrasound.value = data
  })
  savingUs.value = false
  showUltrasound.value = false
}
</script>
