<template>
  <div>
    <EmptyState
      v-if="!cycle"
      icon="layers"
      title="No active treatment cycle"
      description="Your treatment planner will appear here once a cycle is scheduled by your doctor."
    />
    <template v-else>
      <div class="page-header">
        <div>
          <h1>My Treatment Planner</h1>
          <div class="desc">{{ cycle.protocol }} · {{ cycle.type }}</div>
        </div>
      </div>

      <div class="steps" style="margin-bottom:24px;">
        <template v-for="(s, i) in stages" :key="s">
          <div class="step" :class="{ done: i < stageIdx, current: i === stageIdx }">
            <div class="num"><Icon v-if="i < stageIdx" name="check-circle" :size="13" /><template v-else>{{ i + 1 }}</template></div>
            <div class="step-label">{{ s }}</div>
          </div>
          <div v-if="i < stages.length - 1" class="step-line" :class="{ done: i < stageIdx }" />
        </template>
      </div>

      <div class="grid grid-main-side">
        <div style="display:flex; flex-direction:column; gap:16px;">
          <div class="card card-pad" style="border-color:var(--blue-100); background:var(--blue-50);">
            <div class="flex-between">
              <b style="color:var(--blue-700); font-size:14.5px;"><Icon name="activity" :size="15" /> Current Phase — {{ cycle.stage }}</b>
              <Badge tone="blue">Cycle Day {{ cycle.cycle_day }}</Badge>
            </div>
            <p style="font-size:12.5px; color:var(--text-700); margin-top:8px;">{{ cycle.physician_notes }}</p>
          </div>

          <div class="card">
            <div class="card-header"><h3><Icon name="clipboard" :size="15" /> Daily Treatment Tracker</h3></div>
            <div class="card-body tight">
              <div v-if="!dailyLogs.length" style="padding:20px;">
                <EmptyState icon="clock" title="No entries yet" description="Your care team logs each day's medication and vitals here." />
              </div>
              <div v-for="l in dailyLogs" :key="l.id" class="list-row">
                <div
                  class="icon-wrap"
                  :style="{
                    background: l.medication_administered ? 'var(--green-50)' : 'var(--bg)',
                    color: l.medication_administered ? 'var(--green-600)' : 'var(--text-400)',
                    width: '34px', height: '34px', borderRadius: '9px', display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }"
                >
                  <Icon :name="l.medication_administered ? 'check-circle' : 'clock'" :size="15" />
                </div>
                <div>
                  <div class="main-txt">Day {{ l.day }} — {{ fmtDate(l.date) }}</div>
                  <div class="sub-txt">{{ l.note || 'Awaiting clinic log' }}</div>
                </div>
                <div class="side"><Badge :tone="l.medication_administered ? 'green' : 'amber'">{{ l.medication_administered ? 'Logged' : 'Pending' }}</Badge></div>
              </div>
            </div>
          </div>
        </div>

        <div class="card card-pad">
          <h3 style="font-size:13.5px;">Milestones</h3>
          <div style="display:flex; flex-direction:column; gap:14px; margin-top:14px;">
            <div v-for="(s, i) in stages" :key="s" class="flex gap-10" style="align-items:flex-start;">
              <div
                style="width:22px;height:22px;border-radius:50%;flex-shrink:0;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;"
                :style="{
                  background: i < stageIdx ? 'var(--green-500)' : i === stageIdx ? 'var(--blue-600)' : 'var(--bg)',
                  color: i <= stageIdx ? '#fff' : 'var(--text-400)',
                  border: `1.5px solid ${i <= stageIdx ? 'transparent' : 'var(--border-strong)'}`,
                }"
              >
                {{ i < stageIdx ? '✓' : i + 1 }}
              </div>
              <div>
                <div style="font-size:13px; font-weight:600;" :style="{ color: i <= stageIdx ? 'var(--text-900)' : 'var(--text-400)' }">{{ s }}</div>
                <div style="font-size:11.5px; color:var(--text-500);">{{ i < stageIdx ? 'Completed' : i === stageIdx ? 'In progress' : 'Upcoming' }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const patientId = profile.value!.patient_id!

const stages = ['Baseline', 'Stimulation', 'OPU', 'Transfer']
const cycle = ref<any>(null)
const dailyLogs = ref<any[]>([])

const { data } = await useAsyncData(`patient-treatment-${patientId}`, async () => {
  const { data: c } = await supabase
    .from('cycles')
    .select('*')
    .eq('patient_id', patientId)
    .neq('status', 'Closed')
    .order('start_date', { ascending: false })
    .limit(1)
    .maybeSingle()

  if (!c) return { cycle: null, logs: [] }

  const { data: logs } = await supabase
    .from('cycle_daily_logs')
    .select('*')
    .eq('cycle_id', c.id)
    .order('day', { ascending: true })

  return { cycle: c, logs: logs || [] }
})

if (data.value) {
  cycle.value = data.value.cycle
  dailyLogs.value = data.value.logs
}

const stageIdx = computed(() => (cycle.value ? stages.indexOf(cycle.value.stage) : -1))
</script>
