<template>
  <div>
    <div class="page-header">
      <div>
        <h1>Medication Tracker</h1>
        <div class="desc">Your current protocol for {{ cycleProtocol || 'this cycle' }}.</div>
      </div>
    </div>

    <div class="card">
      <div class="card-header"><h3><Icon name="pill" :size="15" /> Active Prescriptions</h3></div>
      <div class="card-body tight">
        <div v-if="!prescriptions.length" style="padding:20px;">
          <EmptyState icon="pill" title="No active prescriptions" description="Medications your care team prescribes will appear here." />
        </div>
        <div v-for="rx in prescriptions" :key="rx.id" class="list-row" style="align-items:flex-start;">
          <div class="icon-wrap" style="background:var(--blue-50); color:var(--blue-600); width:36px;height:36px;border-radius:10px;display:flex;align-items:center;justify-content:center;flex-shrink:0;">
            <Icon :name="rx.medication.toLowerCase().includes('tablet') || rx.medication.toLowerCase().includes('vitamin') ? 'pill' : 'syringe'" :size="16" />
          </div>
          <div>
            <div class="main-txt">{{ rx.medication }}</div>
            <div class="sub-txt">{{ rx.sig }}</div>
          </div>
        </div>
      </div>
    </div>

    <div class="card card-pad" style="margin-top:18px; background:var(--blue-50); border-color:var(--blue-100);">
      <div class="flex gap-8"><span style="color:var(--blue-600);"><Icon name="message" :size="16" /></span><b style="font-size:13px;">Understanding your medications</b></div>
      <p style="font-size:12.5px; color:var(--text-700); margin-top:8px;">If you experience side effects or missed a dose, message the clinic or raise it at your next scheduled visit — do not adjust dosages on your own.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useProfile } from '~/composables/useAuth'

const supabase = useSupabaseClient()
const profile = useProfile()
const patientId = profile.value!.patient_id!

const prescriptions = ref<any[]>([])
const cycleProtocol = ref('')

const { data } = await useAsyncData(`patient-medications-${patientId}`, async () => {
  const [rxRes, cycleRes] = await Promise.all([
    supabase.from('prescriptions').select('*').eq('patient_id', patientId).neq('status', 'Cancelled').order('date', { ascending: false }),
    supabase.from('cycles').select('protocol').eq('patient_id', patientId).neq('status', 'Closed').order('start_date', { ascending: false }).limit(1).maybeSingle(),
  ])
  return { prescriptions: rxRes.data || [], protocol: cycleRes.data?.protocol || '' }
})

if (data.value) {
  prescriptions.value = data.value.prescriptions
  cycleProtocol.value = data.value.protocol
}
</script>
