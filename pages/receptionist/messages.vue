<template>
  <div>
    <div class="page-header"><div><h1>Messages</h1><div class="desc">Automated WhatsApp notifications sent to patients — informational only, no clinical data included.</div></div></div>
    <div class="card">
      <div class="card-header"><h3><Icon name="message" :size="15" /> Recent Notifications</h3></div>
      <div class="card-body tight">
        <div v-if="!log.length" style="padding:20px;">
          <EmptyState icon="message" title="No notifications sent yet" description="WhatsApp notifications fire automatically when appointments are booked or rescheduled." />
        </div>
        <div v-for="m in log" :key="m.id" class="list-row">
          <Avatar :name="m.patient_name" :size="32" />
          <div><div class="main-txt">{{ m.patient_name }} <span class="cell-muted" style="font-weight:500;">· {{ triggerLabel(m.trigger_type) }}</span></div><div class="sub-txt">{{ m.body }}</div></div>
          <div class="side">
            <div class="cell-muted" style="margin-bottom:4px; text-align:right;">{{ fmtWhen(m.created_at) }}</div>
            <StatusBadge :status="statusLabel(m.status)" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const supabase = useSupabaseClient()
const log = ref<any[]>([])

await useAsyncData('receptionist-messages', async () => {
  const { data } = await supabase
    .from('messages_log')
    .select('*, patient_names(full_name)')
    .order('created_at', { ascending: false })
    .limit(50)
  log.value = (data || []).map((m: any) => ({ ...m, patient_name: m.patient_names?.full_name || 'Unknown' }))
  return true
})

function triggerLabel(t: string) {
  return t === 'rescheduled' ? 'Appointment Rescheduled' : 'Appointment Confirmation'
}

// messages_log only tracks whether we handed the message to Evolution API —
// WhatsApp delivered/read receipts would need a separate inbound webhook
// from Evolution API, which isn't part of the "exactly two outbound
// triggers" scope in spec §4.3, so this maps to what we can actually know.
function statusLabel(s: string) {
  if (s === 'sent') return 'Completed'
  if (s === 'failed') return 'Urgent'
  return 'Scheduled'
}

function fmtWhen(iso: string) {
  const d = new Date(iso)
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ', ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}
</script>
