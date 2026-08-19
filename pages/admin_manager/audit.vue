<template>
  <div>
    <div class="page-header"><div><h1>Security &amp; Audit Log</h1><div class="desc">Comprehensive, immutable record of all sensitive actions taken within the system.</div></div></div>
    <div class="card">
      <div class="card-header"><h3><Icon name="shield" :size="15" /> Recent Activity</h3></div>
      <table class="data-table">
        <thead><tr><th>Timestamp</th><th>Staff Member</th><th>Role</th><th>Action</th><th>Target Record</th></tr></thead>
        <tbody>
          <tr v-for="a in log" :key="a.id">
            <td class="cell-muted mono">{{ fmtWhen(a.created_at) }}</td>
            <td class="cell-strong">{{ a.staff_name }}</td>
            <td class="cell-muted">{{ a.role }}</td>
            <td>{{ a.action_type }}</td>
            <td class="cell-muted mono">{{ a.target || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div v-if="!log.length" style="padding:20px;"><EmptyState icon="shield" title="No activity yet" description="Sensitive actions across the system will appear here as they happen." /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'

const supabase = useSupabaseClient()
const log = ref<any[]>([])

await useAsyncData('admin-audit', async () => {
  const { data } = await supabase.from('audit_log').select('*').order('created_at', { ascending: false }).limit(100)
  log.value = data || []
  return true
})

function fmtWhen(iso: string) {
  const d = new Date(iso)
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
}
</script>
