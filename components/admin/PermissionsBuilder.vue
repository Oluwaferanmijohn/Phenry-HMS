<template>
  <Modal :model-value="modelValue" :title="`Permissions — ${roleLabel}`" wide @update:model-value="$emit('update:modelValue', $event)">
    <p class="muted" style="font-size:12.5px; margin-bottom:14px;">
      This role starts with <b>zero access</b>. Nothing is visible or editable for it until you grant permissions below and save.
    </p>
    <table class="data-table">
      <thead><tr><th>Table</th><th>View</th><th>Create</th><th>Edit</th><th>Scope</th></tr></thead>
      <tbody>
        <tr v-for="r in RESOURCES" :key="r.key">
          <td class="cell-strong">{{ r.label }}</td>
          <td><input v-model="getRow(r.key).can_view" type="checkbox" /></td>
          <td><input v-model="getRow(r.key).can_create" type="checkbox" /></td>
          <td><input v-model="getRow(r.key).can_edit" type="checkbox" /></td>
          <td>
            <select v-model="getRow(r.key).scope" class="input" style="font-size:11.5px; padding:4px 8px;">
              <option value="own">Own records only</option>
              <option value="assigned">Assigned patients only</option>
              <option value="all">All records</option>
              <option value="aggregate">Aggregate only (no patient data)</option>
            </select>
          </td>
        </tr>
      </tbody>
    </table>
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('update:modelValue', false)">Cancel</button>
      <button class="btn btn-primary" :disabled="saving" @click="save"><Icon name="check-circle" :size="13" /> Save Permissions</button>
    </template>
  </Modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue'
import { useToast } from '~/composables/useToast'

// Every table that currently exists and could plausibly be scoped to a
// custom role. Extend this list as later roles' migrations add tables
// (embryo_batches, requisitions, inventory, etc.) — it isn't exhaustive of
// the whole system, only of what's been built so far.
const RESOURCES = [
  { key: 'patient_names', label: 'Patient Identity' },
  { key: 'bio_details', label: 'Patient Clinical/Demographic Details' },
  { key: 'cycles', label: 'Treatment Cycles' },
  { key: 'consultations', label: 'Consultations' },
  { key: 'appointments', label: 'Appointments' },
  { key: 'payment_plans', label: 'Payment Plans' },
  { key: 'payment_milestones', label: 'Payment Milestones' },
  { key: 'prescriptions', label: 'Prescriptions' },
  { key: 'lab_results', label: 'Lab Results' },
  { key: 'clinic_settings', label: 'Clinic Settings' },
]

const props = defineProps<{ modelValue: boolean; roleKey: string; roleLabel: string }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: [] }>()

const supabase = useSupabaseClient()
const { toast } = useToast()
const saving = ref(false)

function emptyRows() {
  const obj: Record<string, { can_view: boolean; can_create: boolean; can_edit: boolean; scope: string }> = {}
  for (const r of RESOURCES) obj[r.key] = { can_view: false, can_create: false, can_edit: false, scope: 'own' }
  return obj
}
const rows = reactive(emptyRows())
function getRow(key: string) {
  return rows[key]!
}

watch(
  () => [props.modelValue, props.roleKey],
  async ([open]) => {
    if (!open || !props.roleKey) return
    Object.assign(rows, emptyRows())
    const { data } = await supabase.from('role_permissions').select('*').eq('role_key', props.roleKey)
    for (const row of data || []) {
      if (rows[row.resource]) rows[row.resource] = { can_view: row.can_view, can_create: row.can_create, can_edit: row.can_edit, scope: row.scope }
    }
  },
  { immediate: true }
)

async function save() {
  saving.value = true
  const upserts = RESOURCES.map((r) => ({ role_key: props.roleKey, resource: r.key, ...getRow(r.key) }))
  const { error } = await supabase.from('role_permissions').upsert(upserts, { onConflict: 'role_key,resource' })
  saving.value = false
  if (error) {
    toast('Could not save permissions — please try again', 'warn')
    return
  }
  toast(`Permissions saved for ${props.roleLabel}`, 'success')
  emit('saved')
  emit('update:modelValue', false)
}
</script>
