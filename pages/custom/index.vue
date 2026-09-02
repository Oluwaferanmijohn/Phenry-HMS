<template>
  <div>
    <div class="page-header">
      <div><h1>{{ roleLabel }} Workspace</h1><div class="desc">Only resources and rows granted by your Admin Manager are shown.</div></div>
    </div>

    <div v-if="!visiblePermissions.length" class="card card-pad">
      <EmptyState icon="shield" title="No data access granted" description="Your account is active, but this custom role has no view permissions yet. Contact your Admin Manager." />
    </div>

    <template v-else>
      <div class="grid grid-3" style="margin-bottom:18px;">
        <button v-for="permission in visiblePermissions" :key="permission.resource" class="card card-pad clickable" style="text-align:left;" @click="activeResource = permission.resource">
          <div class="flex-between"><b>{{ resourceMeta[permission.resource]?.label || permission.resource }}</b><Badge tone="blue">{{ summaries[permission.resource]?.count ?? '—' }}</Badge></div>
          <div class="cell-muted" style="margin-top:7px;">Scope: {{ scopeLabel(permission.scope) }}</div>
          <div class="flex gap-8" style="margin-top:10px;">
            <Badge v-if="permission.can_create" tone="green">Create allowed</Badge>
            <Badge v-if="permission.can_edit" tone="amber">Edit allowed</Badge>
          </div>
        </button>
      </div>

      <div v-if="activePermission" class="card">
        <div class="card-header">
          <h3><Icon name="shield" :size="15" /> {{ resourceMeta[activeResource]?.label }}</h3>
          <Badge tone="blue">{{ scopeLabel(activePermission.scope) }}</Badge>
        </div>
        <div v-if="activePermission.scope === 'aggregate'" class="card-pad">
          <div style="font-size:30px;font-weight:800;">{{ summaries[activeResource]?.count ?? 0 }}</div>
          <div class="cell-muted">Aggregate records. Patient-level rows are intentionally hidden.</div>
        </div>
        <div v-else-if="summaries[activeResource]?.error" class="card-pad">
          <p style="color:var(--red-600);">{{ summaries[activeResource]?.error }}</p>
        </div>
        <template v-else>
          <table class="data-table">
            <thead><tr><th v-for="column in resourceMeta[activeResource]?.columns || []" :key="column">{{ columnLabel(column) }}</th></tr></thead>
            <tbody>
              <tr v-for="(row, index) in summaries[activeResource]?.rows || []" :key="row.id || row.patient_id || index">
                <td v-for="column in resourceMeta[activeResource]?.columns || []" :key="column">{{ displayValue(row[column]) }}</td>
              </tr>
            </tbody>
          </table>
          <div v-if="!summaries[activeResource]?.rows?.length" style="padding:18px;"><EmptyState icon="file" title="No accessible records" description="There are no records in your granted scope." /></div>
          <p v-if="activePermission.can_create || activePermission.can_edit" class="hint" style="padding:12px 18px;">
            Write permission is enforced by the database. Patient-safe editing remains in the clinic's purpose-built workflows; this generic workspace intentionally does not expose raw record editing.
          </p>
        </template>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useProfile } from '~/composables/useAuth'

const resourceMeta: Record<string, { label: string; columns: string[] }> = {
  patient_names: { label: 'Patient Identity', columns: ['patient_id', 'full_name'] },
  bio_details: { label: 'Patient Details', columns: ['patient_id', 'status', 'registered_on'] },
  cycles: { label: 'Treatment Cycles', columns: ['patient_id', 'type', 'stage', 'status', 'start_date'] },
  consultations: { label: 'Consultations', columns: ['patient_id', 'date', 'type', 'diagnosis'] },
  appointments: { label: 'Appointments', columns: ['patient_id', 'date', 'time', 'type', 'status'] },
  payment_plans: { label: 'Payment Plans', columns: ['patient_id', 'package', 'total_cost'] },
  payment_milestones: { label: 'Payment Milestones', columns: ['label', 'amount', 'status', 'due_context'] },
  prescriptions: { label: 'Prescriptions', columns: ['patient_id', 'medication', 'sig', 'status', 'date'] },
  lab_results: { label: 'Lab Results', columns: ['patient_id', 'collected_on', 'remarks', 'external'] },
  clinic_settings: { label: 'Clinic Settings', columns: ['clinic_name', 'company_phone', 'company_address'] },
}

const supabase = useSupabaseClient()
const profile = useProfile()
const permissions = ref<any[]>([])
const roleLabel = ref('Custom Role')
const activeResource = ref('')
const summaries = ref<Record<string, { count: number; rows: any[]; error?: string }>>({})
const visiblePermissions = computed(() => permissions.value.filter((permission) => permission.can_view && resourceMeta[permission.resource]))
const activePermission = computed(() => visiblePermissions.value.find((permission) => permission.resource === activeResource.value))

await useAsyncData(`custom-workspace-${profile.value?.custom_role_key}`, async () => {
  const roleKey = profile.value!.custom_role_key!
  const [roleResult, permissionResult] = await Promise.all([
    supabase.from('custom_roles').select('label').eq('role_key', roleKey).single(),
    supabase.from('role_permissions').select('*').eq('role_key', roleKey).order('resource'),
  ])
  if (permissionResult.error) throw permissionResult.error
  roleLabel.value = roleResult.data?.label || roleKey
  permissions.value = permissionResult.data || []
  activeResource.value = visiblePermissions.value[0]?.resource || ''

  await Promise.all(visiblePermissions.value.map(async (permission) => {
    if (permission.scope === 'aggregate') {
      const { data, error } = await supabase.rpc('custom_resource_aggregate_count', { p_resource: permission.resource })
      summaries.value[permission.resource] = { count: Number(data || 0), rows: [], error: error?.message }
      return
    }
    const meta = resourceMeta[permission.resource]
    if (!meta) return
    const columns = meta.columns.join(',')
    const { data, count, error } = await supabase.from(permission.resource).select(columns, { count: 'exact' }).limit(25)
    summaries.value[permission.resource] = { count: count || 0, rows: data || [], error: error?.message }
  }))
  return true
})

function scopeLabel(scope: string) {
  return ({ own: 'Own records', assigned: 'Assigned patients', all: 'All records', aggregate: 'Aggregate only' } as Record<string, string>)[scope] || scope
}

function columnLabel(column: string) {
  return column.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function displayValue(value: unknown) {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  if (typeof value === 'object') return JSON.stringify(value).slice(0, 100)
  return String(value)
}
</script>
