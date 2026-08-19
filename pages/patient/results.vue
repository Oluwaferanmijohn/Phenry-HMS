<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Results &amp; Invoices</h1>
        <div class="desc">Review and download your recent health documents.</div>
      </div>
    </div>

    <div class="tabs">
      <div class="tab" :class="{ active: activeTab === 'lab' }" @click="activeTab = 'lab'">Lab Results</div>
      <div class="tab" :class="{ active: activeTab === 'inv' }" @click="activeTab = 'inv'">Invoices &amp; Receipts</div>
    </div>

    <div style="margin-top:16px;">
      <template v-if="activeTab === 'lab'">
        <div class="card">
          <div class="card-body tight">
            <div v-if="!labResults.length" style="padding:20px;">
              <EmptyState icon="file" title="No results yet" description="Lab results will appear here once your samples are processed." />
            </div>
            <div v-for="r in labResults" :key="r.id" class="list-row">
              <div class="icon-wrap" style="background:var(--blue-50); color:var(--blue-600); width:34px;height:34px;border-radius:9px;display:flex;align-items:center;justify-content:center;">
                <Icon name="file" :size="15" />
              </div>
              <div>
                <div class="main-txt">{{ r.lab_templates?.name || (r.external ? 'External Upload' : 'Lab Result') }}</div>
                <div class="sub-txt">{{ fmtDate(r.collected_on) }}{{ r.remarks ? ' · ' + r.remarks : '' }}</div>
              </div>
              <div class="side">
                <button class="icon-btn" @click="downloadResult(r)"><Icon name="download" :size="14" /></button>
              </div>
            </div>
          </div>
        </div>
        <div class="card card-pad" style="margin-top:16px; background:var(--blue-50); border-color:var(--blue-100);">
          <b style="font-size:13px; color:var(--blue-700);"><Icon name="message" :size="14" /> Understanding your results</b>
          <p style="font-size:12.5px; color:var(--text-700); margin-top:8px;">If you have any questions about these documents, you can discuss them during your next scheduled consultation.</p>
        </div>
      </template>

      <template v-else>
        <div class="card">
          <div class="card-body tight">
            <div v-if="!milestones.length" style="padding:20px;">
              <EmptyState icon="cash" title="No invoices yet" description="Invoices and receipts will appear here once a payment plan is created." />
            </div>
            <div v-for="m in milestones" :key="m.id" class="list-row">
              <div class="icon-wrap" style="background:var(--blue-50); color:var(--blue-600); width:34px;height:34px;border-radius:9px;display:flex;align-items:center;justify-content:center;">
                <Icon name="file" :size="15" />
              </div>
              <div>
                <div class="main-txt">{{ m.label }} — {{ m.status === 'Paid' ? 'Receipt' : 'Invoice' }}</div>
                <div class="sub-txt">
                  {{ m.status === 'Paid' ? `Paid ${fmtDate(m.approved_on)}` : `Due: ${m.due_context}` }} · {{ fmtNaira(m.amount) }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate, fmtNaira } from '~/composables/useFormat'
import { useToast } from '~/composables/useToast'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const { toast } = useToast()
const patientId = profile.value!.patient_id!

const activeTab = ref<'lab' | 'inv'>('lab')
const labResults = ref<any[]>([])
const milestones = ref<any[]>([])

const { data } = await useAsyncData(`patient-results-${patientId}`, async () => {
  const [labRes, planRes] = await Promise.all([
    supabase.from('lab_results').select('*, lab_templates(name)').eq('patient_id', patientId).order('collected_on', { ascending: false }),
    supabase.from('payment_plans').select('payment_milestones(*)').eq('patient_id', patientId),
  ])
  const allMilestones = (planRes.data || []).flatMap((p: any) => p.payment_milestones || [])
  return { labResults: labRes.data || [], milestones: allMilestones }
})

if (data.value) {
  labResults.value = data.value.labResults
  milestones.value = data.value.milestones
}

function downloadResult(r: any) {
  if (r.external_file_url) {
    window.open(r.external_file_url, '_blank')
  } else {
    toast(`Downloading ${r.lab_templates?.name || 'result'}…`)
  }
}
</script>
