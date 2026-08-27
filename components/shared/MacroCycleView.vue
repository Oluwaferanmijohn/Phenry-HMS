<template>
  <div>
    <div class="page-header">
      <div><h1>Active Clinic Cycles (Macro View)</h1><div class="desc">Every active treatment cycle across the clinic, at a glance.</div></div>
      <div v-if="allowCreate" class="page-actions"><button class="btn btn-primary" @click="showStart = true"><Icon name="plus" :size="14" /> Start New Cycle</button></div>
    </div>
    <div class="card">
      <div class="card-body tight">
        <div style="display:grid; grid-template-columns: 1.4fr repeat(4, 1fr); padding:10px 20px; font-size:10.5px; font-weight:700; color:var(--text-400); text-transform:uppercase; border-bottom:1px solid var(--border);">
          <div>Patient Details</div><div>Baseline</div><div>Stimulation</div><div>OPU</div><div>Transfer</div>
        </div>
        <div
          v-for="c in active"
          :key="c.id"
          class="list-row"
          style="display:grid; grid-template-columns: 1.4fr repeat(4, 1fr); align-items:center; padding:14px 20px; cursor:pointer;"
          @click="openDetail(c)"
        >
          <div><div class="main-txt">{{ c.patient_name }}</div><div class="sub-txt">{{ c.assigned_doctor_name }} · Cycle Mgr: {{ c.cycle_manager_name || 'Unassigned' }}</div></div>
          <div style="grid-column: 2 / span 4; padding-right:10px;">
            <ProgressBar :pct="stagePct(c.stage)" :tone="c.stage === 'Transfer' ? 'green' : ''" />
          </div>
        </div>
        <div v-if="!active.length" style="padding:20px;"><EmptyState icon="layers" title="No active cycles" description="Start a new cycle to see it tracked here." /></div>
      </div>
    </div>

    <StartCycleModal v-model="showStart" :role="role" @started="load" />
    <CycleDetailModal v-model="showDetail" :cycle-id="detailCycleId" :patient-name="detailPatientName" :role="role" :can-manage="role === 'matron'" @updated="load" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { resolveCycleManagerNames } from '~/composables/useCycleManagerNames'

const props = defineProps<{ role: string; allowCreate?: boolean }>()

const supabase = useSupabaseClient()
const STAGES = ['Baseline', 'Stimulation', 'OPU', 'Transfer']

const active = ref<any[]>([])
const showStart = ref(false)
const showDetail = ref(false)
const detailCycleId = ref('')
const detailPatientName = ref('')

async function load() {
  // FIX: `bio_details:patient_id(...)` was trying to embed bio_details
  // directly off a cycles query — there is no foreign key between cycles
  // and bio_details (both independently reference patient_names), so
  // PostgREST rejected this on every load with a "no relationship found"
  // error, silently returning empty (data: null on error). That's the
  // actual cause of "cycle created but nothing shows on the cycle page" —
  // it wasn't specific to new cycles, no cycle was ever going to show here.
  // Fetching bio_details/profiles as a separate query and joining
  // client-side, the same pattern used elsewhere in the app (e.g.
  // pages/patient/home.vue), works because that IS a real FK relationship.
  const { data: cyclesData } = await supabase
    .from('cycles')
    .select('*, patient_names(full_name)')
    .in('status', ['Active', 'Pending Start'])

  const patientIds = [...new Set((cyclesData || []).map((c: any) => c.patient_id))]
  const [bioRes, managerNames] = await Promise.all([
    patientIds.length
      ? supabase.from('bio_details').select('patient_id, assigned_doctor_id, profiles:assigned_doctor_id(full_name)').in('patient_id', patientIds)
      : Promise.resolve({ data: [] as any[] }),
    resolveCycleManagerNames(supabase, (cyclesData || []).map((c: any) => c.cycle_manager_id)),
  ])
  const doctorByPatient = new Map((bioRes.data || []).map((b: any) => [b.patient_id, b.profiles?.full_name || null]))

  active.value = (cyclesData || []).map((c: any) => ({
    ...c,
    patient_name: c.patient_names?.full_name || 'Unknown',
    assigned_doctor_name: doctorByPatient.get(c.patient_id) || 'Unassigned',
    cycle_manager_name: c.cycle_manager_id ? managerNames.get(c.cycle_manager_id) || null : null,
  }))
}
await useAsyncData(`macro-cycle-view-${props.role}`, load)

function stagePct(stage: string) {
  const idx = STAGES.indexOf(stage)
  return idx >= 0 ? ((idx + 1) / 4) * 100 : 5
}

function openDetail(c: any) {
  detailCycleId.value = c.id
  detailPatientName.value = c.patient_name
  showDetail.value = true
}
</script>
