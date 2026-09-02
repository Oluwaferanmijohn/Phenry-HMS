<template>
  <div>
    <div class="page-header">
      <div><h1>Staff Management</h1><div class="desc">{{ staff.length }} team members</div></div>
      <div class="page-actions"><button class="btn btn-primary" @click="openAdd"><Icon name="plus" :size="14" /> Add Staff</button></div>
    </div>

    <div class="card">
      <table class="data-table">
        <thead><tr><th>Name</th><th>Role</th><th>Joined</th><th>Status</th><th></th></tr></thead>
        <tbody>
          <tr v-for="s in staff" :key="s.id">
            <td class="flex gap-8"><Avatar :name="s.full_name" :size="28" /><span class="cell-strong">{{ s.full_name }}</span></td>
            <td class="cell-muted">{{ roleLabelOf(s) }}</td>
            <td class="cell-muted">{{ fmtDate(s.created_at) }}</td>
            <td><Badge :tone="s.active ? 'green' : 'gray'">{{ s.active ? 'Active' : 'Revoked' }}</Badge></td>
            <td style="text-align:right;" class="flex gap-8">
              <button class="btn btn-secondary btn-sm" @click="openEdit(s)"><Icon name="edit" :size="12" /> Edit Role</button>
              <button class="btn btn-secondary btn-sm" @click="toggleActive(s)">{{ s.active ? 'Revoke Access' : 'Reinstate' }}</button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card" style="margin-top:18px;" v-if="customRoles.length">
      <div class="card-header"><h3><Icon name="settings" :size="15" /> Custom Roles</h3></div>
      <div class="card-body tight">
        <div v-for="r in customRoles" :key="r.role_key" class="list-row">
          <div class="main-txt">{{ r.label }}</div>
          <div class="side"><button class="btn btn-secondary btn-sm" @click="editPermissions(r)"><Icon name="settings" :size="12" /> Edit Permissions</button></div>
        </div>
      </div>
    </div>

    <StaffModal v-model="showStaffModal" :editing-staff="editingStaff" @saved="load" />
    <PermissionsBuilder v-model="showPermEdit" :role-key="permEditRole?.role_key || ''" :role-label="permEditRole?.label || ''" />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { fmtDate } from '~/composables/useFormat'
import { ROLE_META } from '~/composables/useRoleMeta'
import { useToast } from '~/composables/useToast'

const supabase = useSupabaseClient()
const { toast } = useToast()

const staff = ref<any[]>([])
const customRoles = ref<any[]>([])
const showStaffModal = ref(false)
const editingStaff = ref<any>(null)
const showPermEdit = ref(false)
const permEditRole = ref<any>(null)

async function load() {
  const [staffRes, rolesRes] = await Promise.all([
    supabase.from('profiles').select('*, staff_contacts(email, phone)').not('role', 'is', null).neq('role', 'patient').order('created_at', { ascending: false }),
    supabase.from('custom_roles').select('*').order('label', { ascending: true }),
  ])
  // profiles with a custom_role_key (role is null) also need to show — the
  // first query's `role is not null` filter excludes them, so fetch those too.
  const { data: customStaff } = await supabase.from('profiles').select('*, staff_contacts(email, phone)').not('custom_role_key', 'is', null)
  staff.value = [...(staffRes.data || []), ...(customStaff || [])].map((row: any) => {
    const contact = Array.isArray(row.staff_contacts) ? row.staff_contacts[0] : row.staff_contacts
    return { ...row, email: contact?.email || '', phone: contact?.phone || '' }
  })
  customRoles.value = rolesRes.data || []
}
await useAsyncData('admin-staff', load)

function roleLabelOf(s: any) {
  if (s.role) return ROLE_META[s.role]?.label || s.role
  return customRoles.value.find((r) => r.role_key === s.custom_role_key)?.label || s.custom_role_key
}

function openAdd() {
  editingStaff.value = null
  showStaffModal.value = true
}
function openEdit(s: any) {
  editingStaff.value = s
  showStaffModal.value = true
}
function editPermissions(r: any) {
  permEditRole.value = r
  showPermEdit.value = true
}

async function toggleActive(s: any) {
  try {
    await $fetch('/api/admin/update-staff', {
      method: 'POST',
      body: {
        profileId: s.id,
        fullName: s.full_name,
        phone: s.phone,
        role: s.role,
        customRoleKey: s.custom_role_key,
        active: !s.active,
      },
    })
    s.active = !s.active
    toast(`${s.full_name}'s access ${s.active ? 'reinstated' : 'revoked'}`, s.active ? 'success' : 'warn')
  } catch (e: any) {
    toast(e?.data?.statusMessage || e?.statusMessage || 'Could not update access', 'warn')
  }
}
</script>
