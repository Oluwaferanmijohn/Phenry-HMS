<template>
  <div class="login-wrap">
    <div class="login-side">
      <div style="display:flex; align-items:center; gap:10px;">
        <div class="mark" style="width:34px;height:34px;border-radius:9px;background:linear-gradient(135deg, var(--blue-500), var(--blue-700));display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;">P</div>
        <div style="color:#fff; font-weight:700; font-size:15px;">Phenry Health</div>
      </div>
      <div>
        <div class="tagline">One clinic. <span>Ten roles.</span> One record of truth — built offline-first, secured by row-level access.</div>
        <div class="foot-note" style="margin-top:14px;">© 2026 Phenry Health EMR · Nuxt 3 · Supabase · PowerSync · Evolution API (WhatsApp)</div>
      </div>
    </div>
    <div class="login-form-side">
      <div class="login-card">
        <h2 style="font-size:19px;">Sign in</h2>
        <div class="tabs" style="margin-top:12px;">
          <div class="tab" :class="{ active: mode === 'staff' }" @click="mode = 'staff'">Staff</div>
          <div class="tab" :class="{ active: mode === 'patient' }" @click="mode = 'patient'">Patient</div>
        </div>
        <p class="muted" style="font-size:13px; margin-top:10px;">
          {{ mode === 'staff' ? 'Use the email and password your clinic gave you.' : 'Use your Patient ID and the temporary password given to you at registration (your surname).' }}
        </p>
        <p v-if="revoked" class="hint" style="color:var(--red-600); margin-top:10px;">Your access has been revoked. Contact your Admin Manager if this is unexpected.</p>

        <form style="margin-top:18px;" @submit.prevent="handleSubmit">
          <template v-if="mode === 'staff'">
            <div class="field">
              <label>Email</label>
              <input v-model="email" class="input" type="email" autocomplete="username" required placeholder="you@example.com" />
            </div>
          </template>
          <template v-else>
            <div class="field">
              <label>Patient ID</label>
              <input v-model="patientId" class="input" autocomplete="username" required placeholder="e.g. ADE/20260811/001" />
            </div>
          </template>
          <div class="field">
            <label>Password</label>
            <input v-model="password" class="input" type="password" autocomplete="current-password" required placeholder="••••••••" />
          </div>
          <p v-if="errorMessage" class="hint" style="color:var(--red-600); margin-bottom:12px;">{{ errorMessage }}</p>
          <button class="btn btn-primary btn-block" type="submit" :disabled="loading">
            {{ loading ? 'Signing in…' : 'Sign in' }} <Icon name="arrow-right" :size="14" />
          </button>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { loadProfile } from '~/composables/useAuth'
import { roleHomePath } from '~/composables/useRoleMeta'
import { patientLoginEmail } from '~/composables/usePatientAuth'

definePageMeta({ layout: false })

const supabase = useSupabaseClient()
const route = useRoute()
const revoked = computed(() => route.query.revoked === '1')
const mode = ref<'staff' | 'patient'>('staff')
const email = ref('')
const patientId = ref('')
const password = ref('')
const loading = ref(false)
const errorMessage = ref('')

watch(mode, () => {
  errorMessage.value = ''
})

async function handleSubmit() {
  loading.value = true
  errorMessage.value = ''
  const loginEmail = mode.value === 'staff' ? email.value : patientLoginEmail(patientId.value)
  const { error } = await supabase.auth.signInWithPassword({ email: loginEmail, password: password.value })
  loading.value = false

  if (error) {
    errorMessage.value = mode.value === 'staff' ? error.message || 'Could not sign in — check your email and password.' : 'Could not sign in — check your Patient ID and password.'
    return
  }

  const profile = await loadProfile()
  await navigateTo(profile ? roleHomePath(profile.role ?? '') : '/no-access')
}
</script>
