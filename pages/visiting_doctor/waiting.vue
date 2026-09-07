<template>
  <div><div class="page-header"><div><h1>My Assigned Queue</h1><div class="desc">Only appointments explicitly assigned to you.</div></div></div>
    <div class="card"><div class="card-header"><h3><Icon name="users" :size="15" /> Today</h3><Badge tone="amber">{{ appointments.length }} assigned</Badge></div><div class="card-body tight">
      <div v-if="!appointments.length" style="padding:20px;"><EmptyState icon="users" title="No assigned patients today" description="The clinic administrator or reception team can assign an appointment to your account." /></div>
      <div v-for="item in appointments" :key="item.id" class="list-row"><div style="width:56px;font-size:12px;font-weight:700;">{{ item.time }}</div><Avatar :name="item.patient_name" :size="30" /><div><div class="main-txt">{{ item.patient_name }}</div><div class="sub-txt">{{ item.type }}</div></div><div class="side"><button class="btn btn-primary btn-sm" @click="$router.push(`/visiting_doctor/consultation?patient=${item.patient_id}`)">Start consult</button></div></div>
    </div></div>
  </div>
</template>
<script setup lang="ts">
import { ref } from 'vue'
import { useProfile } from '~/composables/useAuth'
const supabase = useSupabaseClient(); const profile = useProfile(); const appointments = ref<any[]>([])
await useAsyncData(`visiting-doctor-queue-${profile.value?.id || ''}`, async () => { const { data } = await supabase.from('appointments').select('id,patient_id,type,time,status,patient_names(full_name)').eq('provider_profile_id', profile.value?.id || '').eq('date', new Date().toISOString().slice(0,10)).order('time'); appointments.value=(data||[]).map((row:any)=>({...row,patient_name:row.patient_names?.full_name||'Patient'})); return true })
</script>
