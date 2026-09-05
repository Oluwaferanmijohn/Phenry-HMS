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
            <button v-for="r in labResults" :key="r.id" type="button" class="list-row patient-result-row" @click="openResult(r)">
              <div class="icon-wrap" style="background:var(--blue-50); color:var(--blue-600); width:34px;height:34px;border-radius:9px;display:flex;align-items:center;justify-content:center;">
                <Icon name="file" :size="15" />
              </div>
              <div>
                <div class="main-txt">{{ r.lab_templates?.name || (r.external ? 'External Upload' : 'Lab Result') }}</div>
                <div class="sub-txt">{{ fmtDate(r.collected_on) }}{{ r.remarks ? ' · ' + r.remarks : '' }}</div>
              </div>
              <div class="side">
                <span class="result-action"><Icon :name="r.external ? 'download' : 'printer'" :size="14" /> {{ r.external ? 'Open file' : 'View / Print' }}</span>
              </div>
            </button>
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
    <LabResultReportModal v-model="showReport" :result-id="selectedResultId" />
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
const downloadingId = ref<string | null>(null)
const showReport = ref(false)
const selectedResultId = ref('')

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

async function openResult(r: any) {
  if (!r.external_file_url) {
    selectedResultId.value = r.id
    showReport.value = true
    return
  }
  // external_file_url is a storage path (e.g. "PT-001/169..."), not a
  // public URL — the bucket is private, so it has to be exchanged for a
  // short-lived signed URL before it can be opened.
  downloadingId.value = r.id
  const { data, error } = await supabase.storage.from('lab-external-results').createSignedUrl(r.external_file_url, 60)
  downloadingId.value = null
  if (error || !data?.signedUrl) {
    toast("Couldn't open this document — please try again or ask the clinic.")
    return
  }
  window.open(data.signedUrl, '_blank')
}
</script>

<style scoped>
.patient-result-row { width:100%; border:0; background:transparent; text-align:left; font-family:inherit; cursor:pointer; }
.patient-result-row:hover { background:var(--bg); }
.result-action { display:inline-flex; align-items:center; gap:6px; color:var(--blue-600); font-size:11.5px; font-weight:700; white-space:nowrap; }
</style>
