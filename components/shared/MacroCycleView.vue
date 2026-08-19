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
          <div><div class="main-txt">{{ c.patient_name }}</div><div class="sub-txt">{{ c.assigned_doctor_name }}</div></div>
          <div style="grid-column: 2 / span 4; padding-right:10px;">
            <ProgressBar :pct="stagePct(c.stage)" :tone="c.stage === 'Transfer' ? 'green' : ''" />
          </div>
        </div>
        <div v-if="!active.length" style="padding:20px;"><EmptyState icon="layers" title="No active cycles" description="Start a new cycle to see it tracked here." /></div>
      </div>
    </div>

    <StartCycleModal v-model="showStart" :role="role" @started="load" />
    <CycleDetailModal v-model="showDetail" :cycle-id="detailCycleId" :patient-name="detailPatientName" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const props = defineProps<{ role: string; allowCreate?: boolean }>()

const supabase = useSupabaseClient()
const STAGES = ['Baseline', 'Stimulation', 'OPU', 'Transfer']

const active = ref<any[]>([])
const showStart = ref(false)
const showDetail = ref(false)
const detailCycleId = ref('')
const detailPatientName = ref('')

async function load() {
  const { data } = await supabase
    .from('cycles')
    .select('*, patient_names(full_name), bio_details:patient_id(assigned_doctor_id, profiles:assigned_doctor_id(full_name))')
    .in('status', ['Active', 'Pending Start'])
  active.value = (data || []).map((c: any) => ({
    ...c,
    patient_name: c.patient_names?.full_name || 'Unknown',
    assigned_doctor_name: c.bio_details?.profiles?.full_name || 'Unassigned',
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
