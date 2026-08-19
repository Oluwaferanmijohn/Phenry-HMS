<template>
  <div>
    <div class="page-header"><div><h1>Lab Staffing</h1><div class="desc">Embryology lab team.</div></div></div>
    <div class="card">
      <table class="data-table">
        <thead><tr><th>Name</th><th>Role</th><th>Joined</th></tr></thead>
        <tbody>
          <tr v-for="s in staff" :key="s.id">
            <td class="flex gap-8"><Avatar :name="s.full_name" :size="28" /><span class="cell-strong">{{ s.full_name }}</span></td>
            <td class="cell-muted">{{ ROLE_META[s.role]?.label || s.role }}</td>
            <td class="cell-muted">{{ fmtDate(s.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <div v-if="!staff.length" style="padding:20px;"><EmptyState icon="users" title="No lab staff yet" description="Staff added by your Admin Manager will appear here." /></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { ROLE_META } from '~/composables/useRoleMeta'

const supabase = useSupabaseClient()
const staff = ref<any[]>([])

await useAsyncData('chief-staffing', async () => {
  const { data } = await supabase.from('profiles').select('*').in('role', ['chief_embryologist', 'lab_tech']).order('created_at', { ascending: true })
  staff.value = data || []
  return true
})
</script>
