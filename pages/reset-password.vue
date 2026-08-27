<template>
  <div style="min-height:100vh; display:flex; align-items:center; justify-content:center; background:var(--bg); padding:20px;">
    <div style="width:100%; max-width:440px;">
      <div style="text-align:center; margin-bottom:22px;">
        <div style="display:inline-flex; align-items:center; gap:10px;">
          <div style="width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg, var(--blue-500), var(--blue-700));display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;">P</div>
          <div style="font-weight:800; font-size:18px; color:var(--blue-600);">Phenry Health EMR</div>
        </div>
        <p class="muted" style="font-size:13px; margin-top:6px;">Clinical precision and empathetic care.</p>
      </div>
      <div class="card card-pad">
        <h3 style="font-size:16px; display:flex; align-items:center; gap:8px;"><Icon name="lock" :size="16" /> Security Requirement: Set Your New Password</h3>
        <div style="background:var(--blue-50); border:1px solid var(--blue-100); border-radius:var(--radius-sm); padding:12px 14px; font-size:12.5px; color:var(--text-700); margin:16px 0;">
          Welcome to Phenry Health. For your privacy and security, please update your temporary password before accessing your medical portal.
        </div>
        <div class="field">
          <label>New Password</label>
          <input v-model="newPassword" class="input" type="password" placeholder="Enter new password" />
          <div class="hint" :style="{ color: strong ? 'var(--green-600)' : 'var(--red-600)' }">
            {{ strong ? 'Strong password' : 'Weak — add numbers & symbols' }}
          </div>
        </div>
        <div class="field">
          <label>Confirm New Password</label>
          <input v-model="confirmPassword" class="input" type="password" placeholder="Re-enter new password" />
        </div>
        <button class="btn btn-primary btn-block" :disabled="submitting" @click="submit">
          Save Password &amp; Access Portal <Icon name="arrow-right" :size="14" />
        </button>
      </div>
      <p class="muted" style="text-align:center; font-size:11.5px; margin-top:18px;">Phenry Health · Support · Privacy Policy · Terms of Service<br />© 2026 Phenry Health EMR.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useToast } from '~/composables/useToast'
import { loadProfile } from '~/composables/useAuth'
import { roleHomePath } from '~/composables/useRoleMeta'

definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const { toast } = useToast()

const newPassword = ref('')
const confirmPassword = ref('')
const submitting = ref(false)

const strong = computed(() => newPassword.value.length >= 8 && /\d/.test(newPassword.value) && /[^A-Za-z0-9]/.test(newPassword.value))

async function submit() {
  if (!newPassword.value || newPassword.value.length < 6) {
    toast('Choose a password with at least 6 characters', 'warn')
    return
  }
  if (newPassword.value !== confirmPassword.value) {
    toast('Passwords do not match', 'warn')
    return
  }

  submitting.value = true
  const { error: pwError } = await supabase.auth.updateUser({ password: newPassword.value })
  if (pwError) {
    submitting.value = false
    toast(pwError.message || 'Could not update password', 'warn')
    return
  }

  // Goes through a security-definer RPC rather than a direct table update —
  // see 00000000000014_secure_password_reset.sql. Re-fetching the profile
  // afterward (rather than trusting an optimistic local mutation) confirms
  // the flag is actually clear in the database before we ever navigate
  // away, so a silent failure here can't leave the account stuck bouncing
  // back to this page on every future login.
  const { error: rpcError } = await supabase.rpc('complete_password_reset')
  if (rpcError) {
    submitting.value = false
    toast('Password changed, but could not clear the reset flag — contact your Admin Manager', 'warn')
    return
  }

  const updated = await loadProfile()
  submitting.value = false

  if (!updated || updated.force_password_reset) {
    toast('Password changed, but could not confirm the reset flag was cleared — contact your Admin Manager', 'warn')
    return
  }

  toast('Password updated — welcome to your portal', 'success')
  await navigateTo(roleHomePath(updated.role ?? 'patient'))
}
</script>
