<template>
  <Modal :model-value="modelValue" :title="mode === 'edit' ? 'Edit Staff Role' : 'Add New Staff Member'" @update:model-value="close">
    <template v-if="createdPassword">
      <div class="empty-state" style="padding:10px 0;">
        <div class="icon-wrap"><Icon name="check-circle" :size="22" /></div>
        <h4>{{ form.fullName }}'s account is ready</h4>
        <p>Share this temporary password with them securely — they'll be required to change it on first login.</p>
      </div>
      <div class="flex-between" style="background:var(--bg); border:1px solid var(--border); border-radius:var(--radius-sm); padding:12px 14px; margin-top:10px;">
        <span class="mono" style="font-size:15px; font-weight:700;">{{ createdPassword }}</span>
        <button class="btn btn-secondary btn-sm" @click="copyPassword"><Icon name="file" :size="12" /> Copy</button>
      </div>
    </template>
    <template v-else>
      <div class="field"><label>Full Name</label><input v-model="form.fullName" class="input" placeholder="e.g. Amaka Obi" /></div>
      <div class="field"><label>Email</label><input v-model="form.email" class="input" type="email" :disabled="mode === 'edit'" placeholder="amaka.obi@example.com" /></div>
      <div class="field">
        <label>Role</label>
        <select v-model="selectedRole" class="input">
          <optgroup label="Standard Roles">
            <option v-for="r in FIXED_STAFF_ROLES" :key="r" :value="r">{{ ROLE_META[r]?.label || r }}</option>
          </optgroup>
          <optgroup v-if="customRoles.length" label="Custom Roles">
            <option v-for="r in customRoles" :key="r.role_key" :value="r.role_key">{{ r.label }}</option>
          </optgroup>
          <option value="__new__">+ Add New Role…</option>
        </select>
      </div>

      <div v-if="selectedRole === '__new__'" class="card-pad" style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); margin-top:6px;">
        <div class="field"><label>New Role Name</label><input v-model="newRoleLabel" class="input" placeholder="e.g. Physiotherapist" /></div>
        <button class="btn btn-primary btn-sm" :disabled="!newRoleLabel" @click="createRoleAndConfigure">
          <Icon name="settings" :size="12" /> Create Role &amp; Set Permissions
        </button>
      </div>
    </template>

    <template #footer>
      <template v-if="createdPassword">
        <button class="btn btn-primary" @click="finishAfterCreate">Done</button>
      </template>
      <template v-else>
        <button class="btn btn-secondary" @click="close">Cancel</button>
        <button class="btn btn-primary" :disabled="submitting || !canSubmit" @click="submit">
          <Icon name="check-circle" :size="13" /> {{ mode === 'edit' ? 'Save Role' : 'Create Account' }}
        </button>
      </template>
    </template>
  </Modal>

  <PermissionsBuilder v-model="showPermBuilder" :role-key="pendingRoleKey" :role-label="newRoleLabel" @saved="onRoleConfigured" />
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue'
import { ROLE_META } from '~/composables/useRoleMeta'
import { useToast } from '~/composables/useToast'

const FIXED_STAFF_ROLES = ['receptionist', 'admin_manager', 'doctor', 'matron', 'nurse', 'chief_embryologist', 'lab_tech', 'pharmacy', 'stakeholder']

const props = defineProps<{ modelValue: boolean; editingStaff?: any | null }>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; saved: [] }>()

const supabase = useSupabaseClient()
const { toast } = useToast()

const mode = computed(() => (props.editingStaff ? 'edit' : 'create'))
const form = reactive({ fullName: '', email: '' })
const selectedRole = ref('')
const customRoles = ref<any[]>([])
const newRoleLabel = ref('')
const showPermBuilder = ref(false)
const pendingRoleKey = ref('')
const submitting = ref(false)
const createdPassword = ref('')

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    createdPassword.value = ''
    newRoleLabel.value = ''
    const { data } = await supabase.from('custom_roles').select('*').order('label', { ascending: true })
    customRoles.value = data || []
    if (props.editingStaff) {
      form.fullName = props.editingStaff.full_name
      form.email = props.editingStaff.email || ''
      selectedRole.value = props.editingStaff.role || props.editingStaff.custom_role_key
    } else {
      form.fullName = ''
      form.email = ''
      selectedRole.value = 'receptionist'
    }
  }
)

const canSubmit = computed(() => form.fullName && (mode.value === 'edit' || form.email) && selectedRole.value && selectedRole.value !== '__new__')

async function createRoleAndConfigure() {
  const roleKey = newRoleLabel.value.toLowerCase().trim().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '')
  if (!roleKey) return
  const { error } = await supabase.from('custom_roles').insert({ role_key: roleKey, label: newRoleLabel.value })
  if (error) {
    toast(error.message.includes('duplicate') ? 'A role with that name already exists' : 'Could not create the role', 'warn')
    return
  }
  pendingRoleKey.value = roleKey
  showPermBuilder.value = true
}

async function onRoleConfigured() {
  const { data } = await supabase.from('custom_roles').select('*').order('label', { ascending: true })
  customRoles.value = data || []
  selectedRole.value = pendingRoleKey.value
}

async function submit() {
  submitting.value = true
  const isCustom = !FIXED_STAFF_ROLES.includes(selectedRole.value)

  if (mode.value === 'edit') {
    const { error } = await supabase
      .from('profiles')
      .update(isCustom ? { role: null, custom_role_key: selectedRole.value } : { role: selectedRole.value, custom_role_key: null })
      .eq('id', props.editingStaff.id)
    submitting.value = false
    if (error) {
      toast('Could not update the role', 'warn')
      return
    }
    toast(`${form.fullName}'s role updated`, 'success')
    emit('saved')
    close()
    return
  }

  try {
    const result = await $fetch<{ userId: string; tempPassword: string }>('/api/admin/create-staff', {
      method: 'POST',
      body: { fullName: form.fullName, email: form.email, role: isCustom ? null : selectedRole.value, customRoleKey: isCustom ? selectedRole.value : null },
    })
    createdPassword.value = result.tempPassword
  } catch (e: any) {
    toast(e?.data?.statusMessage || e?.statusMessage || 'Could not create the staff account', 'warn')
  } finally {
    submitting.value = false
  }
}

function copyPassword() {
  navigator.clipboard?.writeText(createdPassword.value)
  toast('Password copied', 'success')
}

function finishAfterCreate() {
  emit('saved')
  close()
}

function close() {
  emit('update:modelValue', false)
}
</script>
